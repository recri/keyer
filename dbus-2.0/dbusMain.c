#include "dbustcl.h"

Tcl_HashTable bus;
Tcl_DBusBus *defaultbus = NULL;
static int initialized = 0;
TCL_DECLARE_MUTEX(dbusMutex)

int Dbus_Init(Tcl_Interp *interp)
{
   if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
      return TCL_ERROR;
   }
   if (Tcl_PkgRequire(interp, "Tcl", "8.5", 0) == NULL) {
      return TCL_ERROR;
   }

   Tcl_MutexLock(&dbusMutex);
   if (!initialized) {
      Tcl_InitObjHashTable(&bus);
      Tcl_CreateEventSource(DBus_SetupProc, DBus_CheckProc, interp);
      initialized = TRUE;
   }
   Tcl_MutexUnlock(&dbusMutex);
   TclInitDBusCmd(interp);
   /* Provide the historical name for compatibility */
   Tcl_PkgProvide(interp, "dbus-tcl", PACKAGE_VERSION);
   return Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION);
}

Tcl_DBusBus *DBus_GetConnection(Tcl_Interp *interp, Tcl_Obj *const name)
{
   Tcl_HashEntry *entry;
   Tcl_DBusBus *dbus;

   entry = Tcl_FindHashEntry(&bus, (char *) name);
   if (entry == NULL) return NULL;
   dbus = (Tcl_DBusBus *) Tcl_GetHashValue(entry);
   entry = Tcl_FindHashEntry(dbus->snoop, (char *) interp);
   if (entry != NULL)
     return dbus;
   else
     return NULL;
}

char *DBus_Alloc(int size, char *file, int line)
{
   char *rc;

   rc = Tcl_Alloc(size);
   printf("%p, %d bytes (%s:%d)\n", rc, size, file, line);
   return rc;
}

void DBus_Free(char *ptr, char *file, int line)
{
   printf("Free %p (%s:%d)\n", ptr, file, line);
   Tcl_Free(ptr);
}

int Tcl_CheckHashEmpty(Tcl_HashTable *hash)
{
   return (hash->numEntries == 0);
}

int DBus_SignalCleanup(Tcl_Interp *interp, Tcl_HashTable *members)
{
   Tcl_HashTable *interps;
   Tcl_HashEntry *memberPtr, *interpPtr;
   Tcl_HashSearch search;
   Tcl_DBusSignalData *signal;

   for (memberPtr = Tcl_FirstHashEntry(members, &search);
	memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
      interps = Tcl_GetHashValue(memberPtr);
      interpPtr = Tcl_FindHashEntry(interps, (char *) interp);
      if (interpPtr != NULL) {
	 signal = Tcl_GetHashValue(interpPtr);
	 Tcl_DecrRefCount(signal->script);
	 ckfree((char *) signal);
	 Tcl_DeleteHashEntry(interpPtr);
	 if (Tcl_CheckHashEmpty(interps)) {
	    Tcl_DeleteHashTable(interps);
	    ckfree((char *) interps);
	    Tcl_DeleteHashEntry(memberPtr);
	 }
      }
   }
   return Tcl_CheckHashEmpty(members);
}

int DBus_MethodCleanup(Tcl_Interp *interp, Tcl_HashTable *members)
{
   Tcl_HashEntry *memberPtr;
   Tcl_HashSearch search;
   Tcl_DBusMethodData *method;

   for (memberPtr = Tcl_FirstHashEntry(members, &search);
	memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
      method = Tcl_GetHashValue(memberPtr);
      if (method->interp == interp) {
	 Tcl_DecrRefCount(method->script);
	 ckfree((char *) method);
	 Tcl_DeleteHashEntry(memberPtr);
      }
   }
   return Tcl_CheckHashEmpty(members);
}

int DBus_HandlerCleanup(Tcl_Interp *interp, Tcl_DBusHandlerData *data)
{
   if (data->signal != NULL) {
      if (DBus_SignalCleanup(interp, data->signal)) {
	 Tcl_DeleteHashTable(data->signal);
	 ckfree((char *) data->signal);
	 data->signal = NULL;
      }
   }
   if (data->method != NULL) {
      if (DBus_MethodCleanup(interp, data->method)) {
	 Tcl_DeleteHashTable(data->method);
	 ckfree((char *) data->method);
	 data->method = NULL;
      }
   }
   return (data->signal == NULL && data->method == NULL);
}

void DBus_InterpCleanup(Tcl_Interp *interp, DBusConnection *conn, char *path)
{
   char **entries, **entry, *newpath, *pathentry;
   Tcl_DBusHandlerData *data;

   dbus_connection_get_object_path_data(conn, path, (void **)&data);
   if (data != NULL) {
      if (DBus_HandlerCleanup(interp, data)) {
	 dbus_connection_unregister_object_path(conn, path);
	 ckfree((char *)data);
      }
   }
   dbus_connection_list_registered(conn, path, &entries);
   if (*entries != NULL) {
      newpath = ckalloc(strlen(path) + 256);
      strcpy(newpath, path);
      pathentry = newpath + strlen(path) - 1;
      if (*pathentry++ != '/') *pathentry++ = '/';
      for (entry = entries; *entry != NULL; entry++) {
	 strncpy(pathentry, *entry, 255);
	 /* Get a list of descendents from the child */
	 DBus_InterpCleanup(interp, conn, newpath);
      }
      ckfree(newpath);
   }
   /* Release the entries array */
   dbus_free_string_array(entries);
}

const char *DBus_InterpPath(Tcl_Interp *interp)
{
   Tcl_Interp *master;
   master = Tcl_GetMaster(interp);
   if (master == NULL) return "";
   Tcl_GetInterpPath(master, interp);
   return (Tcl_GetStringResult(master));
}

void DBus_Disconnect(Tcl_Interp *interp, Tcl_HashEntry *busPtr)
{
   Tcl_DBusBus *data;
   Tcl_HashEntry *hPtr;
   Tcl_DBusMonitorData *snoop;
  
   data = Tcl_GetHashValue(busPtr);
   /* Find all paths with handlers registered by the interp */
   DBus_InterpCleanup(interp, data->conn, "/");
   /* Find all handlers of the interp without a path */
   if (data->fallback != NULL) {
      if (DBus_HandlerCleanup(interp, data->fallback)) {
	 ckfree((char *)data->fallback);
	 data->fallback = NULL;
      }
   }
   /* Find snoop handlers */
   hPtr = Tcl_FindHashEntry(data->snoop, (char *) interp);
   if (hPtr != NULL) {
      snoop = Tcl_GetHashValue(hPtr);
      if (snoop != NULL) {
	 /* Uninstall the monitor script */
	 dbus_connection_remove_filter(data->conn, DBus_Monitor, snoop);
	 Tcl_DecrRefCount(snoop->script);
	 ckfree((char *) snoop);
      }
      Tcl_DeleteHashEntry(hPtr);
      if (Tcl_CheckHashEmpty(data->snoop)) {
	 /* Last interpreter that was connected to the dbus */
	 Tcl_DeleteHashTable(data->snoop);
	 ckfree((char *) data->snoop);
	 if (data->type == N_BUS_TYPES)
	   dbus_connection_unref(data->conn);
	 ckfree((char *) data);
	 if (defaultbus == data) defaultbus = NULL;
	 Tcl_DeleteHashEntry(busPtr);
      }
   }
}

void DBus_InterpDelete(ClientData clientData, Tcl_Interp *interp)
{
   DBus_Disconnect(interp, (Tcl_HashEntry *) clientData);
}
