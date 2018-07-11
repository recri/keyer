#include "dbustcl.h"
#include <ctype.h>

#define TCL_TSD_INIT(keyPtr) \
  (Tcl_DBusThreadData *)Tcl_GetThreadData((keyPtr), sizeof(Tcl_DBusThreadData))

static Tcl_ThreadDataKey dataKey;
TCL_DECLARE_MUTEX(dbusMutex);

/* Reserve a slot for attaching Tcl related data to a dbus connection */
dbus_int32_t dataSlot = -1;

/* Names of the standard dbusses */
const char *busnames[] = {
    "session", "system", "starter", NULL
};

int Tcl_CheckHashEmpty(Tcl_HashTable *hash)
{
   Tcl_HashSearch search;

   return (Tcl_FirstHashEntry(hash, &search) == NULL);
}

void Tcl_DBusErrorCode(Tcl_Interp *interp, char *op, DBusError err)
{
   char *s1, *s2, buf[32];

   s1 = strrchr(err.name, '.');
   s2 = buf;
   while ((*s2++ = toupper(*++s1)) != '\0');
   Tcl_SetErrorCode(interp, "DBUS", op, buf, NULL);
}

int DBus_SignalCleanup(Tcl_Interp *interp, Tcl_HashTable *members)
{
   Tcl_HashTable *interps;
   Tcl_HashEntry *memberPtr, *interpPtr;
   Tcl_HashSearch search, iter;
   Tcl_DBusSignalData *signal;

   for (memberPtr = Tcl_FirstHashEntry(members, &search);
	memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
      interps = Tcl_GetHashValue(memberPtr);
      if (interp == NULL) {
	 interpPtr = Tcl_FirstHashEntry(interps, &iter);
      } else {
	 interpPtr = Tcl_FindHashEntry(interps, (char *) interp);
      }
      while (interpPtr != NULL) {
	 signal = Tcl_GetHashValue(interpPtr);
	 Tcl_DecrRefCount(signal->script);
	 ckfree((char *) signal);
	 Tcl_DeleteHashEntry(interpPtr);
	 if (interp != NULL) break;
	 interpPtr = Tcl_NextHashEntry(&iter);
      }
      if (Tcl_CheckHashEmpty(interps)) {
	 Tcl_DeleteHashTable(interps);
	 ckfree((char *) interps);
	 Tcl_DeleteHashEntry(memberPtr);
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
      if (interp == NULL || method->interp == interp) {
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

void DBus_SnoopCleanup(Tcl_Interp *interp, DBusConnection *conn)
{
   Tcl_DBusThreadData *tsdPtr;
   Tcl_HashEntry *hPtr;
   Tcl_HashSearch iter;
   Tcl_DBusMonitorData *snoop;
   Tcl_DBusBus *dbus;

   dbus = dbus_connection_get_data(conn, dataSlot);
   if (interp == NULL) {
      hPtr = Tcl_FirstHashEntry(dbus->snoop, &iter);
   } else {
      hPtr = Tcl_FindHashEntry(dbus->snoop, (char *) interp);
   }
   while (hPtr != NULL) {
      snoop = Tcl_GetHashValue(hPtr);
      if (snoop != NULL) {
	 /* Uninstall the monitor script */
	 dbus_connection_remove_filter(conn, DBus_Monitor, snoop);
	 Tcl_DecrRefCount(snoop->script);
	 ckfree((char *) snoop);
      }
      Tcl_DeleteHashEntry(hPtr);
      if (interp != NULL) break;
      hPtr = Tcl_NextHashEntry(&iter);
   }
   if (Tcl_CheckHashEmpty(dbus->snoop)) {
      Tcl_DeleteHashTable(dbus->snoop);
      ckfree((char *) dbus->snoop);
      dbus->snoop = NULL;

      /* Remove the dbus name from the hash table */
      tsdPtr = DBus_GetThreadData(NULL);
      hPtr = Tcl_FindHashEntry(&tsdPtr->bus, (char *)dbus->name);
      if (hPtr != NULL) {
	 switch (dbus->type) {
	  case TCL_DBUS_SESSION:
	  case TCL_DBUS_SYSTEM:
	  case TCL_DBUS_STARTER:
	    Tcl_SetHashValue(hPtr, NULL);
	    break;
	  case TCL_DBUS_PRIVATE:
	  case TCL_DBUS_SHARED:
	    Tcl_DeleteHashEntry(hPtr);
	    break;
	 }
      }

      /* Release the dbus connection */
      switch (dbus->type) {
       case TCL_DBUS_SESSION:
       case TCL_DBUS_SYSTEM:
       case TCL_DBUS_STARTER:
       case TCL_DBUS_PRIVATE:
	 dbus_connection_close(conn);
	 /* Fall through */
       case TCL_DBUS_SHARED:
	 dbus_connection_unref(conn);
	 break;
      }

      /* Cancel any pending dispatch actions */
      DBusDispatchCancel(conn);
   }
}

void DBus_Disconnect(DBusConnection *conn) {
   Tcl_DBusBus *dbus;

   dbus = dbus_connection_get_data(conn, dataSlot);
   /* Delete all handlers without a path */
   if (dbus->fallback != NULL) {
      if (DBus_HandlerCleanup(NULL, dbus->fallback)) {
	 ckfree((char *)dbus->fallback);
	 dbus->fallback = NULL;
      }
   }
   /* Delete all snoop handlers */
   DBus_SnoopCleanup(NULL, conn);
}

static void DBus_ThreadExit(ClientData data)
{
   Tcl_DBusThreadData *tsdPtr = (Tcl_DBusThreadData *)data;
   Tcl_HashEntry *hPtr;
   Tcl_HashSearch search;
   DBusConnection *conn;

   if (tsdPtr->defaultbus != NULL) {
#ifdef _WIN32
      Tcl_DeleteEventSource(DBus_SetupProc, DBus_CheckProc, tsdPtr);
#endif
      hPtr = Tcl_FirstHashEntry(&tsdPtr->bus, &search);
      while (hPtr != NULL) {
	 conn = (DBusConnection *)Tcl_GetHashValue(hPtr);
	 if (conn != NULL)
	   DBus_Disconnect(conn);
	 hPtr = Tcl_NextHashEntry(&search);
      }
      Tcl_DeleteHashTable(&tsdPtr->bus);
      Tcl_DecrRefCount(tsdPtr->defaultbus);
      tsdPtr->defaultbus = NULL;
   }
}

int Dbus_Init(Tcl_Interp *interp)
{
   Tcl_DBusThreadData *tsdPtr;
   Tcl_Obj *name;
   const char **s;
   int i, isNew;

   if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
      return TCL_ERROR;
   }
   if (Tcl_PkgRequire(interp, "Tcl", "8.5", 0) == NULL) {
      return TCL_ERROR;
   }

   Tcl_MutexLock(&dbusMutex);
   if (dataSlot == -1) {
      /* Application-wide initialization */
#ifdef TCL_THREADS
      dbus_threads_init_default();
#endif
      /* Allocate a data slot to use for tracking new connections */
      dbus_connection_allocate_data_slot(&dataSlot);
   }
   Tcl_MutexUnlock(&dbusMutex);

   tsdPtr = TCL_TSD_INIT(&dataKey);
   if (tsdPtr->defaultbus == NULL) {
      /* Per thread initialization */
      Tcl_InitObjHashTable(&tsdPtr->bus);
      tsdPtr->dbusid = 0;

      /*
       * Put the standard bus names in the hash table to get the correct
       * error messages when they are referenced without a connection
       */

      for (i = 0, s = busnames; *s != NULL; i++, s++) {
	 name = Tcl_NewStringObj(*s, -1);
	 /* Tcl_CreateHashEntry will increment the refcount */
	 Tcl_CreateHashEntry(&tsdPtr->bus, (char *)name, &isNew);
	 if (i == TCL_DBUS_DEFAULT) {
	    tsdPtr->defaultbus = name;
	    Tcl_IncrRefCount(name);
	 }
      }

#ifdef _WIN32
      Tcl_CreateEventSource(DBus_SetupProc, DBus_CheckProc, tsdPtr);
#endif
      Tcl_CreateThreadExitHandler(DBus_ThreadExit, tsdPtr);
   }

   TclInitDBusCmd(interp);
   /* Provide the historical name for compatibility */
   Tcl_PkgProvide(interp, "dbus-tcl", PACKAGE_VERSION);
   return Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION);
}

Tcl_DBusThreadData *DBus_GetThreadData(Tcl_Interp *interp)
{
   Tcl_DBusThreadData *tsdPtr = TCL_TSD_INIT(&dataKey);

   if (tsdPtr->defaultbus != NULL)
     return tsdPtr;
   else if (interp != NULL)
     Tcl_SetObjResult(interp,
		      Tcl_NewStringObj("DBus module not initialized", -1));
   return NULL;
}

DBusConnection *DBus_GetConnection(Tcl_Interp *interp, Tcl_Obj *const name)
{
   Tcl_DBusThreadData *tsdPtr;
   Tcl_HashEntry *entry;
   Tcl_DBusBus *dbus;
   Tcl_Obj *str;
   DBusConnection *conn = NULL;

   if ((tsdPtr = DBus_GetThreadData(interp)) == NULL)
     return NULL;

   if (name == NULL)
      str = tsdPtr->defaultbus;
   else
      str = name;

   entry = Tcl_FindHashEntry(&tsdPtr->bus, (char *)str);
   if (entry != NULL) {
      conn = (DBusConnection *)Tcl_GetHashValue(entry);
      /* Check that the current interpreter has a connection */
      /* to the selected dbus */
      if (conn != NULL) {
	 if (interp == NULL)
	   return conn;
	 dbus = dbus_connection_get_data(conn, dataSlot);
	 if (dbus->snoop != NULL) {
	    entry = Tcl_FindHashEntry(dbus->snoop, (char *) interp);
	    if (entry != NULL)
	      return conn;
	 }
      }
      if (interp != NULL)
	Tcl_SetObjResult(interp, Tcl_NewStringObj("Not connected", -1));
   } else {
      if (interp != NULL)
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("bad busId \"%s\"",
					       Tcl_GetString(str)));
   }
   return NULL;
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

void DBus_Close(Tcl_Interp *interp, DBusConnection *conn)
{
   Tcl_DBusBus *dbus;

   dbus = dbus_connection_get_data(conn, dataSlot);
   /* Find all paths with handlers registered by the interp */
   DBus_InterpCleanup(interp, conn, "/");
   /* Find all handlers of the interp without a path */
   if (dbus->fallback != NULL) {
      if (DBus_HandlerCleanup(interp, dbus->fallback)) {
	 ckfree((char *)dbus->fallback);
	 dbus->fallback = NULL;
      }
   }
   /* Remove snoop handlers */
   DBus_SnoopCleanup(interp, conn);
}

void DBus_InterpDelete(ClientData data, Tcl_Interp *interp)
{
   DBus_Close(interp, (DBusConnection *)data);
}

#ifdef DBUS_MEM_DEBUG
char *DBus_Alloc(int size, char *file, int line)
{
   char *rc;

   rc = Tcl_Alloc(size);
   printf("Alloc %d bytes -> %p (%s:%d)\n", size, rc, file, line);
   return rc;
}

char *DBus_AttemptAlloc(int size, char *file, int line)
{
   char *rc;

   rc = Tcl_AttemptAlloc(size);
   printf("Alloc %d bytes -> %p (%s:%d)\n", size, rc, file, line);
   return rc;
}

void DBus_Free(char *ptr, char *file, int line)
{
   printf("Free %p (%s:%d)\n", ptr, file, line);
   Tcl_Free(ptr);
}

void DBus_RefCount(Tcl_Obj *objPtr, int delta, char *file, int line)
{
   static const char *dir[] = {"Increment", "Decrement"};

   printf("%s %p = %d (%s:%d)",
	  dir[delta < 0], objPtr, objPtr->refCount + delta, file, line);

   if (delta > 0)
     ++(objPtr)->refCount;

   /* Don't use Tcl_GetString() as that may invalidate the intrep */
   if (objPtr->bytes != NULL) {
      if (objPtr->length > 40)
	printf(": %-38s...", objPtr->bytes);
      else
	printf(": %s", objPtr->bytes);
   }
   if (objPtr->typePtr != NULL) {
      printf(", type = %s", objPtr->typePtr->name);
   }
   printf("\n");

   if (delta < 0)
     if (--(objPtr)->refCount <= 0) {
	printf("Freeing %p\n", objPtr);
	TclFreeObj(objPtr);
     }
}
#endif
