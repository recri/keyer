#include "dbustcl.h"

#define DBUS_RECURSEFLAG 1
#define DBUS_METHODFLAG 2
#define DBUS_UNKNOWNFLAG 4

/*
 *----------------------------------------------------------------------
 * DBus_GetMessageHandler
 *
 *	Get a pointer to the D-Bus message handler data at a specific
 *	path. If no message handler exists for the specified path, a new
 *	handler	will be created.
 *----------------------------------------------------------------------
 */

Tcl_DBusHandlerData *DBus_GetMessageHandler(Tcl_Interp *interp,
	DBusConnection *conn, char *path)
{
   DBusObjectPathVTable vtable;
   Tcl_DBusBus *dbus;
   Tcl_DBusHandlerData *dataPtr;

   /* Get the currently registered handler for the path */
   if (*path == '\0') {
      if (!dbus_connection_get_object_path_data(conn, "/",
		(void **)&dataPtr)) return NULL;
   }
   else {
      if (!dbus_connection_get_object_path_data(conn, path,
		(void **)&dataPtr)) return NULL;
   }
   if (dataPtr == NULL) {
      /* No handler currently exists - create a new one */
      vtable.message_function = DBus_Message;
      vtable.unregister_function = DBus_Unregister;
      dataPtr = (Tcl_DBusHandlerData *)ckalloc(sizeof(Tcl_DBusHandlerData));
      dataPtr->signal = NULL;
      dataPtr->method = NULL;
      dataPtr->flags = 0;
      if (path[0] == '\0' || (path[0] == '/' && path[1] == '\0')) {
	 /* Register as a fallback method handler */
	 if (!dbus_connection_register_fallback(conn, "/",
						&vtable, dataPtr))
	   return NULL;
	 dataPtr->flags |= DBUSFLAG_FALLBACK;
      }
      else {
	 /* Register as a regular method handler */
	 if (!dbus_connection_register_object_path(conn, path,
						      &vtable, dataPtr))
	   return NULL;
      }
   }
   if (*path == '\0') {
      dbus = dbus_connection_get_data(conn, dataSlot);
      if (dbus->fallback != NULL)
	return dbus->fallback;
      dataPtr = (Tcl_DBusHandlerData *)ckalloc(sizeof(Tcl_DBusHandlerData));
      dataPtr->signal = NULL;
      dataPtr->method = NULL;
      dbus->fallback = dataPtr;
   }
   return dataPtr;
}

/*
 *----------------------------------------------------------------------
 * DBus_CleanUpHandler
 *----------------------------------------------------------------------
 */

void DBus_CleanUpHandler(Tcl_DBusBus *dbus, char *path)
{

}

/*
 *----------------------------------------------------------------------
 *
 * DBus_EventHandler --
 *
 * 	Handle a queued event by calling a Tcl script and, if necessary,
 * 	send out a message_return or error message to the DBus with the
 * 	result of the Tcl script.
 *
 * Results:
 * 	Boolean indicating the event was processed.
 *
 * Side effects:
 * 	Release the Tcl script object and the DBus message object
 * 	referenced in the Tcl_Event structure.
 *
 *----------------------------------------------------------------------
 */

static int DBus_EventHandler(Tcl_Event *evPtr, int flags)
{
   Tcl_DBusEvent *ev;
   DBusMessageIter iter;
   Tcl_Obj *script, *retopts, *key, *value, *list;
   int rc, defer;

   if (!(flags & TCL_IDLE_EVENTS)) return 0;
   ev = (Tcl_DBusEvent *) evPtr;
   script = ev->script;
   /* The script should actually never be shared */
   if (Tcl_IsShared(script)) {
      script = Tcl_DuplicateObj(script);
      Tcl_IncrRefCount(script);
      Tcl_DecrRefCount(ev->script);
   }
   Tcl_ListObjAppendElement(ev->interp, script,
			    DBus_MessageInfo(ev->interp, ev->msg));
   /* read the parameters and append to the script */
   if (dbus_message_iter_init(ev->msg, &iter)) {
      list = DBus_IterList(ev->interp, &iter,
			   (ev->flags & DBUSFLAG_DETAILS) != 0);
      Tcl_ListObjAppendList(ev->interp, script, list);
      Tcl_DecrRefCount(list);
   }
   /* Excute the constructed Tcl command */
   Tcl_Preserve(ev->interp);
   rc = Tcl_EvalObjEx(ev->interp, script, TCL_EVAL_GLOBAL);
   if (rc != TCL_ERROR) {
      /* Report success only if noreply == 0 and async == 0 */
      if (!(ev->flags & DBUSFLAG_NOREPLY) && !(ev->flags & DBUSFLAG_ASYNC)) {
	 retopts = Tcl_GetReturnOptions(ev->interp, rc);
	 key = Tcl_NewStringObj("-async", 6);
	 Tcl_DictObjGet(NULL, retopts, key, &value);
	 Tcl_DecrRefCount(key);
	 if (value == NULL ||
	     Tcl_GetBooleanFromObj(NULL, value, &defer) != TCL_OK)
	   defer = 0;
	 if (!defer) {
	    /* read the parameters and append to the script */;
	    value = Tcl_GetObjResult(ev->interp);
	    DBus_SendMessage(ev->interp, ev->conn,
		DBUS_MESSAGE_TYPE_METHOD_RETURN, NULL, NULL, NULL,
		dbus_message_get_sender(ev->msg),
		dbus_message_get_serial(ev->msg),
		NULL, 1, &value);
	 }
	 Tcl_DecrRefCount(retopts);
      }
   } else {
      /* Always report failures if noreply == 0 */
      if (!(ev->flags & DBUSFLAG_NOREPLY)) {
	 value = Tcl_GetObjResult(ev->interp);
	 DBus_Error(ev->interp, ev->conn, NULL,
		dbus_message_get_sender(ev->msg),
		dbus_message_get_serial(ev->msg),
		Tcl_GetString(value));
      }
   }
   Tcl_Release(ev->interp);
   dbus_message_unref(ev->msg);
   Tcl_DecrRefCount(script);
   /* The event structure will be cleaned up by Tcl_ServiceEvent */
#ifdef DBUS_MEM_DEBUG
   printf("Free %p is left to Tcl_ServiceEvent() (%s:%d)\n",
	  evPtr, __FILE__, __LINE__);
#endif
   return 1;
}

#ifdef _WIN32
void DBus_SetupProc(ClientData data, int flags)
{
   Tcl_Time blockTime;
   Tcl_HashEntry *hPtr;
   Tcl_HashSearch search;
   DBusConnection *conn;
   DBusDispatchStatus status;

   if (!(flags & TCL_FILE_EVENTS))
      return;

   blockTime.sec = 0;
   blockTime.usec = 100000;
   /* Check the incoming message queues */
   for (hPtr = Tcl_FirstHashEntry(&bus, &search); hPtr != NULL;
	hPtr = Tcl_NextHashEntry(&search)) {
      conn = (DBusConnection *)Tcl_GetHashValue(hPtr);
      if (conn != NULL) {
	 dbus_connection_read_write(conn, 0);
	 status = dbus_connection_get_dispatch_status(conn);
	 if (status == DBUS_DISPATCH_DATA_REMAINS) {
	    blockTime.sec = 0;
	    blockTime.usec = 0;
	    break;
	 }
      }
   }
   Tcl_SetMaxBlockTime(&blockTime);
}

void DBus_CheckProc(ClientData data, int flags)
{
   Tcl_HashEntry *hPtr;
   Tcl_HashSearch search;
   DBusConnection *conn;
   DBusDispatchStatus dispatch;

   if (!(flags & TCL_IDLE_EVENTS)) return;
   for (hPtr = Tcl_FirstHashEntry(&bus, &search); hPtr != NULL;
	hPtr = Tcl_NextHashEntry(&search)) {
      conn = (DBusConnection *) Tcl_GetHashValue(hPtr);
      if (conn != NULL) {
	  /* Drain the message queue */
	  do
	    dispatch = dbus_connection_dispatch(conn);
	  while (dispatch == DBUS_DISPATCH_DATA_REMAINS);
      }
   }
}
#endif

/*
 *----------------------------------------------------------------------
 */

ClientData DBus_FindListeners(DBusConnection *conn,
	const char *path, const char *name, int method)
{
   Tcl_DBusBus *dbus;
   Tcl_DBusHandlerData *dataPtr;
   Tcl_HashTable *tablePtr;
   Tcl_HashEntry *hPtr;

   /* Get the currently registered handler for signal/method and path */
   if (*path == '\0') {
      dbus = dbus_connection_get_data(conn, dataSlot);
      dataPtr = dbus->fallback;
   } else {
      if (!dbus_connection_get_object_path_data(conn, path, (void **)&dataPtr))
	 return NULL;
   }
   /* Check if any handler is registered for this path */
   if (dataPtr == NULL) return NULL;
   if (method)
     tablePtr = dataPtr->method;
   else
     tablePtr = dataPtr->signal;
   /* Check if any handlers are registered for this path */
   if (tablePtr == NULL) return NULL;
   /* Check if a handler with the specified name was registered */
   hPtr = Tcl_FindHashEntry(tablePtr, name);
   if (hPtr == NULL) return NULL;
   return Tcl_GetHashValue(hPtr);
}

/*
 *----------------------------------------------------------------------
 */

DBusHandlerResult DBus_Message(DBusConnection *conn,
	DBusMessage *msg, void *data)
{
   Tcl_HashTable *members;
   Tcl_HashEntry *memberPtr;
   Tcl_HashSearch search;
   Tcl_DBusEvent *evPtr;
   Tcl_DBusMethodData *mPtr = NULL;
   Tcl_DBusSignalData *sPtr;
   DBusMessage *err;
   int i, len;
   char buffer[DBUS_MAXIMUM_NAME_LENGTH + 1], *errbuf;
   const char *path, *name, *intf, *str[2];

   path = dbus_message_get_path(msg);
   intf = dbus_message_get_interface(msg);
   name = dbus_message_get_member(msg);
   if (intf != NULL) {
      intf = strncpy(buffer, intf, DBUS_MAXIMUM_NAME_LENGTH);
      buffer[DBUS_MAXIMUM_NAME_LENGTH] = '\0';
      len = strlen(intf);
      buffer[len++] = '.';
      name = strncpy(buffer + len, name, DBUS_MAXIMUM_NAME_LENGTH - len);
   }
   switch (dbus_message_get_type(msg)) {
    case DBUS_MESSAGE_TYPE_METHOD_CALL:
      if (intf != NULL) {
	 mPtr = DBus_FindListeners(conn, path, intf, TRUE);
	 if (mPtr == NULL) {
	    /* Check if a method was defined without a path */
	    mPtr = DBus_FindListeners(conn, "", intf, TRUE);
	 }
      }
      if (intf == NULL || mPtr == NULL) {
	 /* TODO: Method calls are not required to specify an interface */
	 /* So should really also check for *.name if intf == NULL */

	 /* Check if a method was defined without an interface */
	 mPtr = DBus_FindListeners(conn, path, name, TRUE);
	 if (mPtr == NULL) {
	    /* Check if a method was defined with no path and no interface */
	    mPtr = DBus_FindListeners(conn, "", name, TRUE);
	 }
      }
      if (mPtr == NULL) {
	  /* Check if an unknown handler was defined for the path */
	  mPtr = DBus_FindListeners(conn, path, "", TRUE);
	  if (mPtr == NULL) {
	      /* Check if a global unknown handler was defined */
	      mPtr = DBus_FindListeners(conn, "", "", TRUE);
	  }
      }
      if (mPtr == NULL) {
	  /* There is no script-level handler for this method call */
	  if (dbus_message_get_no_reply(msg))
	    /* The caller is not interested in succes or failure */
	    break;
	  /* Allocate space and construct the error message */
	  /* Each of name, interface, and signature can only be 255 chars */
	  /* long, but path is unlimited. So base the amount of space */
	  /* to request on the length of the path string */
	  if ((errbuf = attemptckalloc(strlen(path) + 1024)) != NULL) {
	      sprintf(errbuf, "No such method '%s' in interface '%s' "
		      "at object path '%s' (signature '%s')",
		      name, dbus_message_get_interface(msg),
		      path, dbus_message_get_signature(msg));
	  }
	  /* Send the error back to the caller */
	  err = dbus_message_new_error(msg, DBUS_ERROR_UNKNOWN_METHOD, errbuf);
	  if (dbus_connection_send(conn, err, NULL)) {
#ifdef _WIN32
	      dbus_connection_flush(conn);
#endif
	  }
	  /* Free up the used resources */
	  dbus_message_unref(err);
	  if (errbuf != NULL) ckfree(errbuf);
	  break;
      }
      evPtr = (Tcl_DBusEvent *) ckalloc(sizeof(Tcl_DBusEvent));
      evPtr->event.proc = DBus_EventHandler;
      evPtr->interp = mPtr->interp;
      evPtr->script = Tcl_DuplicateObj(mPtr->script);
      Tcl_IncrRefCount(evPtr->script);
      evPtr->conn = mPtr->conn;
      evPtr->msg = msg;
      evPtr->flags = mPtr->flags;
      dbus_message_ref(msg);
      if (dbus_message_get_no_reply(msg))
	/* Don't report the result of the event handler */
	evPtr->flags |= DBUSFLAG_NOREPLY;
      Tcl_QueueEvent((Tcl_Event *) evPtr, TCL_QUEUE_TAIL);
      break;
    case DBUS_MESSAGE_TYPE_METHOD_RETURN:
      break;
    case DBUS_MESSAGE_TYPE_ERROR:
      break;
    case DBUS_MESSAGE_TYPE_SIGNAL:
      str[0] = intf; str[1] = name;
      for (i = 0; i < 2; i++) {
	 if (str[i] == NULL) continue;
	 members = DBus_FindListeners(conn, path, str[i], FALSE);
	 if (members == NULL) {
	    members = DBus_FindListeners(conn, "", str[i], FALSE);
	    if (members == NULL) continue;
	 }
	 /* Queue execution of listeners for this signal in all interpreters */
	 for (memberPtr = Tcl_FirstHashEntry(members, &search);
	      memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
	    evPtr = (Tcl_DBusEvent *) ckalloc(sizeof(Tcl_DBusEvent));
	    sPtr = (Tcl_DBusSignalData *) Tcl_GetHashValue(memberPtr);
	    evPtr->event.proc = DBus_EventHandler;
	    evPtr->interp = (Tcl_Interp *) Tcl_GetHashKey(members, memberPtr);
	    evPtr->script = Tcl_DuplicateObj(sPtr->script);
	    Tcl_IncrRefCount(evPtr->script);
	    evPtr->conn = conn;
	    evPtr->msg = msg;
	    /* Never report the result of a signal handler */
	    evPtr->flags = sPtr->flags | DBUSFLAG_NOREPLY;
	    dbus_message_ref(msg);
	    Tcl_QueueEvent((Tcl_Event *) evPtr, TCL_QUEUE_TAIL);
	 }
      }
      break;
   }
   return DBUS_HANDLER_RESULT_HANDLED;
}

void DBus_Unregister(DBusConnection *conn, void *data)
{
}

void DBus_CallResult(DBusPendingCall *pending, void *data)
{
   DBusMessage *msg;
   Tcl_CallData *dataPtr = data;
   Tcl_DBusEvent *evPtr;

   msg = dbus_pending_call_steal_reply(pending);
   /* free the pending message handle */
   dbus_pending_call_unref(pending);
   /* Allocate a DBus event structure and copy in some basic data */
   evPtr = (Tcl_DBusEvent *) ckalloc(sizeof(Tcl_DBusEvent));
   evPtr->interp = dataPtr->interp;
   evPtr->script = dataPtr->script;
   evPtr->conn = dataPtr->conn;
   /* Fill in the rest of the DBus event structure */
   evPtr->event.proc = DBus_EventHandler;
   evPtr->msg = msg;
   /* Don't send a reply on the reply */
   evPtr->flags = dataPtr->flags | DBUSFLAG_NOREPLY;
   Tcl_QueueEvent((Tcl_Event *) evPtr, TCL_QUEUE_TAIL);
   /* Free the DBus handler data structure */
   ckfree(data);
}

void DBus_FreeTimeout(void *memory)
{
   Tcl_TimerToken token = memory;
   Tcl_DeleteTimerHandler(token);
}

void DBus_Timeout(ClientData timeout)
{
   Tcl_TimerToken token;

   dbus_timeout_handle(timeout);
   /* Must restart the timeout until it is removed */
   token = Tcl_CreateTimerHandler(dbus_timeout_get_interval(timeout),
				  DBus_Timeout, timeout);
   dbus_timeout_set_data(timeout, token, DBus_FreeTimeout);
}

dbus_bool_t DBus_AddTimeout(DBusTimeout *timeout, void *data)
{
   Tcl_TimerToken token;

   /* The same timeout value may be added multiple times */
   token = dbus_timeout_get_data(timeout);
   if (token != NULL)
     Tcl_DeleteTimerHandler(token);

   token = Tcl_CreateTimerHandler(dbus_timeout_get_interval(timeout),
				   DBus_Timeout, timeout);
   dbus_timeout_set_data(timeout, token, DBus_FreeTimeout);
   return TRUE;
}

void DBus_RemoveTimeout(DBusTimeout *timeout, void *data)
{
   Tcl_TimerToken token;

   /* Multiple removes are harmless */
   token = dbus_timeout_get_data(timeout);
   Tcl_DeleteTimerHandler(token);
}

void DBus_ToggleTimeout(DBusTimeout *timeout, void *data)
{
   if (dbus_timeout_get_enabled(timeout)) {
      DBus_AddTimeout(timeout, data);
   } else {
      DBus_RemoveTimeout(timeout, data);
   }
}

#ifndef _WIN32

static void DBus_FileHandler(ClientData data, int mask)
{
   DBusWatch *watch = (DBusWatch *)data;
   unsigned int flags = 0;

   if (mask & TCL_EXCEPTION) flags |= DBUS_WATCH_ERROR;
   if (mask & TCL_READABLE) flags |= DBUS_WATCH_READABLE;
   if (mask & TCL_WRITABLE) flags |= DBUS_WATCH_WRITABLE;

   dbus_watch_handle(watch, flags);
}

dbus_bool_t DBus_ModifyWatch(DBusWatch *watch, void *data, int enabled)
{
   Tcl_DBusWatchData *watchData = (Tcl_DBusWatchData *)data;
   unsigned int flags = dbus_watch_get_flags(watch);
   int fd, mask = 0;

   /* Assumption: Read and write side of a dbus connection use the same fd */
   if (watchData->chan == NULL) {
      fd = dbus_watch_get_unix_fd(watch);
      watchData->chan = Tcl_MakeFileChannel(INT2PTR(fd),
					    TCL_READABLE | TCL_WRITABLE);
      Tcl_RegisterChannel(NULL, watchData->chan);
   }

   /* Convert dbus flags to Tcl flags */
   if (flags & DBUS_WATCH_READABLE) mask |= TCL_READABLE;
   if (flags & DBUS_WATCH_WRITABLE) mask |= TCL_WRITABLE;

   if (enabled)
     Tcl_CreateChannelHandler(watchData->chan, mask, DBus_FileHandler, watch);
   else
     Tcl_DeleteChannelHandler(watchData->chan, DBus_FileHandler, watch);

   return TRUE;
}

dbus_bool_t DBus_AddWatch(DBusWatch *watch, void *data)
{
   return DBus_ModifyWatch(watch, data, dbus_watch_get_enabled(watch));
}

void DBus_RemoveWatch(DBusWatch *watch, void *data)
{
   DBus_ModifyWatch(watch, data, 0);
}

void DBus_ToggleWatch(DBusWatch *watch, void *data)
{
   DBus_ModifyWatch(watch, data, dbus_watch_get_enabled(watch));
}
#endif

/*
 *----------------------------------------------------------------------
 *
 * DBus_ListListeners
 *	Check if a signal handler is registered by the specified interpreter
 *	for the specified path. Then otionally find the children of the path
 *	and call itself recursively for each child to generate a list with
 *	all registered handlers in the subtree.
 *
 * Results:
 * 	A list consisting of alternating paths and registered listeners.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *DBus_ListListeners(Tcl_Interp *interp,
	DBusConnection *conn, const char *path, int flags)
{
   Tcl_DBusBus *dbus;
   Tcl_Obj *list, *sublist;
   char **entries, **entry, *newpath, *pathentry, *s;
   Tcl_DBusHandlerData *data;
   Tcl_DBusSignalData *signal;
   Tcl_DBusMethodData *method;
   Tcl_HashTable *interps;
   Tcl_HashEntry *memberPtr, *interpPtr;
   Tcl_HashSearch search;

   list = Tcl_NewObj();

   /* Check if the specified path has a handler defined */
   if (*path == '\0') {
      dbus = dbus_connection_get_data(conn, dataSlot);
      data = dbus->fallback;
   } else {
      dbus_connection_get_object_path_data(conn, path, (void **)&data);
   }
   if (data != NULL) {
      if ((flags & DBUS_METHODFLAG) == 0 && data->signal != NULL) {
	 for (memberPtr = Tcl_FirstHashEntry(data->signal, &search);
	      memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
	    interps = Tcl_GetHashValue(memberPtr);
	    interpPtr = Tcl_FindHashEntry(interps, (char *) interp);
	    if (interpPtr != NULL) {
	       signal = Tcl_GetHashValue(interpPtr);
	       /* Report both the path and the script configured for the path */
	       Tcl_ListObjAppendElement(NULL, list, Tcl_NewStringObj(path, -1));
	       s = Tcl_GetHashKey(data->signal, memberPtr);
	       Tcl_ListObjAppendElement(NULL, list, Tcl_NewStringObj(s, -1));
	       Tcl_ListObjAppendElement(NULL, list, signal->script);
	    }
	 }
      } else if ((flags & DBUS_METHODFLAG) != 0 && data->method != NULL) {
	 for (memberPtr = Tcl_FirstHashEntry(data->method, &search);
	      memberPtr != NULL; memberPtr = Tcl_NextHashEntry(&search)) {
	    method = Tcl_GetHashValue(memberPtr);
	    if (method->interp == interp) {
	       s = Tcl_GetHashKey(data->method, memberPtr);
	       /* Normally skip unknown handlers. But when listing */
	       /* unknown handlers, skip all named handlers. */
	       if (!(flags & DBUS_UNKNOWNFLAG) == (*s == '\0')) continue;
	       /* Report both the path and the script configured for the path */
	       Tcl_ListObjAppendElement(NULL, list, Tcl_NewStringObj(path, -1));
	       /* There is no method name for unknown handlers */
	       if (!(flags & DBUS_UNKNOWNFLAG))
		 Tcl_ListObjAppendElement(NULL, list, Tcl_NewStringObj(s, -1));
	       Tcl_ListObjAppendElement(NULL, list, method->script);
	    }
	 }
      }
   }
   if (flags & DBUS_RECURSEFLAG) {
      /* Get a list of children of the current path */
      dbus_connection_list_registered(conn, path, &entries);
      /* Allocate space for concatenating the path and a childs name */
      newpath = ckalloc(strlen(path) + 256);
      /* Copy the path in the allocated space, making sure it ends with a / */
      strcpy(newpath, path);
      pathentry = newpath + strlen(path) - 1;
      if (*pathentry++ != '/') *pathentry++ = '/';
      /* Append each childs name to the path in turn */
      for (entry = entries; *entry != NULL; entry++) {
	 strncpy(pathentry, *entry, 255);
	 /* Get a list of descendents from the child */
	 sublist = DBus_ListListeners(interp, conn, newpath, flags);
	 /* Append the sublist entries to the total list */
	 Tcl_ListObjAppendList(NULL, list, sublist);
	 /* Release the temporary sublist */
	 Tcl_DecrRefCount(sublist);
      }
      /* Release the entries array */
      dbus_free_string_array(entries);
      ckfree(newpath);
   }
   return list;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusListenCmd
 *	Register a script to be called when a signal with a specific
 *	path is received.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusListenCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_DBusBus *dbus;
   Tcl_DBusHandlerData *data;
   Tcl_DBusSignalData *signal;
   Tcl_HashTable *interps;
   Tcl_HashEntry *memberPtr, *interpPtr;
   DBusConnection *conn;
   int x = 1, flags = 0, index, isNew;
   char c, *path = NULL;
   Tcl_Obj *busname = NULL, *name = NULL, *handler = NULL, *result, *extra;
   static const char *options[] = {"-details", NULL};
   enum options {DBUS_DETAILS};

   if (objc > 1) {
      c = Tcl_GetString(objv[1])[0];
      /* Options start with '-', path starts with '/' or is "" */
      /* Anything else has to be a busId specification */
      if (c != '/' && c != '-' && c != '\0')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   for (; x < objc; x++) {
      c = Tcl_GetString(objv[x])[0];
      if (c != '-') break;
      if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
			      &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      switch ((enum options) index) {
       case DBUS_DETAILS:
	 flags |= DBUSFLAG_DETAILS;
	 break;
      }
   }

   if (x < objc) {
      if (Tcl_GetCharLength(objv[x]) > 0 && !DBus_CheckPath(objv[x])) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid path", -1));
	 return TCL_ERROR;
      }
      path = Tcl_GetString(objv[x++]);
   }
   if (x < objc) {
      if (!DBus_CheckMember(objv[x]) && DBus_CheckIntfName(objv[x]) < 2) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid signal name", -1));
	 return TCL_ERROR;
      }
      name = objv[x++];
   }
   if (x < objc) {
      handler = objv[x++];
   }

   if (x != objc) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? ?options? "
		       "?path ?signal ?script???");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (handler == NULL) {
      /* Request for a report on currently registered handler(s) */
      if (path == NULL) {
	 /* Get all handlers for any path */
	 result = DBus_ListListeners(interp, conn, "", 0);
	 /* Append the registered handlers from the root path */
	 extra = DBus_ListListeners(interp, conn, "/", DBUS_RECURSEFLAG);
	 Tcl_ListObjAppendList(NULL, result, extra);
	 Tcl_DecrRefCount(extra);

	 Tcl_SetObjResult(interp, result);
	 return TCL_OK;
      }
      if (name == NULL) {
	 /* Report all currently registered handlers at the specified path */
	 Tcl_SetObjResult(interp,
		DBus_ListListeners(interp, conn, path, 0));
	 return TCL_OK;
      }
      interps = DBus_FindListeners(conn, path, Tcl_GetString(name), FALSE);
      if (interps != NULL) {
	 /* Check if a signal handler was registered by the current interp */
	 memberPtr = Tcl_FindHashEntry(interps, (char * ) interp);
	 if (memberPtr != NULL) {
	    /* Return the script configured for the handler */
	    signal = Tcl_GetHashValue(memberPtr);
	    Tcl_IncrRefCount(signal->script);
	    Tcl_SetObjResult(interp, signal->script);
	 }
      }
      return TCL_OK;
   }

   if (Tcl_GetCharLength(handler) == 0) {
      /* Unregistering a handler */
      dbus = dbus_connection_get_data(conn, dataSlot);
      if (*path != '\0') {
	 if (!dbus_connection_get_object_path_data(conn, path,
						   (void **)&data))
	   return DBus_MemoryError(interp);
      } else {
	 data = dbus->fallback;
      }
      if (data == NULL) return TCL_OK;
      if (data->signal == NULL) return TCL_OK;
      memberPtr = Tcl_FindHashEntry(data->signal, Tcl_GetString(name));
      if (memberPtr == NULL) return TCL_OK;
      interps = Tcl_GetHashValue(memberPtr);
      interpPtr = Tcl_FindHashEntry(interps, (char *) interp);
      if (interpPtr == NULL) return TCL_OK;
      signal = Tcl_GetHashValue(interpPtr);
      Tcl_DecrRefCount(signal->script);
      ckfree((char *) signal);
      Tcl_DeleteHashEntry(interpPtr);
      /* Clean up the message handler, if no longer used */
      if (Tcl_CheckHashEmpty(interps)) {
	 Tcl_DeleteHashTable(interps);
	 ckfree((char *) interps);
	 Tcl_DeleteHashEntry(memberPtr);
	 if (Tcl_CheckHashEmpty(data->signal)) {
	    Tcl_DeleteHashTable(data->signal);
	    ckfree((char *) data->signal);
	    data->signal = NULL;
	    if (data->method == NULL && !(data->flags & DBUSFLAG_FALLBACK)) {
	       ckfree((char *) data);
	       if (*path != '\0')
		 dbus_connection_unregister_object_path(conn, path);
	       else
		 dbus->fallback = NULL;
	    }
	 }
      }
      return TCL_OK;
   }

   /* Register the new handler */
   data = DBus_GetMessageHandler(interp, conn, path);
   if (data->signal == NULL) {
      /* No signals have been defined for this path by any interpreter yet
         So first a hash table indexed by interpreter must be created */
      data->signal = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(data->signal, TCL_STRING_KEYS);
   }
   memberPtr = Tcl_CreateHashEntry(data->signal, Tcl_GetString(name), &isNew);
   if (isNew) {
      interps = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(interps, TCL_ONE_WORD_KEYS);
      Tcl_SetHashValue(memberPtr, (ClientData) interps);
   } else {
      interps = Tcl_GetHashValue(memberPtr);
   }
   /* Find the entry for the current interpreter */
   memberPtr = Tcl_CreateHashEntry(interps, (char *) interp, &isNew);
   if (isNew) {
      signal = (Tcl_DBusSignalData *) ckalloc(sizeof(Tcl_DBusSignalData));
      Tcl_SetHashValue(memberPtr, signal);
   } else {
      /* Release the old script */
      signal = Tcl_GetHashValue(memberPtr);
      Tcl_DecrRefCount(signal->script);
   }
   /* Create a private copy of the handler to avoid problems */
   /* in a threaded environment */
   signal->script = Tcl_DuplicateObj(handler);
   Tcl_IncrRefCount(signal->script);
   signal->flags = flags;
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusMethodCmd
 *	Register a script to be called when a call for a method at a
 *	specific path is received.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusMethodCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_DBusBus *dbus;
   Tcl_DBusHandlerData *data;
   Tcl_DBusMethodData *method;
   Tcl_HashEntry *memberPtr;
   DBusConnection *conn;
   int x = 1, flags = 0, isNew, index;
   char c, *str, *path = NULL;
   Tcl_Obj *busname = NULL, *name = NULL, *handler = NULL, *result, *extra;
   static const char *options[] = {"-async", "-details", NULL};
   enum options {DBUS_ASYNC, DBUS_DETAILS};

   if (objc > 1) {
      c = Tcl_GetString(objv[1])[0];
      /* Options start with '-', path starts with '/' or is "" */
      /* Anything else has to be a busId specification */
      if (c != '/' && c != '-' && c != '\0')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   for (; x < objc; x++) {
      str = Tcl_GetString(objv[x]);
      if (*str != '-') break;
      if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
			      &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      switch ((enum options) index) {
       case DBUS_ASYNC:
	 flags |= DBUSFLAG_ASYNC;
	 break;
       case DBUS_DETAILS:
	 flags |= DBUSFLAG_DETAILS;
	 break;
      }
   }

   if (x < objc) {
      if (*str != '\0' && !DBus_CheckPath(objv[x])) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid path", -1));
	 return TCL_ERROR;
      }
      path = Tcl_GetString(objv[x++]);
   }
   if (x < objc) {
      if (!DBus_CheckMember(objv[x]) && DBus_CheckIntfName(objv[x]) < 2) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid method name", -1));
	 return TCL_ERROR;
      }
      name = objv[x++];
   }
   if (x < objc) {
      handler = objv[x++];
   }

   if (x != objc) {
      Tcl_WrongNumArgs(interp, 1, objv,
		       "?busId? ?options? ?path ?method ?script???");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (handler == NULL) {
      /* Request for a report on currently registered handler(s) */
      if (flags & DBUSFLAG_ASYNC) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("The -async option "
		"is not applicable for querying method handlers", -1));
	 return TCL_ERROR;
      }
      if (path == NULL) {
	 /* Get all handlers for any path */
	 result = DBus_ListListeners(interp, conn, "", DBUS_METHODFLAG);
	 /* append all currently registered handlers from the root path */
	 extra = DBus_ListListeners(interp, conn, "/",
				    DBUS_METHODFLAG | DBUS_RECURSEFLAG);
	 Tcl_ListObjAppendList(NULL, result, extra);
	 Tcl_DecrRefCount(extra);
	 Tcl_SetObjResult(interp, result);
	 return TCL_OK;
      }
      if (name == NULL) {
	 /* Report all currently registered handlers at the specified path */
	 Tcl_SetObjResult(interp,
		DBus_ListListeners(interp, conn, path, DBUS_METHODFLAG));
	 return TCL_OK;
      }
      method = DBus_FindListeners(conn, path, Tcl_GetString(name), TRUE);
      if (method != NULL && method->interp == interp) {
	 /* Return the script configured for the handler */
	 Tcl_IncrRefCount(method->script);
	 Tcl_SetObjResult(interp, method->script);
      }
      return TCL_OK;
   }

   if (Tcl_GetCharLength(handler) == 0) {
      /* Unregistering a handler */
      dbus = dbus_connection_get_data(conn, dataSlot);
      if (flags & DBUSFLAG_ASYNC) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("The -async option "
		"is not applicable for unregistering method handlers", -1));
	 return TCL_ERROR;
      }
      if (*path != '\0') {
	 if (!dbus_connection_get_object_path_data(conn, path,
						   (void **)&data))
	   return DBus_MemoryError(interp);
      }
      else {
	 data = dbus->fallback;
      }
      if (data == NULL) return TCL_OK;
      if (data->method == NULL) return TCL_OK;
      memberPtr = Tcl_FindHashEntry(data->method, Tcl_GetString(name));
      if (memberPtr == NULL) return TCL_OK;
      method = Tcl_GetHashValue(memberPtr);
      Tcl_DecrRefCount(method->script);
      ckfree((char *) method);
      Tcl_DeleteHashEntry(memberPtr);
      /* Clean up the message handler, if no longer used */
      if (Tcl_CheckHashEmpty(data->method)) {
	 Tcl_DeleteHashTable(data->method);
	 ckfree((char *) data->method);
	 data->method = NULL;
	 if (data->signal == NULL && !(data->flags & DBUSFLAG_FALLBACK)) {
	    ckfree((char *) data);
	    if (*path != '\0')
	      dbus_connection_unregister_object_path(conn, path);
	    else
	      dbus->fallback = NULL;
	 }
      }
      return TCL_OK;
   }

   /* Register the new handler */
   data = DBus_GetMessageHandler(interp, conn, path);
   if (data->method == NULL) {
      /* No methods have been defined for this path by any interpreter yet
         So first a hash table indexed by interpreter must be created */
      data->method = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(data->method, TCL_STRING_KEYS);
   }
   memberPtr = Tcl_CreateHashEntry(data->method, Tcl_GetString(name), &isNew);
   if (isNew) {
      method = (Tcl_DBusMethodData *) ckalloc(sizeof(Tcl_DBusMethodData));
      method->interp = interp;
      method->conn = conn;
      Tcl_SetHashValue(memberPtr, method);
   } else {
      method = Tcl_GetHashValue(memberPtr);
      if(method->interp == interp) {
	 /* Release the old script */
	 Tcl_DecrRefCount(method->script);
      } else {
	 /* Method was registered by another interpreter */
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("method is in use by "
						   "another interpreter", -1));
	 return TCL_ERROR;
      }
   }
   /* Create a private copy of the handler to avoid problems */
   /* when used in a threaded environment */
   method->script = Tcl_DuplicateObj(handler);
   Tcl_IncrRefCount(method->script);
   method->flags = flags;
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusUnknownCmd
 *	Register a script to be called when a call for an unknown method
 *	is received.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusUnknownCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_DBusBus *dbus;
   Tcl_DBusHandlerData *data;
   Tcl_DBusMethodData *method;
   Tcl_HashEntry *memberPtr;
   DBusConnection *conn;
   int x = 1, isNew, flags, index;
   char c, *path = NULL;
   Tcl_Obj *busname = NULL, *handler = NULL, *result, *extra;
   static const char *options[] = {"-details", NULL};
   enum options {DBUS_DETAILS};

   if (objc > 1) {
      c = Tcl_GetString(objv[1])[0];
      /* Options start with '-', path starts with '/' or is "" */
      /* Anything else has to be a busId specification */
      if (c != '/' && c != '-' && c != '\0')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   /* Unknown handlers are always async */
   flags = DBUSFLAG_ASYNC;

   for (; x < objc; x++) {
      c = Tcl_GetString(objv[x])[0];
      if (c != '-') break;
      if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
			      &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      switch ((enum options) index) {
       case DBUS_DETAILS:
	 flags |= DBUSFLAG_DETAILS;
	 break;
      }
   }

   if (x < objc) {
      c = Tcl_GetString(objv[x])[0];
      if (c != '\0' && !DBus_CheckPath(objv[x])) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid path", -1));
	 return TCL_ERROR;
      }
      path = Tcl_GetString(objv[x++]);
   }
   if (x < objc) {
      handler = objv[x++];
   }

   if (x != objc) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? ?options? ?path ?script??");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (handler == NULL) {
      /* Request for a report on currently registered handler(s) */
      if (path == NULL) {
	 /* Get all handlers for any path */
	 result = DBus_ListListeners(interp, conn, "",
				     DBUS_METHODFLAG | DBUS_UNKNOWNFLAG);
	 /* append all currently registered handlers from the root path */
	 extra = DBus_ListListeners(interp, conn, "/",
			DBUS_METHODFLAG | DBUS_UNKNOWNFLAG | DBUS_RECURSEFLAG);
	 Tcl_ListObjAppendList(NULL, result, extra);
	 Tcl_DecrRefCount(extra);
	 Tcl_SetObjResult(interp, result);
	 return TCL_OK;
      }
      method = DBus_FindListeners(conn, path, "", TRUE);
      if (method != NULL && method->interp == interp) {
	 /* Return the script configured for the handler */
	 Tcl_IncrRefCount(method->script);
	 Tcl_SetObjResult(interp, method->script);
      }
      return TCL_OK;
   }

   if (Tcl_GetCharLength(handler) == 0) {
      /* Unregistering a handler */
      dbus = dbus_connection_get_data(conn, dataSlot);
      if (*path != '\0') {
	 if (!dbus_connection_get_object_path_data(conn, path,
						   (void **)&data))
	   return DBus_MemoryError(interp);
      }
      else {
	 data = dbus->fallback;
      }
      if (data == NULL) return TCL_OK;
      if (data->method == NULL) return TCL_OK;
      memberPtr = Tcl_FindHashEntry(data->method, "");
      if (memberPtr == NULL) return TCL_OK;
      method = Tcl_GetHashValue(memberPtr);
      Tcl_DecrRefCount(method->script);
      ckfree((char *) method);
      Tcl_DeleteHashEntry(memberPtr);
      /* Clean up the message handler, if no longer used */
      if (Tcl_CheckHashEmpty(data->method)) {
	 Tcl_DeleteHashTable(data->method);
	 ckfree((char *) data->method);
	 data->method = NULL;
	 if (data->signal == NULL && !(data->flags & DBUSFLAG_FALLBACK)) {
	    ckfree((char *) data);
	    if (*path != '\0')
	      dbus_connection_unregister_object_path(conn, path);
	    else
	      dbus->fallback = NULL;
	 }
      }
      return TCL_OK;
   }

   /* Register the new handler */
   data = DBus_GetMessageHandler(interp, conn, path);
   if (data->method == NULL) {
      /* No methods have been defined for this path by any interpreter yet
         So first a hash table indexed by interpreter must be created */
      data->method = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
      Tcl_InitHashTable(data->method, TCL_STRING_KEYS);
   }
   memberPtr = Tcl_CreateHashEntry(data->method, "", &isNew);
   if (isNew) {
      method = (Tcl_DBusMethodData *) ckalloc(sizeof(Tcl_DBusMethodData));
      method->interp = interp;
      method->conn = conn;
      Tcl_SetHashValue(memberPtr, method);
   } else {
      method = Tcl_GetHashValue(memberPtr);
      if(method->interp == interp) {
	 /* Release the old script */
	 Tcl_DecrRefCount(method->script);
      } else {
	 /* Method was registered by another interpreter */
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("unknown handler is defined "
						   "by another interpreter", -1));
	 return TCL_ERROR;
      }
   }
   /* Create a private copy of the handler to avoid problems */
   /* when used in a threaded environment */
   method->script = Tcl_DuplicateObj(handler);
   Tcl_IncrRefCount(method->script);
   method->flags = flags;
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 */

DBusHandlerResult DBus_Monitor(DBusConnection *conn,
	DBusMessage *msg, void *data)
{
   Tcl_DBusEvent *evPtr;
   Tcl_DBusMonitorData* dataPtr = data;

   if (dataPtr->script != NULL) {
      evPtr = (Tcl_DBusEvent *) ckalloc(sizeof(Tcl_DBusEvent));
      /* Storage at *evPtr will be freed by Tcl_ServiceEvent */
      evPtr->event.proc = DBus_EventHandler;
      evPtr->interp = dataPtr->interp;
      evPtr->script = Tcl_DuplicateObj(dataPtr->script);
      Tcl_IncrRefCount(evPtr->script);
      evPtr->conn = conn;
      evPtr->msg = msg;
      /* Never report the result of a snoop handler */
      evPtr->flags = dataPtr->flags | DBUSFLAG_NOREPLY;
      dbus_message_ref(msg);
      Tcl_QueueEvent((Tcl_Event *) evPtr, TCL_QUEUE_TAIL);
   }
   /* Allow messages to proceed to invoke methods and signal events */
   return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusMonitorCmd
 *	Register a script to be called whenever any D-Bus message is
 *	received.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

int DBusMonitorCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_DBusBus *dbus;
   Tcl_DBusMonitorData *snoop;
   Tcl_HashEntry *memberPtr;
   Tcl_Obj *busname = NULL, *handler;
   DBusConnection *conn;
   int x = 1, flags = 0, index;
   char c;
   static const char *options[] = {"-details", NULL};
   enum options {DBUS_DETAILS};

   if (objc > 2) {
      c = Tcl_GetString(objv[1])[0];
      /* If the arg doesn't start with '-', it must be a busId specification */
      if (c != '-')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   for (; x < objc - 1; x++) {
      c = Tcl_GetString(objv[x])[0];
      if (c != '-') break;
      if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
			      &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      switch ((enum options) index) {
       case DBUS_DETAILS:
	 flags |= DBUSFLAG_DETAILS;
	 break;
      }
   }

   if (objc != x + 1) {
      Tcl_WrongNumArgs(interp, 1, objv, "?busId? script");
      return TCL_ERROR;
   }
   handler = objv[x];

   if (conn == NULL)
     return TCL_ERROR;

   dbus = dbus_connection_get_data(conn, dataSlot);

   /* Find the snoop entry for the current interpreter */
   memberPtr = Tcl_FindHashEntry(dbus->snoop, (char *) interp);
   if (memberPtr == NULL) {
      Tcl_SetObjResult(interp,
		       Tcl_NewStringObj("DBus module not initialized", -1));
      return TCL_ERROR;
   }
   snoop = Tcl_GetHashValue(memberPtr);

   /* Unregistering the old handler */
   if (snoop != NULL) {
      dbus_connection_remove_filter(conn, DBus_Monitor, snoop);
      Tcl_DecrRefCount(snoop->script);
      ckfree((char *) snoop);
      Tcl_SetHashValue(memberPtr, NULL);
   }

   if (Tcl_GetCharLength(handler) > 0) {
      /* Register the new handler */
      snoop = (Tcl_DBusMonitorData *)ckalloc(sizeof(Tcl_DBusMonitorData));
      snoop->interp = interp;
      /* Create a private copy of the handler to avoid problems */
      /* when used in a threaded environment */
      snoop->script = Tcl_DuplicateObj(handler);
      Tcl_IncrRefCount(snoop->script);
      snoop->flags = flags;
      Tcl_SetHashValue(memberPtr, snoop);

      dbus_connection_add_filter(conn, DBus_Monitor, snoop, NULL);
   }
   return TCL_OK;
}
