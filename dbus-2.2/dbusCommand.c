#include "dbustcl.h"

/* Mapping from our bus type enumeration to that used by dbus */
/* They are probably the same, but better be safe */
static DBusBusType bustypes[] = {
   DBUS_BUS_SESSION, DBUS_BUS_SYSTEM, DBUS_BUS_STARTER
};

void DBus_FreeDataSlot(void *data)
{
   Tcl_DBusBus *dbus = (Tcl_DBusBus *)data;
   Tcl_DecrRefCount(dbus->name);
   ckfree(data);
}

void DBus_FreeWatch(void *data)
{
   Tcl_DBusWatchData *watchData = (Tcl_DBusWatchData *)data;
   if (watchData->chan != NULL)
      Tcl_DetachChannel(NULL, watchData->chan);
   ckfree(data);
}

void DBusIdleProc(ClientData data)
{
   DBusConnection *conn = (DBusConnection *)data;
   DBusDispatchStatus dispatch;

   do {
      dispatch = dbus_connection_dispatch(conn);
   } while (dispatch == DBUS_DISPATCH_DATA_REMAINS);
}

void DBusDispatchChange(DBusConnection *conn,
			DBusDispatchStatus status, void *data)
{
   if (status == DBUS_DISPATCH_DATA_REMAINS)
      Tcl_DoWhenIdle(DBusIdleProc, conn);
}

void DBusDispatchCancel(DBusConnection *conn)
{
   Tcl_CancelIdleCall(DBusIdleProc, conn);
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_MemoryError
 *	Set the result value for the interpreter to indicate an out of
 *	memory error.
 *
 * Results:
 *	Always returns TCL_ERROR
 *
 * Side effects:
 * 	None
 *
 *----------------------------------------------------------------------
 */

int DBus_MemoryError(Tcl_Interp *interp)
{
   Tcl_SetObjResult(interp, Tcl_NewStringObj("Out Of Memory", -1));
   return TCL_ERROR;
}

/*
 * Compare DBus addresses
 */

int DBus_BusEqual(DBusAddressEntry *ref, const char *addr)
{
   int rc, len;
   Tcl_Obj *p1, *p2;
   DBusAddressEntry **entries;
   DBusError err;
   const char *v1, *v2, **s;
   static const char *keys[] = {
      "guid", "path", "tmpdir", "abstract", "runtime",
	"host", "port", "bind", "family", NULL
   };

   dbus_error_init(&err);
   if (!dbus_parse_address(addr, &entries, &len, &err))
     return 0;

   s = keys;
   /* If both addresses contain a guid, we only need to compare those */
   v1 = dbus_address_entry_get_value(ref, *s);
   v2 = dbus_address_entry_get_value(entries[0], *s);
   if (v1 != NULL && v2 != NULL) {
      rc = (strcmp(v1, v2) == 0);
   } else if (strcmp(dbus_address_entry_get_method(ref),
		     dbus_address_entry_get_method(entries[0])) != 0) {
      rc = 0;
   } else {
      rc = 1;
      while (rc && *++s != NULL) {
	 v1 = dbus_address_entry_get_value(ref, *s);
	 v2 = dbus_address_entry_get_value(entries[0], *s);
	 if (v1 == NULL || v2 == NULL) {
	    rc = (v1 == v2);
	 } else if (v1[0] == '/' && v2[0] == '/') {
	    /* Compare file paths */
	    p1 = Tcl_NewStringObj(v1, -1);
	    Tcl_IncrRefCount(p1);
	    p2 = Tcl_NewStringObj(v2, -1);
	    Tcl_IncrRefCount(p2);
	    rc = Tcl_FSEqualPaths(p1, p2);
	    Tcl_DecrRefCount(p1);
	    Tcl_DecrRefCount(p2);
	 } else {
	    rc = (strcmp(v1, v2) == 0);
	 }
      }
   }
   dbus_address_entries_free(entries);
   return rc;
}

/*
 * Find a DBus
 */

int DBus_BusType(Tcl_Interp *interp, Tcl_Obj **const arg)
{
   int rc, index, len;
   const char *s;
   Tcl_Obj *name;
   DBusAddressEntry **entries;
   DBusError err;

   rc = TCL_DBUS_PRIVATE;

   name = *arg;
   if (name == NULL) {
      rc = TCL_DBUS_DEFAULT;
   } else if (Tcl_GetIndexFromObj(NULL, name, busnames,
				  "", TCL_EXACT, &index) == TCL_OK) {
      if (index != TCL_DBUS_STARTER)
	return index;
      name = Tcl_GetVar2Ex(interp,
			   "env", "DBUS_STARTER_ADDRESS", TCL_GLOBAL_ONLY);
      if (name == NULL)
	rc = TCL_DBUS_DEFAULT;
   }

   if (rc == TCL_DBUS_PRIVATE) {
      dbus_error_init(&err);
      if (!dbus_parse_address(Tcl_GetString(name), &entries, &len, &err)) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj(err.message, -1));
	 dbus_error_free(&err);
	 return -1;
      }

      s = Tcl_GetVar2(interp,
		      "env", "DBUS_SESSION_BUS_ADDRESS", TCL_GLOBAL_ONLY);
      if (s != NULL && DBus_BusEqual(entries[0], s)) {
	 /* This is actually the session bus */
	 rc = TCL_DBUS_SESSION;
      } else if (DBus_BusEqual(entries[0], SYSTEMBUSADDRESS)) {
	 /* This is actually the systembus */
	 rc = TCL_DBUS_SYSTEM;
      }
      dbus_address_entries_free(entries);
   }

   if (rc != TCL_DBUS_PRIVATE) {
      if (*arg != NULL)
	Tcl_DecrRefCount(*arg);
      name = Tcl_NewStringObj(busnames[rc], -1);
      Tcl_IncrRefCount(name);
      *arg = name;
   }
   return rc;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusConnectCmd
 *	Connect to the DBus.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	The result value of the interpreter is set to the busId for
 *	the connection.
 *
 *----------------------------------------------------------------------
 */

int DBusConnectCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   int type = DBUS_BUS_SESSION;
   Tcl_DBusBus *dbus;
   Tcl_HashEntry *busPtr, *hPtr;
   Tcl_DBusThreadData *tsdPtr;
   DBusConnection *conn;
   DBusError err;
   int isNew;
   Tcl_Obj *result, *name = NULL;

#ifndef _WIN32
   Tcl_DBusWatchData *watchData;
#endif

   if ((tsdPtr = DBus_GetThreadData(interp)) == NULL)
     return TCL_ERROR;

   if (objc > 2) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId?");
      return TCL_ERROR;
   }
   if (objc == 2) {
      name = objv[1];
      Tcl_IncrRefCount(name);
   }
   type = DBus_BusType(interp, &name);

   if (type < 0) {
      Tcl_SetObjResult(interp,
		       Tcl_ObjPrintf("bad busId \"%s\"", Tcl_GetString(name)));
      Tcl_DecrRefCount(name);
      return TCL_ERROR;
   }

   if ((conn = DBus_GetConnection(interp, name)) != NULL) {
      /* Already connected */
   } else if ((conn = DBus_GetConnection(NULL, name)) == NULL) {
      /* First connection in the current thread */

      /* initialise the dbus error structure */
      dbus_error_init(&err);

      /* connect to the bus and check for errors */
      switch (type) {
       case TCL_DBUS_SESSION:
       case TCL_DBUS_SYSTEM:
       case TCL_DBUS_STARTER:
	 /* Each thread gets its own connection to the standard DBus */
	 conn = dbus_bus_get_private(bustypes[type], &err);
	 break;
       case TCL_DBUS_PRIVATE:
	 conn = dbus_connection_open_private(Tcl_GetString(name), &err);
	 if (conn != NULL && !dbus_error_is_set(&err)) {
	    dbus_bus_register(conn, &err);
	    name = Tcl_ObjPrintf("dbus%d", ++(tsdPtr->dbusid));
	 }
	 break;
      }
      if (dbus_error_is_set(&err)) {
	 result = Tcl_NewStringObj("Connection Error: ", -1);
	 Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
	 Tcl_SetObjResult(interp, result);
	 Tcl_DBusErrorCode(interp, "CONNECT", err);
	 dbus_error_free(&err);
	 Tcl_DecrRefCount(name);	 
	 return TCL_ERROR;
      }

      if (conn == NULL) {
	 result = Tcl_NewStringObj("Connection Error", -1);
	 Tcl_SetObjResult(interp, result);
	 Tcl_DecrRefCount(name);
	 return TCL_ERROR;
      }

      /* A disconnect of the DBus should not terminate the application */
      /* Should there be command to control this? */
      dbus_connection_set_exit_on_disconnect(conn, FALSE);
   }

   dbus = dbus_connection_get_data(conn, dataSlot);
   if (dbus == NULL) {
      /* First interpreter to connect to this dbus */
      /* Map name to the dbus connection */
      busPtr = Tcl_CreateHashEntry(&tsdPtr->bus, (char *)name, &isNew);
      Tcl_SetHashValue(busPtr, (ClientData)conn);
      /* Attach some data to the connection */
      dbus = (Tcl_DBusBus *) ckalloc(sizeof(Tcl_DBusBus));
      dbus->type = type;
      dbus->snoop = NULL;
      dbus->fallback = NULL;
      dbus->name = name;
      dbus_connection_set_data(conn, dataSlot, dbus, DBus_FreeDataSlot);
      /* Set the timeout functions for the connection */
      dbus_connection_set_timeout_functions(conn, DBus_AddTimeout,
		DBus_RemoveTimeout, DBus_ToggleTimeout, NULL, NULL);
#ifndef _WIN32
      /* Set the watch functions for the connection */
      watchData = (Tcl_DBusWatchData *)ckalloc(sizeof(Tcl_DBusWatchData));
      memset(watchData, 0, sizeof(Tcl_DBusWatchData));
      watchData->chan = NULL;
      dbus_connection_set_watch_functions(conn, DBus_AddWatch,
		DBus_RemoveWatch, DBus_ToggleWatch, watchData, DBus_FreeWatch);
      dbus_connection_set_dispatch_status_function(conn,
		DBusDispatchChange, NULL, NULL);
      /* For some reason the fileevent doesn't fire for data that is
       * already waiting (like the NameAcquired signal), so that data
       * needs to be collected explicitly. */
      DBusDispatchChange(conn, dbus_connection_get_dispatch_status(conn), NULL);
#endif
   } else {
      Tcl_DecrRefCount(name);
      name = dbus->name;
   }

   if (dbus->snoop == NULL) {
      dbus->snoop = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(dbus->snoop, TCL_ONE_WORD_KEYS);
   }

   hPtr = Tcl_CreateHashEntry(dbus->snoop, (char *) interp, &isNew);
   /* Presence of the array entry indicates connection to the bus */
   if (isNew) {
      /* New connection for this interpreter */
      Tcl_SetHashValue(hPtr, NULL);
      Tcl_CallWhenDeleted(interp, DBus_InterpDelete, conn);
   }

   /* Return the handle to the connection */
   Tcl_SetObjResult(interp, name);
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusCloseCmd
 *	Close a DBus connection.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None
 *
 *----------------------------------------------------------------------
 */

int DBusCloseCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   Tcl_Obj *busname = NULL;
   DBusConnection *conn;

   if (objc < 1 || objc > 2) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId?");
      return TCL_ERROR;
   }
   if (objc > 1)
     busname = objv[1];
   conn = DBus_GetConnection(interp, busname);
   if (conn != NULL) {
      DBus_Close(interp, conn);
      Tcl_DontCallWhenDeleted(interp, DBus_InterpDelete, conn);
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusFilterCmd
 *	Add or remove a dbus message filter.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	The result value of the interpreter is set to the match rule passed
 *	to libdbus.
 *
 *----------------------------------------------------------------------
 */

int DBusFilterCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   DBusConnection *conn;
   DBusError err;
   Tcl_Obj *busname = NULL, *match = NULL, *result;
   int index, subcmd, len, x = 1;
   static const char *subcmds[] = {
      "add", "remove", NULL
   };
   enum subcmds {
      DBUS_FILTERADD, DBUS_FILTERDEL
   };
   static const char *options[] = {
      "-destination", "-eavesdrop", "-interface", "-member", "-path",
	"-sender", "-type", NULL
   };

   if (objc < 4) {
      Tcl_WrongNumArgs(interp, 1, objv,
		       "?busId? subcommand -option value ?...?");
      return TCL_ERROR;
   }
   if ((objc & 1) == 1)
      busname = objv[x++];
   if ((conn = DBus_GetConnection(interp, busname)) == NULL)
      return TCL_ERROR;

   if (Tcl_GetIndexFromObj(interp, objv[x], subcmds,
			   "subcommand", 0, &subcmd) != TCL_OK) {
      return TCL_ERROR;
   }

   /* type='signal',sender='org.freedesktop.DBus',
    interface='org.freedesktop.DBus', member='Foo',
    path='/bar/foo',destination=':452345.34'" */
   for (x += 1; x < objc - 1; x += 2) {
      if (match == NULL)
	match = Tcl_NewObj();
      else
	Tcl_AppendToObj(match, ",", 1);
      if (Tcl_GetIndexFromObj(interp, objv[x], options,
			      "option", 0, &index) != TCL_OK) {
	 Tcl_DecrRefCount(match);
	 return TCL_ERROR;
      }
      len = Tcl_GetCharLength(objv[x]);
      /* Get the option without the - */
      Tcl_AppendObjToObj(match, Tcl_GetRange(objv[x], 1, len - 1));
      Tcl_AppendToObj(match, "='", 2);
      /* Get the specified value */
      Tcl_AppendObjToObj(match, objv[x+1]);
      Tcl_AppendToObj(match, "'", 1);
   }

   /* initialise the dbus error structure */
   dbus_error_init(&err);

   if ((enum subcmds) subcmd == DBUS_FILTERADD)
     dbus_bus_add_match(conn, Tcl_GetString(match), &err);
   else
     dbus_bus_remove_match(conn, Tcl_GetString(match), &err);
   dbus_connection_flush(conn);
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Match Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      /* Strip trailing newline off the error message */
      Tcl_SetObjLength(result, Tcl_GetCharLength(result) - 1);
      Tcl_SetObjResult(interp, result);
      Tcl_DBusErrorCode(interp, "FILTER", err);
      dbus_error_free(&err);
      Tcl_DecrRefCount(match);
      return TCL_ERROR;
   }
   Tcl_SetObjResult(interp, match);
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusInfoCmd
 *	Provide information about various dbus aspects.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	On return, the result value of the interpreter contains the requested
 *	information.
 *
 *----------------------------------------------------------------------
 */

int DBusInfoCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   int index, major, minor, micro, sw;
   Tcl_Obj *busname = NULL, *rc;
   DBusConnection *conn;
   static const char *options[] = {
      "capabilities", "local", "machineid", "name", "path", "pending",
	"serverid", "service", "version", NULL
   };
   enum options {
      DBUS_INFOCAPS, DBUS_INFOLOCAL, DBUS_INFOUUID, DBUS_INFONAME,
      DBUS_INFOPATH, DBUS_INFOPENDING, DBUS_INFOSERVER, DBUS_INFOSERVICE,
      DBUS_INFOVERSION
   };

   if (objc < 2 || objc > 3) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? option");
      return TCL_ERROR;
   }
   if (objc > 2)
      busname = objv[1];

   if (Tcl_GetIndexFromObj(interp, objv[objc - 1], options,
			   "option", 0, &index) != TCL_OK) {
      return TCL_ERROR;
   }

   switch ((enum options) index) {
    case DBUS_INFOVERSION:
      dbus_get_version(&major, &minor, &micro);
      Tcl_SetObjResult(interp,
		       Tcl_ObjPrintf("%d.%d.%d", major, minor, micro));
      return TCL_OK;
    case DBUS_INFOUUID:
      Tcl_SetObjResult(interp,
		       Tcl_NewStringObj(dbus_get_local_machine_id(), -1));
      return TCL_OK;
    case DBUS_INFOPATH:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_PATH_DBUS, -1));
      return TCL_OK;
    case DBUS_INFOLOCAL:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_PATH_LOCAL, -1));
      return TCL_OK;
    case DBUS_INFOSERVICE:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_SERVICE_DBUS, -1));
      return TCL_OK;
    default:
      /* Silence compiler warning */
      break;
   }

   /* Remaining subcommands require a dbus connection */
   if ((conn = DBus_GetConnection(interp, busname)) == NULL)
      return TCL_ERROR;

   switch ((enum options) index) {
    case DBUS_INFOSERVER:
      Tcl_SetObjResult(interp,
	Tcl_NewStringObj(dbus_connection_get_server_id(conn), -1));
      return TCL_OK;
    case DBUS_INFOPENDING:
      Tcl_SetObjResult(interp,
	Tcl_NewIntObj(dbus_connection_has_messages_to_send(conn)));
      return TCL_OK;
    case DBUS_INFONAME:
      Tcl_SetObjResult(interp,
	Tcl_NewStringObj(dbus_bus_get_unique_name(conn), -1));
      return TCL_OK;
    case DBUS_INFOCAPS:
      rc = Tcl_NewDictObj();
      sw = dbus_connection_can_send_type(conn, DBUS_TYPE_UNIX_FD);
      Tcl_DictObjPut(interp, rc,
		Tcl_NewStringObj("unixfd", -1), Tcl_NewBooleanObj(sw));
      Tcl_SetObjResult(interp, rc);
      return TCL_OK;
    default:
      /* Silence compiler warning */
      break;
   }
   /* Should never get here */
   return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusNameCmd
 *	Request the dbus server to assign a given name to the connection.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusNameCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   DBusConnection *conn;
   DBusError err;
   Tcl_Obj *busname = NULL, *result;
   int index, mask, ret, x = 1;
   static const char *options[] = {
      "-noqueue", "-replace", "-yield", NULL
   };
   static const int flag[] = {
      DBUS_NAME_FLAG_DO_NOT_QUEUE,
	DBUS_NAME_FLAG_REPLACE_EXISTING,
	DBUS_NAME_FLAG_ALLOW_REPLACEMENT
   };
   static const char *error[] = {
      "Name in use, request queued", "Name exists", "Already owner"
   };

   if (objc < 2) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? ?options? name");
      return TCL_ERROR;
   }
   if (objc > 2 && Tcl_GetStringFromObj(objv[1], NULL)[0] != '-')
      busname = objv[x++];
   conn = DBus_GetConnection(interp, busname);

   for (mask = 0; x < objc-1; x++) {
      if (Tcl_GetIndexFromObj(interp, objv[x], options,
			      "option", 0, &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      mask |= flag[index];
   }

   /* Check the bus name */
   if (!DBus_CheckBusName(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid bus name", -1));
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   /* initialise the dbus error structure */
   dbus_error_init(&err);
   /* request our name on the bus and check for errors */
   ret = dbus_bus_request_name(conn, Tcl_GetString(objv[x]), mask, &err);
   /*
    * DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER   1
    * DBUS_REQUEST_NAME_REPLY_IN_QUEUE        2
    * DBUS_REQUEST_NAME_REPLY_EXISTS          3
    * DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER   4
    */
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Name Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      Tcl_SetObjResult(interp, result);
      Tcl_DBusErrorCode(interp, "NAME", err);
      dbus_error_free(&err);
      return TCL_ERROR;
   }
   if (ret == DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER)
     return TCL_OK;
   /* Command failed or only partially succeeded */
   Tcl_SetObjResult(interp, Tcl_NewStringObj(error[ret-2], -1));
   return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusReleaseCmd
 *	Asks the dbus server to unassign the given name from this connection.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusReleaseCmd(ClientData dummy, Tcl_Interp *interp,
		int objc, Tcl_Obj *const objv[])
{
   DBusConnection *conn;
   DBusError err;
   Tcl_Obj *busname = NULL, *result;
   int ret;
   static const char *error[] = {
      "Name does not exist", "Not owner"
   };

   if (objc < 2 || objc > 3) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? name");
      return TCL_ERROR;
   }
   if (objc > 2)
      busname = objv[1];
   conn = DBus_GetConnection(interp, busname);

   /* Check the bus name */
   if (!DBus_CheckBusName(objv[objc - 1])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid bus name", -1));
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   /* initialise the dbus error structure */
   dbus_error_init(&err);

   /* release our name on the bus and check for errors */
   ret = dbus_bus_release_name(conn, Tcl_GetString(objv[objc - 1]), &err);
   /*
    * DBUS_RELEASE_NAME_REPLY_RELEASED       1
    * DBUS_RELEASE_NAME_REPLY_NON_EXISTENT   2
    * DBUS_RELEASE_NAME_REPLY_NOT_OWNER      3
    */
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Release Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      Tcl_SetObjResult(interp, result);
      Tcl_DBusErrorCode(interp, "RELEASE", err);
      dbus_error_free(&err);
      return TCL_ERROR;
   }
   if (ret == DBUS_RELEASE_NAME_REPLY_RELEASED)
     return TCL_OK;
   /* Name could not be released */
   Tcl_SetObjResult(interp, Tcl_NewStringObj(error[ret-2], -1));
   return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitDBusCmd
 *	Create the dbus ensemble command.
 *
 * Results:
 *	The command token for the ensemble.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Command TclInitDBusCmd(Tcl_Interp *interp)
{
   Tcl_Namespace *nsPtr;
   Tcl_Obj* subcmds;
   Tcl_Command rc;

   /* Create the dbus namespace if it doesn't exist */
   nsPtr = Tcl_FindNamespace(interp, "::dbus", NULL, 0);
   if (nsPtr == NULL)
     nsPtr = Tcl_CreateNamespace(interp, "::dbus", NULL, NULL);

   /* Create an empty list, reserving space for the expected elements */
   subcmds = Tcl_NewListObj(15, NULL);

   Tcl_CreateObjCommand(interp, "::dbus::call", DBusCallCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("call", -1));

   Tcl_CreateObjCommand(interp, "::dbus::close", DBusCloseCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("close", -1));

   Tcl_CreateObjCommand(interp, "::dbus::connect", DBusConnectCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("connect", -1));

   Tcl_CreateObjCommand(interp, "::dbus::error", DBusErrorCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("error", -1));

   Tcl_CreateObjCommand(interp, "::dbus::filter", DBusFilterCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("filter", -1));

   Tcl_CreateObjCommand(interp, "::dbus::info", DBusInfoCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("info", -1));

   Tcl_CreateObjCommand(interp, "::dbus::listen", DBusListenCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("listen", -1));

   Tcl_CreateObjCommand(interp, "::dbus::method", DBusMethodCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("method", -1));

   Tcl_CreateObjCommand(interp, "::dbus::monitor", DBusMonitorCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("monitor", -1));

   Tcl_CreateObjCommand(interp, "::dbus::name", DBusNameCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("name", -1));

   Tcl_CreateObjCommand(interp, "::dbus::release", DBusReleaseCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("release", -1));

   Tcl_CreateObjCommand(interp, "::dbus::return", DBusMethodReturnCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("return", -1));

   Tcl_CreateObjCommand(interp, "::dbus::signal", DBusSignalCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("signal", -1));

   Tcl_CreateObjCommand(interp, "::dbus::unknown", DBusUnknownCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("unknown", -1));

   Tcl_CreateObjCommand(interp, "::dbus::validate", DBusValidateCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   Tcl_ListObjAppendElement(NULL, subcmds, Tcl_NewStringObj("validate", -1));

   rc = Tcl_CreateEnsemble(interp, "::dbus", nsPtr, TCL_ENSEMBLE_PREFIX);
   Tcl_SetEnsembleSubcommandList(NULL, rc, subcmds);
   return rc;
}
