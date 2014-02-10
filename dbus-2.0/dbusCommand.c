#include "dbustcl.h"

static int dbusid = 0;

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
   DBusBusType type = DBUS_BUS_SESSION;
   Tcl_DBusBus *dbus;
   Tcl_HashEntry *busPtr, *hPtr;
   DBusConnection *conn;
   DBusError err;
   int isNew;
   
   Tcl_Obj *result, *name = NULL;

   if (objc > 2) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId?");
      return TCL_ERROR;
   }
   if (objc == 2) {
      name = objv[1];
      type = DBus_BusType(NULL, name);
   }

   /* initialise the dbus error structure */
   dbus_error_init(&err);

   /* connect to the bus and check for errors */
   switch (type) {
    case DBUS_BUS_SESSION:
    case DBUS_BUS_SYSTEM:
    case DBUS_BUS_STARTER:
      conn = dbus_bus_get(type, &err);
      break;
    default:
      conn = dbus_connection_open(Tcl_GetString(name), &err);
      if (conn != NULL && !dbus_error_is_set(&err)) {
	 dbus_bus_register(conn, &err); 
      }
      break;
   }
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Connection Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      Tcl_SetObjResult(interp, result);
      dbus_error_free(&err);
      return TCL_ERROR;
   }

   if (conn == NULL) {
      result = Tcl_NewStringObj("Connection Error", -1);
      Tcl_SetObjResult(interp, result);
      return TCL_ERROR;
   }

   if ((int)type < 0) {
      name = Tcl_ObjPrintf("dbus%d", ++dbusid);
      type = 3;
   }
   else if (name == NULL)
     name = Tcl_NewStringObj("session", 7);
   Tcl_IncrRefCount(name);
   busPtr = Tcl_CreateHashEntry(&bus, (char *) name, &isNew);
   if (isNew) {
      /* First interpreter to connect to this dbus */
      dbus = (Tcl_DBusBus *) ckalloc(sizeof(Tcl_DBusBus));
      dbus->conn = conn;
      dbus->type = (int)type;
      dbus->snoop = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(dbus->snoop, TCL_ONE_WORD_KEYS);
      dbus->fallback = NULL;
      Tcl_SetHashValue(busPtr, (ClientData) dbus);
      if (type == DBUS_BUS_SESSION) defaultbus = dbus;
   }
   else {
      dbus = Tcl_GetHashValue(busPtr);
   }
   hPtr = Tcl_CreateHashEntry(dbus->snoop, (char *) interp, &isNew);
   if (isNew) {
      /* Presence of the array entry indicates connection to the bus */
      Tcl_SetHashValue(hPtr, NULL);
      Tcl_CallWhenDeleted(interp, DBus_InterpDelete, busPtr);
   }

   dbus_connection_set_timeout_functions(conn, DBus_AddTimeout,
					    DBus_RemoveTimeout,
					    DBus_ToggleTimeout, NULL, NULL);

   /* Return the handle to the connection */
   Tcl_SetObjResult(interp, Tcl_DuplicateObj(name));
   Tcl_DecrRefCount(name);
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
   Tcl_HashEntry *entry;
   Tcl_Obj *name;

   if (objc < 1 || objc > 2) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId?");
      return TCL_ERROR;
   }
   if (objc < 2)
     name = Tcl_NewStringObj("session", -1);
   else
     name = objv[1];
   Tcl_IncrRefCount(name);
   entry = Tcl_FindHashEntry(&bus, (char *) name);
   if (entry != NULL) {
      DBus_Disconnect(interp, entry);
      Tcl_DontCallWhenDeleted(interp, DBus_InterpDelete, entry);
   }
   Tcl_DecrRefCount(name);
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
   Tcl_DBusBus *dbus = defaultbus;
   DBusError err;
   Tcl_Obj *match = NULL, *result;
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
   if ((objc & 1) == 1) {
      if (DBus_BusType(interp, objv[1]) < 0) return TCL_ERROR;
      dbus = DBus_GetConnection(interp, objv[1]);
      x++;
   }
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
   
   if (dbus == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Not connected", -1));
      return TCL_ERROR;
   }
   /* initialise the dbus error structure */
   dbus_error_init(&err);
   
   if ((enum subcmds) subcmd == DBUS_FILTERADD)
     dbus_bus_add_match(dbus->conn, Tcl_GetString(match), &err);
   else
     dbus_bus_remove_match(dbus->conn, Tcl_GetString(match), &err);
   dbus_connection_flush(dbus->conn);
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Match Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      /* Strip trailing newline off the error message */
      Tcl_SetObjLength(result, Tcl_GetCharLength(result) - 1);
      Tcl_SetObjResult(interp, result);
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
   Tcl_DBusBus *dbus = defaultbus;
   int index, major, minor, micro;
   static const char *options[] = {
      "machineid", "local", "name", "path", "pending", 
	"serverid", "service", "version", NULL
   };
   enum options {
      DBUS_INFOUUID, DBUS_INFOLOCAL, DBUS_INFONAME, DBUS_INFOPATH,
	DBUS_INFOPENDING, DBUS_INFOSERVER, DBUS_INFOSERVICE, DBUS_INFOVERSION
   };

   if (objc < 2 || objc > 3) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? option");
      return TCL_ERROR;
   }
   if (objc > 2) {
      if (DBus_BusType(interp, objv[1]) < 0) return TCL_ERROR;
      dbus = DBus_GetConnection(interp, objv[1]);
   }
   if (Tcl_GetIndexFromObj(interp, objv[objc - 1], options,
			   "option", 0, &index) != TCL_OK) {
      return TCL_ERROR;
   }

   if (dbus == NULL && 
       ((enum options) index == DBUS_INFONAME ||
	(enum options) index == DBUS_INFOPENDING || 
	(enum options) index == DBUS_INFOSERVER)) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Not connected", -1));
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
    case DBUS_INFOSERVER:
      Tcl_SetObjResult(interp,
	Tcl_NewStringObj(dbus_connection_get_server_id(dbus->conn), -1));
      return TCL_OK;
    case DBUS_INFOPENDING:
      Tcl_SetObjResult(interp,
	Tcl_NewIntObj(dbus_connection_has_messages_to_send(dbus->conn)));
      return TCL_OK;
    case DBUS_INFOPATH:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_PATH_DBUS, -1));
      return TCL_OK;
    case DBUS_INFONAME:
      Tcl_SetObjResult(interp,
	Tcl_NewStringObj(dbus_bus_get_unique_name(dbus->conn), -1));
      return TCL_OK;
    case DBUS_INFOLOCAL:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_PATH_LOCAL, -1));
      return TCL_OK;
    case DBUS_INFOSERVICE:
      Tcl_SetObjResult(interp, Tcl_NewStringObj(DBUS_SERVICE_DBUS, -1));
      return TCL_OK;
   }
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
   Tcl_DBusBus *dbus = defaultbus;
   DBusError err;
   Tcl_Obj *result;
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
   if (objc > 2 && Tcl_GetStringFromObj(objv[1], NULL)[0] != '-') {
      if (DBus_BusType(interp, objv[1]) < 0) return TCL_ERROR;
      dbus = DBus_GetConnection(interp, objv[1]);
      x++;
   }
   
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

   if (dbus == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Not connected", -1));
      return TCL_ERROR;
   }
   /* initialise the dbus error structure */
   dbus_error_init(&err);
   /* request our name on the bus and check for errors */
   ret = dbus_bus_request_name(dbus->conn, 
				  Tcl_GetString(objv[x]), mask, &err);
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
   Tcl_DBusBus *dbus = defaultbus;
   DBusError err;
   Tcl_Obj *result;
   int ret;
   static const char *error[] = {
      "Name does not exist", "Not owner"
   };
   
   if (objc < 2 || objc > 3) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? name");
      return TCL_ERROR;
   }
   if (objc > 2) {
      if (DBus_BusType(interp, objv[1]) < 0) return TCL_ERROR;
      dbus = DBus_GetConnection(interp, objv[1]);
   }

   /* Check the bus name */
   if (!DBus_CheckBusName(objv[objc - 1])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid bus name", -1));
      return TCL_ERROR;
   }
      
   if (dbus == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Not connected", -1));
      return TCL_ERROR;
   }
   /* initialise the dbus error structure */
   dbus_error_init(&err);

   /* release our name on the bus and check for errors */
   ret = dbus_bus_release_name(dbus->conn, 
				  Tcl_GetString(objv[objc - 1]), &err);
   /* 
    * DBUS_RELEASE_NAME_REPLY_RELEASED       1
    * DBUS_RELEASE_NAME_REPLY_NON_EXISTENT   2
    * DBUS_RELEASE_NAME_REPLY_NOT_OWNER      3
    */
   if (dbus_error_is_set(&err)) {
      result = Tcl_NewStringObj("Release Error: ", -1);
      Tcl_AppendStringsToObj(result, err.message, (char *) NULL);
      Tcl_SetObjResult(interp, result);
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
   Tcl_Obj* subcmdlist[15];
   Tcl_Command rc;
   int x = 0;

   /* Create the dbus namespace if it doesn't exist */
   nsPtr = Tcl_FindNamespace(interp, "::dbus", NULL, 0);
   if (nsPtr == NULL)
     nsPtr = Tcl_CreateNamespace(interp, "::dbus", NULL, NULL);

   Tcl_CreateObjCommand(interp, "::dbus::call", DBusCallCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("call", -1);

   Tcl_CreateObjCommand(interp, "::dbus::close", DBusCloseCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("close", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::connect", DBusConnectCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("connect", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::error", DBusErrorCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("error", -1);

   Tcl_CreateObjCommand(interp, "::dbus::filter", DBusFilterCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("filter", -1);

   Tcl_CreateObjCommand(interp, "::dbus::info", DBusInfoCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("info", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::listen", DBusListenCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("listen", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::method", DBusMethodCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("method", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::monitor", DBusMonitorCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("monitor", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::name", DBusNameCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("name", -1);
   
   Tcl_CreateObjCommand(interp, "::dbus::release", DBusReleaseCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("release", -1);

   Tcl_CreateObjCommand(interp, "::dbus::return", DBusMethodReturnCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("return", -1);

   Tcl_CreateObjCommand(interp, "::dbus::signal", DBusSignalCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("signal", -1);

   Tcl_CreateObjCommand(interp, "::dbus::unknown", DBusUnknownCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("unknown", -1);

   Tcl_CreateObjCommand(interp, "::dbus::validate", DBusValidateCmd,
			(ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
   subcmdlist[x++] = Tcl_NewStringObj("validate", -1);

   rc = Tcl_CreateEnsemble(interp, "::dbus", nsPtr, TCL_ENSEMBLE_PREFIX);
   Tcl_SetEnsembleSubcommandList(NULL, rc, Tcl_NewListObj(x, subcmdlist));
   return rc;
}
