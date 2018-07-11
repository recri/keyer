#include "dbustcl.h"

/*
 *----------------------------------------------------------------------
 *
 * DBus_MessageInfo --
 *
 * 	Creates a dict with interesting information about a dbus message.
 *
 * Results:
 * 	Returns a dict.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *DBus_MessageInfo(Tcl_Interp *interp, DBusMessage *msg)
{
   Tcl_Obj *info;
   int type;

   info = Tcl_NewDictObj();
   /* Get the interface member being invoked or emitted */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("member", -1),
		  Tcl_NewStringObj(dbus_message_get_member(msg), -1));
   /* Get the interface the message is being sent to or emitted from */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("interface", -1),
		  Tcl_NewStringObj(dbus_message_get_interface(msg), -1));
   /* Get the object path the message is being sent to or emitted from */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("path", -1),
		    Tcl_NewStringObj(dbus_message_get_path(msg), -1));
   /* Get the unique name of the connection which originated the message */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("sender", -1),
		  Tcl_NewStringObj(dbus_message_get_sender(msg), -1));
   /* Get the destination of the message */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("destination", -1),
		  Tcl_NewStringObj(dbus_message_get_destination(msg), -1));
   /* Get the message type (signal, method_call, method_reply, or error */
   type = dbus_message_get_type(msg);
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("messagetype", -1),
		  Tcl_NewStringObj(dbus_message_type_to_string(type), -1));
   /* Get the signature specifying the type of the arguments in the payload */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("signature", -1),
		  Tcl_NewStringObj(dbus_message_get_signature(msg), -1));
   /* Get the serial of a message or 0 if none has been specified */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("serial", -1),
		  Tcl_NewIntObj(dbus_message_get_serial(msg)));
   /* Get the serial that the message is a reply to or 0 if none */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("replyserial", -1),
		  Tcl_NewIntObj(dbus_message_get_reply_serial(msg)));
   /* Get the no-reply setting, 1 if the message does not expect a reply */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("noreply", -1),
		  Tcl_NewIntObj(dbus_message_get_no_reply(msg)));
   /* Get the auto-start setting, 1 if true, 0 if false */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("autostart", -1),
		  Tcl_NewIntObj(dbus_message_get_auto_start(msg)));
   /* Get the error_name, only relevant for error messages */
   Tcl_DictObjPut(interp, info, Tcl_NewStringObj("errorname", -1),
		  Tcl_NewStringObj(dbus_message_get_error_name(msg), -1));
   return info;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_IterList --
 *
 *	Converts a dbus return value or message parameters into a (nested)
 *	Tcl list.
 *
 * Returns:
 *	A list representing the dbus message parameters or return value.
 *
 * Side effects:
 * 	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *DBus_IterList(Tcl_Interp *interp, DBusMessageIter *iter, int details)
{
   DBusMessageIter sub;
   Tcl_Obj *list, *str, *variant, *sublist;
   DBus_Value value;
   Tcl_Channel chan;

   list = Tcl_NewObj();
   do
     switch (dbus_message_iter_get_arg_type(iter)) {
      case DBUS_TYPE_STRING:
      case DBUS_TYPE_OBJECT_PATH:
      case DBUS_TYPE_SIGNATURE:
	dbus_message_iter_get_basic(iter, &value.str);
	str = Tcl_NewStringObj(value.str, -1);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_INT64:
	dbus_message_iter_get_basic(iter, &value.int64);
	str = Tcl_NewWideIntObj(value.int64);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_UINT64:
	dbus_message_iter_get_basic(iter, &value.uint64);
	if (value.uint64 & DBUS_UINT64_MASK)
	  /* The value cannot be represented in a wideint object. To avoid */
	  /* having to link against tommath, just put the value in string */
	  str = Tcl_ObjPrintf(DBUS_UINT64_FORMAT, value.uint64);
	else
	  str = Tcl_NewWideIntObj(value.uint64);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_BOOLEAN:
      case DBUS_TYPE_INT32:
	dbus_message_iter_get_basic(iter, &value.int32);
	str = Tcl_NewIntObj(value.int32);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_UINT32:
	dbus_message_iter_get_basic(iter, &value.uint32);
	str = Tcl_NewWideIntObj(value.uint32);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_INT16:
	dbus_message_iter_get_basic(iter, &value.int16);
	str = Tcl_NewIntObj(value.int16);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_UINT16:
	dbus_message_iter_get_basic(iter, &value.uint16);
	str = Tcl_NewIntObj(value.uint16);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_BYTE:
	dbus_message_iter_get_basic(iter, &value.byte);
	str = Tcl_NewIntObj(value.byte);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_DOUBLE:
	dbus_message_iter_get_basic(iter, &value.real);
	str = Tcl_NewDoubleObj(value.real);
	Tcl_ListObjAppendElement(interp, list, str);
	break;

      case DBUS_TYPE_ARRAY:
	/* This may be done more efficiently using something like:
	dbus_message_iter_recurse(iter, &sub);
	if (dbus_type_is_fixed(&sub)) {
	   dbus_message_iter_get_element_type(&sub);
	   dbus_message_iter_get_fixed_array(&sub, &array, 32);
	} */
	dbus_message_iter_recurse(iter, &sub);
	Tcl_ListObjAppendElement(interp, list,
				 DBus_IterList(interp, &sub, details));
	break;

      case DBUS_TYPE_VARIANT:
	dbus_message_iter_recurse(iter, &sub);
	if (details) {
	   variant = Tcl_NewObj();
	   Tcl_ListObjAppendElement(interp, variant,
		Tcl_NewStringObj(dbus_message_iter_get_signature(&sub), -1));
	   sublist = DBus_IterList(interp, &sub, details);
	   Tcl_ListObjAppendList(interp, variant, sublist);
	   Tcl_DecrRefCount(sublist);
	   Tcl_ListObjAppendElement(interp, list, variant);
	} else {
	   sublist = DBus_IterList(interp, &sub, details);
	   Tcl_ListObjAppendList(interp, list, sublist);
	   Tcl_DecrRefCount(sublist);
	}
	break;

      case DBUS_TYPE_STRUCT:
	dbus_message_iter_recurse(iter, &sub);
	Tcl_ListObjAppendElement(interp, list,
				 DBus_IterList(interp, &sub, details));
	break;

      case DBUS_TYPE_DICT_ENTRY:
	dbus_message_iter_recurse(iter, &sub);
	sublist = DBus_IterList(interp, &sub, details);
	Tcl_ListObjAppendList(interp, list, sublist);
	Tcl_DecrRefCount(sublist);
	break;

      case DBUS_TYPE_UNIX_FD:
	dbus_message_iter_get_basic(iter, &value.fd);
	chan = Tcl_MakeFileChannel(INT2PTR(value.fd), TCL_READABLE|TCL_WRITABLE);
	if (chan != NULL) {
	   Tcl_RegisterChannel(interp, chan);
	   str = Tcl_NewStringObj(Tcl_GetChannelName(chan), -1);
	} else {
	   str = Tcl_NewStringObj("NULL", 4);
	}
	Tcl_ListObjAppendElement(interp, list, str);
	break;

     }
   while (dbus_message_iter_next(iter));
   return list;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_AppendArgs
 *      Append arguments according to the specified signature or as strings
 *      if signature is NULL.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *      Interpreter value is set to error text in case of error occured
 *
 *----------------------------------------------------------------------
 */

int DBus_AppendArgs (Tcl_Interp *interp, DBusConnection *conn,
        DBusMessage *msg, const char *signature, int objc,
        Tcl_Obj *const objv[])
{
   int x = 0;
   DBusMessageIter iter;
   DBusSignatureIter sig;

   dbus_message_iter_init_append(msg, &iter);
   if (signature == NULL) {
      if (objc == 0)
	return TCL_OK;
      /* No signature has been specified. Add all arguments as strings */
      for (; x < objc; x++) {
	 if (DBus_BasicArg(interp, &iter, DBUS_TYPE_STRING, objv[x]) != TCL_OK)
	   return TCL_ERROR;
      }
   } else {
      /* Add the arguments as the type specified by the signature */
      dbus_signature_iter_init(&sig, signature);
      if (DBus_ArgList(interp, conn, &iter, &sig, &objc, objv) != TCL_OK) {
	 return TCL_ERROR;
      }
      if (objc != 0 ||
	  dbus_signature_iter_get_current_type(&sig) != DBUS_TYPE_INVALID) {
	 Tcl_SetObjResult(interp, Tcl_NewStringObj("Argument list does "
						   "not match signature", -1));
	 return TCL_ERROR;
      }
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_SendMessage
 *	Send message with specified type, interface, name, replySerial and
 *      signature to destination.
 *
 *      This is a wrapper for dbus_message_new(), dbus_message_set_*()
 *      and dbus_connection_send() methods from dbus.h.
 *
 * Arguments:
 *      interp      Tcl interpreter instance
 *      conn        D-Bus connection
 *      type        Type of message (can be DBUS_MESSAGE_TYPE_METHOD_RETURN,
 *                  DBUS_MESSAGE_TYPE_ERROR, DBUS_MESSAGE_TYPE_SIGNAL)
 *      path        Object path this message is being sent to (for
 *                  DBUS_MESSAGE_TYPE_METHOD_CALL) or the one a signal
 *                  is being emitted from (for DBUS_MESSAGE_TYPE_SIGNAL)
 *      intf        Interface of an signal (must be NULL for other types)
 *      name        Name of a signal or error_name for error messages
 *		    (ignored for other types)
 *      destination Message destination (must be NULL for signals)
 *      replySerial Reply serial ID (ignored for signals)
 *      signature   D-Bus type signature (if empty, all arguments passed
 *                  as strings)
 *      objc        Count of Tcl objects in objv array
 *      objv        Array of message parameters
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *      Interpreter value is set to error text in case an error occured
 *
 *----------------------------------------------------------------------
 */

int DBus_SendMessage(Tcl_Interp *interp, DBusConnection *conn,
        int type, const char *path, const char *intf,
        const char *name, const char *destination,
        dbus_uint32_t replySerial, const char *signature,
        int objc, Tcl_Obj *const objv[])
{
   DBusMessage *msg;
   dbus_uint32_t serial;

   /* Check if the connection is still present */
   if (!dbus_connection_get_is_connected(conn)) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(
				"D-Bus connection is closed", -1));
      return TCL_ERROR;
   }

   /* create a new message & check for errors */
   msg = dbus_message_new(type);
   if (msg == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"Unable to create D-Bus message", -1));
      return TCL_ERROR;
   }
   dbus_message_set_no_reply(msg, TRUE);

   if ((type == DBUS_MESSAGE_TYPE_ERROR) && (name == NULL))
     name = DBUS_ERROR_FAILED;

   /* set message parameters */
   if (!dbus_message_set_path(msg, path) ||
       !dbus_message_set_interface(msg, intf) ||
       !(type != DBUS_MESSAGE_TYPE_SIGNAL ||
	 dbus_message_set_member(msg, name)) ||
       !(type != DBUS_MESSAGE_TYPE_ERROR ||
	 dbus_message_set_error_name(msg, name)) ||
       !dbus_message_set_destination(msg, destination) ||
       !(type == DBUS_MESSAGE_TYPE_SIGNAL ||
	 dbus_message_set_reply_serial(msg, replySerial))) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(
                    "Unable to set message parameters", -1));
      dbus_message_unref(msg);
      return TCL_ERROR;
   }

   /* append message arguments */
   if ((DBus_AppendArgs(interp, conn, msg, signature, objc, objv)) != TCL_OK) {
      dbus_message_unref(msg);
      return TCL_ERROR;
   }

   /* send the message and flush the connection */
   if (!dbus_connection_send(conn, msg, &serial)) {
      dbus_message_unref(msg);
      return DBus_MemoryError(interp);
   }
#ifdef _WIN32
   dbus_connection_flush(conn);
#endif
   dbus_message_unref(msg);
   Tcl_SetObjResult(interp, Tcl_NewIntObj(serial));
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_Error
 *	Send a error message onto the dbus.
 *
 * Arguments:
 *      interp      Tcl interpreter instance
 *      conn        D-Bus connection
 *	name	    Error name (default: org.freedesktop.DBus.Error.Failed)
 *      destination Message destination (must be NULL for signals)
 *      replySerial Reply serial ID (ignored for signals)
 *      message     Error message
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *      Interpreter value is set to error text in case of error occured
 *
 *----------------------------------------------------------------------
 */

int DBus_Error (Tcl_Interp *interp, DBusConnection *conn,
        const char *name, const char *destination,
	dbus_uint32_t replySerial, const char *message)
{
   int objc = 0;
   int res;
   Tcl_Obj **objv = NULL;
   Tcl_Obj *msg = NULL;

   if (message != NULL) {
      objc = 1;
      msg = Tcl_NewStringObj(message, -1);
      Tcl_IncrRefCount(msg);
      objv = &msg;
   }
   res = DBus_SendMessage(interp, conn, DBUS_MESSAGE_TYPE_ERROR,
			  NULL, NULL, name, destination, replySerial,
			  NULL, objc, objv);
   if (message != NULL) {
      Tcl_DecrRefCount(msg);
   }
   return res;
}

/*
 *----------------------------------------------------------------------
 *
 * DBusCallCmd
 *	This procedure is invoked to process the "dbus call" Tcl command.
 *	It sends a method call onto the dbus and optionally waits for a
 *	reply.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 * 	The result value of the interpreter is set depending on the
 *	specified options.
 *
 *----------------------------------------------------------------------
 */

int DBusCallCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   DBusMessage *msg;
   DBusMessageIter iter;
   DBusPendingCall *pending;
   DBusConnection *conn;
   DBusError err;
   Tcl_Obj *busname = NULL, *tmp, *result, *handler = NULL;
   Tcl_CallData *dataPtr;
   int index, timeout = -1, x = 1, autostart = 1, details = 0;
   int elemCount;
   char *str, *signature = NULL, *dest = NULL;
   dbus_uint32_t serial;
   static const char *options[] = {
      "-autostart", "-dest", "-details", "-handler",
      "-signature", "-timeout", "--", NULL
   };
   enum options {
      DBUS_START, DBUS_DEST, DBUS_DETAILS, DBUS_HANDLER, DBUS_SIGNATURE,
      DBUS_TIMEOUT, DBUS_LAST
   };

   if (objc < 4) {
      Tcl_WrongNumArgs(interp, 1, objv,
		       "?busId? ?options? path interface method ?arg ...?");
      return TCL_ERROR;
   }
   if (objc > 4) {
      str = Tcl_GetString(objv[1]);
      /* Options start with '-', path starts with '/' */
      /* Anything else has to be a busId specification */
      if (*str != '-' && *str != '/')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   for (; x < objc - 3; x++) {
      str = Tcl_GetString(objv[x]);
      if (*str != '-') break;
      if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
			      &index) != TCL_OK) {
	 return TCL_ERROR;
      }
      /* Assume all options have a value. If that assumption */
      /* turns out to be false, that will be corrected later */
      x++;
      if ((enum options) index == DBUS_LAST) break;
      switch ((enum options) index) {
       case DBUS_START:
	  str = Tcl_GetString(objv[x]);
	  /* Allow the option to be specified with- or without a value */
	  /* A following option starts with '-', path starts with '/' */
	  /* Anything else means a value for the option was specified */
	  if (*str == '-' || *str == '/') {
	    autostart = TRUE;
	    x--;
	  } else {
	      if (Tcl_GetBooleanFromObj(interp, objv[x], &autostart) != TCL_OK)
		return TCL_ERROR;
	  }
	 break;
       case DBUS_DEST:
	 if (!DBus_CheckBusName(objv[x])) {
	    Tcl_AppendResult(interp, "Invalid destination", NULL);
	    return TCL_ERROR;
	 }
	 dest = Tcl_GetString(objv[x]);
	 break;
       case DBUS_DETAILS:
	  str = Tcl_GetString(objv[x]);
	  /* Allow the option to be specified with- or without a value */
	  /* A following option starts with '-', path starts with '/' */
	  /* Anything else means a value for the option was specified */
	  if (*str == '-' || *str == '/') {
	    details = TRUE;
	    x--;
	  } else {
	      if (Tcl_GetBooleanFromObj(interp, objv[x], &details) != TCL_OK)
		return TCL_ERROR;
	  }
	  break;
       case DBUS_HANDLER:
	 /* Allow specifying an empty string to mean: no handler */
	 if (Tcl_GetCharLength(objv[x]) > 0) handler = objv[x];
	 break;
       case DBUS_SIGNATURE:
	 signature = Tcl_GetString(objv[x]);
	 /* Check that the signature is valid */
	 if (!dbus_signature_validate(signature, NULL)) {
	    Tcl_AppendResult(interp, "Invalid type signature", NULL);
	    return TCL_ERROR;
	 }
	 break;
       case DBUS_TIMEOUT:
	 if (Tcl_GetIntFromObj(interp, objv[x], &timeout) != TCL_OK)
	   return TCL_ERROR;
	 if (timeout < 0) timeout = -2;
	 break;
       case DBUS_LAST:
	 /* Silence compiler warning. This can never happen */
	 break;
      }
   }

   if (x > objc - 3) {
      Tcl_WrongNumArgs(interp, 1, objv,
		       "?option value ...? path interface method ?arg ...?");
      return TCL_ERROR;
   }
   if (!DBus_CheckPath(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid path", -1));
      return TCL_ERROR;
   }
   if (!DBus_CheckIntfName(objv[x+1])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid interface name", -1));
      return TCL_ERROR;
   }
   if (!DBus_CheckMember(objv[x+2])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid method", -1));
      return TCL_ERROR;
   }
   if (conn == NULL)
      return TCL_ERROR;
   if (!dbus_connection_get_is_connected(conn)) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(
				"D-Bus connection is closed", -1));
      return TCL_ERROR;
   }

   msg = dbus_message_new_method_call(dest, Tcl_GetString(objv[x]),
				      Tcl_GetString(objv[x+1]),
				      Tcl_GetString(objv[x+2]));
   x += 3;
   dbus_message_set_auto_start(msg, autostart);

   if ((DBus_AppendArgs(interp, conn,
		msg, signature, objc - x, objv + x)) != TCL_OK) {
      dbus_message_unref(msg);
      return TCL_ERROR;
   }

   /* initialise the dbus error structure */
   dbus_error_init(&err);

   if (timeout < -1) {
      /* Indicate we are not interested in a reply */
      dbus_message_set_no_reply(msg, TRUE);
      /* send the message and flush the connection */
      if (!dbus_connection_send(conn, msg, &serial))
	return DBus_MemoryError(interp);
#ifdef _WIN32
      dbus_connection_flush(conn);
#endif
      dbus_message_unref(msg);
      Tcl_SetObjResult(interp, Tcl_NewIntObj(serial));
      return TCL_OK;
   }
   /* send message and get a handle for a reply */
   if (!dbus_connection_send_with_reply(conn, msg, &pending, timeout)) {
      dbus_message_unref(msg);
      return DBus_MemoryError(interp);
   }
   if (pending == NULL) {
      dbus_message_unref(msg);
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Disconnected", -1));
      return TCL_ERROR;
   }
   dbus_connection_flush(conn);

   if (handler != NULL) {
      dataPtr = (Tcl_CallData *) ckalloc(sizeof(Tcl_CallData));
      dataPtr->interp = interp;
      dataPtr->conn = conn;
      dataPtr->flags = details ? DBUSFLAG_DETAILS : 0;
      if (!dbus_pending_call_set_notify(pending, DBus_CallResult,
					dataPtr, NULL))
	 return DBus_MemoryError(interp);
      /* Create a private copy of the handler to avoid problems in a */
      /* threaded environment */
      dataPtr->script = Tcl_DuplicateObj(handler);
      Tcl_IncrRefCount(dataPtr->script);
      Tcl_SetObjResult(interp, Tcl_NewIntObj(dbus_message_get_serial(msg)));
      /* free message */
      dbus_message_unref(msg);
      return TCL_OK;
   }

   /* free message */
   dbus_message_unref(msg);
   /* block until we recieve a reply */
   dbus_pending_call_block(pending);
   /* get the reply message */
   msg = dbus_pending_call_steal_reply(pending);
   if (msg == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("No reply", -1));
      return TCL_ERROR;
   }
   /* free the pending message handle */
   dbus_pending_call_unref(pending);
   /* read the parameters */
   if (!dbus_message_iter_init(msg, &iter)) {
      /* Message has no arguments */
      dbus_message_unref(msg);
      return TCL_OK;
   }

   result = DBus_IterList(interp, &iter, details);
   /* result is always list */
   Tcl_ListObjLength(NULL, result, &elemCount);
   if (elemCount == 1) {
      /* If result contains only one element, then only this element
       * will be returned */
      Tcl_ListObjIndex(NULL, result, 0, &tmp);
      /* Duplicate list item and release the list */
      tmp = Tcl_DuplicateObj(tmp);
      Tcl_DecrRefCount(result);
      result = tmp;
   }

   Tcl_SetObjResult(interp, result);
   if (dbus_message_get_type(msg) == DBUS_MESSAGE_TYPE_ERROR) {
      Tcl_SetErrorCode(interp, "DBUS", "DBUS_MESSAGE_TYPE_ERROR",
		       dbus_message_get_error_name(msg), NULL);
      /* free reply */
      dbus_message_unref(msg);
      return TCL_ERROR;
   } else {
      /* free reply */
      dbus_message_unref(msg);
      return TCL_OK;
   }
}

/*
 *----------------------------------------------------------------------
 *
 * DBusSignalCmd
 *	Send a signal onto the dbus.
 *
 * Arguments:
 *      busId(optional)     Bus handle
 *      signature(optional) Types of of arguments to be sent on the bus.
 *                          If not set, all arguments will be passed as
 *                          strings.
 *      object              Object path
 *      intf                Interface
 *      name                Signal name
 *      arg ...             Optional signal arguments
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	The result value of the interpreter is set to the serial number of
 *	the dbus message. If an error occurs the result value contains the
 *	error message.
 *
 *----------------------------------------------------------------------
 */

int DBusSignalCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_Obj *busname = NULL;
   DBusConnection *conn;
   int index, x = 1;
   char *signature = NULL;
   char *str, *object, *intf, *name;
   static const char *options[] = {
      "-signature", NULL
   };
   enum options {
      DBUS_SIGNATURE
   };

   if (objc > 4) {
      str = Tcl_GetString(objv[x]);
      /* Options start with '-', path starts with '/' */
      /* Anything else has to be a busId specification */
      if (*str != '-' && *str != '/')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);
   if (x < objc - 4) {
      str = Tcl_GetString(objv[x]);
      if (*str == '-') {
	 if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
				 &index) != TCL_OK) {
	    return TCL_ERROR;
	 }
	 x++;
	 if ((enum options) index == DBUS_SIGNATURE) {
	    signature = Tcl_GetString(objv[x]);
	    /* Check that the signature is valid */
	    if (!dbus_signature_validate(signature, NULL)) {
	       Tcl_AppendResult(interp, "Invalid type signature", NULL);
	       return TCL_ERROR;
	    }
	    x++;
	 }
      }
   }

   if (objc < x + 3) {
      Tcl_WrongNumArgs(interp, 1, objv,
          "?busId? ?-signature string? path interface name ?arg ...?");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (!DBus_CheckPath(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid path", -1));
      return TCL_ERROR;
   }
   object = Tcl_GetString(objv[x++]);
   if (!DBus_CheckBusName(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid bus name", -1));
      return TCL_ERROR;
   }
   intf = Tcl_GetString(objv[x++]);
   if (!DBus_CheckMember(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid member", -1));
      return TCL_ERROR;
   }
   name = Tcl_GetString(objv[x++]);
   return DBus_SendMessage(interp, conn, DBUS_MESSAGE_TYPE_SIGNAL,
	   object, intf, name, NULL, 0, signature, objc-x, objv+x);
}

/*
 *----------------------------------------------------------------------
 *
 * DBusMethodReturnCmd
 *	Send a method return message onto the dbus.
 *
 * Arguments:
 *      busId(optional)     Bus handle
 *      signature(optional) Types of of arguments to be sent on the bus.
 *                          If not set, all arguments will be passed as
 *                          strings.
 *      dest                Destination of a method caller
 *      serial              Method call message serial
 *      arg ...             Method call results
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *      Interpreter value is set to error text in case of error occured
 *
 *----------------------------------------------------------------------
 */

int DBusMethodReturnCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_Obj *busname = NULL;
   DBusConnection *conn;
   int replySerial, index, x = 1;
   char *str, *destination, *signature = NULL;
   static const char *options[] = {
      "-signature", NULL
   };
   enum options {
      DBUS_SIGNATURE
   };

   if (objc > 3) {
      str = Tcl_GetString(objv[x]);
      /* Options start with '-', dest starts with ':' */
      /* Anything else has to be a busId specification */
      if (*str != '-' && *str != ':')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);
   if (x < objc - 2) {
      str = Tcl_GetString(objv[x]);
      if (*str == '-') {
	 if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
				 &index) != TCL_OK) {
	    return TCL_ERROR;
	 }
	 x++;
	 if ((enum options) index == DBUS_SIGNATURE) {
	    signature = Tcl_GetString(objv[x]);
	    /* Check that the signature is valid */
	    if (!dbus_signature_validate(signature, NULL)) {
	       Tcl_AppendResult(interp, "Invalid type signature", NULL);
	       return TCL_ERROR;
	    }
	    x++;
	 }
      }
   }
   if (objc < x + 2) {
      Tcl_WrongNumArgs(interp, 1, objv,
          "?busId? ?-signature string? destination serial ?arg ...?");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (Tcl_GetIntFromObj(interp, objv[x+1], &replySerial) != TCL_OK) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid serial", -1));
      return TCL_ERROR;
   }
   if (!DBus_CheckBusName(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid destination", -1));
      return TCL_ERROR;
   }
   destination = Tcl_GetString(objv[x]);
   x += 2;

   return DBus_SendMessage(interp, conn, DBUS_MESSAGE_TYPE_METHOD_RETURN,
           NULL, NULL, NULL, destination, replySerial, signature,
           objc-x, objv+x);
}

/*
 *----------------------------------------------------------------------
 *
 * DBusErrorCmd
 *	Send a error message onto the dbus.
 *
 * Arguments:
 *      busId(optional)     Bus handle
 *      dest                Destination of a method caller
 *      serial              Method call message serial
 *      message             Error message (optional)
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *      Interpreter value is set to error text in case of error occured
 *
 *----------------------------------------------------------------------
 */

int DBusErrorCmd(ClientData dummy, Tcl_Interp *interp,
	int objc, Tcl_Obj *const objv[])
{
   Tcl_Obj *busname = NULL;
   DBusConnection *conn;
   int index, x = 1;
   int replySerial;
   char *str, *destination, *errorMessage = NULL, *errorName = NULL;
   static const char *options[] = {
      "-name", NULL
   };
   enum options {
      DBUS_ERRORNAME
   };

   if (objc > 3) {
      str = Tcl_GetString(objv[x]);
      /* Options start with '-', dest starts with ':' */
      /* Anything else has to be a busId specification */
      if (*str != '-' && *str != ':')
	 busname = objv[x++];
   }
   conn = DBus_GetConnection(interp, busname);

   if (x < objc - 2) {
      str = Tcl_GetString(objv[x]);
      if (*str == '-') {
	 if (Tcl_GetIndexFromObj(interp, objv[x], options, "option", 0,
				 &index) != TCL_OK) {
	    return TCL_ERROR;
	 }
	 x++;
	 if ((enum options) index == DBUS_ERRORNAME) {
	    if (!DBus_CheckBusName(objv[x])) {
	       Tcl_SetObjResult(interp,
				Tcl_NewStringObj("Invalid error name", -1));
	       return TCL_ERROR;
	    }
	    errorName = Tcl_GetString(objv[x]);
	    x++;
	 }
      }
   }

   if (objc < x + 2 || objc > x + 3) {
      Tcl_WrongNumArgs(interp, 1, objv,
		"?busId? ?-name string? destination serial ?message?");
      return TCL_ERROR;
   }

   if (conn == NULL)
      return TCL_ERROR;

   if (!DBus_CheckBusName(objv[x])) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid destination", -1));
      return TCL_ERROR;
   }
   destination = Tcl_GetString(objv[x]);
   if (Tcl_GetIntFromObj(interp, objv[x+1], &replySerial) != TCL_OK) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("Invalid serial", -1));
      return TCL_ERROR;
   }
   x += 2;
   if (objc > x) {
      errorMessage = Tcl_GetString(objv[x]);
   }

   return DBus_Error(interp, conn, errorName,
		     destination, replySerial, errorMessage);
}
