/*
 * Signature parsing routines. These five functions build up the arguments
 * of a dbus message from Tcl objects based on a provided signature. Due to
 * the nested nature of signatures, these functions may recursively call
 * eachother.
 *
 * The main entry point is DBus_ArgList. It repeatedly calls DBus_Argument
 * to add arguments to the message. DBus_Argument in turn may call
 * DBus_ArgList again to add embedded structure arguments. For the basic
 * argument types DBus_Argument calls DBus_BasicArg. Array arguments are
 * handled by DBus_ArrayArg which repeatedly calls DBus_Argument again for
 * the array elements, unless it's an array of dict entries in which case
 * DBus_DictArg is called to process the complete dict. DBus_DictArg
 * repeatedly calls DBus_BasicArg for the key argument and DBus_Argument
 * for the value argument.
 */

#include "dbustcl.h"

static int DBus_Argument(Tcl_Interp *interp, DBusConnection *conn,
	DBusMessageIter *iter, DBusSignatureIter *sig,
	int argtype, Tcl_Obj *const arg);
static int DBus_DictArg(Tcl_Interp *interp, DBusConnection *conn,
	DBusMessageIter *iter, DBusSignatureIter *sig, Tcl_Obj *const arg);

/*
 *----------------------------------------------------------------------
 *
 * DBus_ArgList --
 *
 * 	Add a Tcl list as a structure argument to a DBus message
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointers in DBusMessageIter and DBusSignatureIter are advanced
 * 	passed the processed part of the signature. The len variable is
 * 	decremented by the number of Tcl_Objs handled. In case of an
 * 	error, the interp Result variable contains a problem description.
 *
 *----------------------------------------------------------------------
 */

int DBus_ArgList(Tcl_Interp *interp, DBusConnection *conn,
		 DBusMessageIter *iter, DBusSignatureIter *sig,
		 int* len, Tcl_Obj *const arg[])
{
   int c;

   while (*len > 0) {
      c = dbus_signature_iter_get_current_type(sig);
      if (DBus_Argument(interp, conn, iter, sig, c, *arg) != TCL_OK)
	return TCL_ERROR;
      ++arg; --*len;
      if (c == DBUS_TYPE_INVALID ||
	  (!dbus_signature_iter_next(sig) && *len > 0)) {
	 Tcl_AppendResult(interp, "Arguments left after exhausting "
			  "the type signature", NULL);
	 return TCL_ERROR;
      }
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_BasicArg --
 *
 * 	Add a Tcl_Obj as a basic argument to a DBus message
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointer of DBusMessageIter is advanced passed the added argument.
 * 	In case of error, the interp Result variable contains a problem
 * 	description.
 *
 *----------------------------------------------------------------------
 */

int DBus_BasicArg(Tcl_Interp *interp, DBusMessageIter *iter,
	int type, Tcl_Obj *const arg)
{
   DBus_Value value;
   int mode;
   Tcl_Channel chan;
   Tcl_DString ds;
   Tcl_Encoding encoding;
   int length;
   const char *str;

   switch (type) {
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_SIGNATURE:
      if (type == DBUS_TYPE_OBJECT_PATH && !DBus_CheckPath(arg)) {
	 Tcl_AppendResult(interp, "Invalid path", NULL);
	 return TCL_ERROR;
      }
      if (type == DBUS_TYPE_SIGNATURE && !DBus_CheckSignature(arg)) {
	 Tcl_AppendResult(interp, "Invalid signature", NULL);
	 return TCL_ERROR;
      }
      /* Fall through to DBUS_TYPE_STRING */
    case DBUS_TYPE_STRING:
      /*
       * Need to convert from internal representation to real utf-8 because
       * the dbus library will crash on Tcl's \0 character (0xc080). After
       * conversion, the string will end at the first \0 (dbus doesn't allow
       * \0 in strings).
       */
      str = Tcl_GetStringFromObj(arg, &length);
      /* The utf-8 encoding is guaranteed to exist, so no checks are needed */
      encoding = Tcl_GetEncoding(interp, "utf-8");
      Tcl_UtfToExternalDString(encoding, str, length, &ds);
      Tcl_FreeEncoding(encoding);
      value.str = Tcl_DStringValue(&ds);
      dbus_message_iter_append_basic(iter, type, &value.str);
      Tcl_DStringFree(&ds);
      break;
    case DBUS_TYPE_UINT64:
      if (Tcl_GetWideIntFromObj(interp, arg, &value.int64) != TCL_OK)
	return TCL_ERROR;
      value.uint64 = value.int64;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT64, &value.uint64);
      break;
    case DBUS_TYPE_INT64:
      if (Tcl_GetWideIntFromObj(interp, arg, &value.int64) != TCL_OK)
	return TCL_ERROR;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_INT64, &value.int64);
      break;
    case DBUS_TYPE_UINT32:
      if (Tcl_GetIntFromObj(interp, arg, &value.int32) != TCL_OK)
	return TCL_ERROR;
      value.uint32 = value.int32;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT32, &value.uint32);
      break;
    case DBUS_TYPE_INT32:
      if (Tcl_GetIntFromObj(interp, arg, &value.int32) != TCL_OK)
	return TCL_ERROR;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_INT32, &value.int32);
      break;
    case DBUS_TYPE_UINT16:
      if (Tcl_GetIntFromObj(interp, arg, &value.int32) != TCL_OK)
	return TCL_ERROR;
      value.uint16 = value.int32;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT16, &value.uint16);
      break;
    case DBUS_TYPE_INT16:
      if (Tcl_GetIntFromObj(interp, arg, &value.int32) != TCL_OK)
	return TCL_ERROR;
      value.int16 = value.int32;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_INT16, &value.int16);
      break;
    case DBUS_TYPE_BYTE:
      if (Tcl_GetIntFromObj(interp, arg, &value.int32) != TCL_OK)
	return TCL_ERROR;
      value.byte = value.int32;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_BYTE, &value.byte);
      break;
    case DBUS_TYPE_BOOLEAN:
      if (Tcl_GetBooleanFromObj(interp, arg, &value.int32) != TCL_OK) {
	 /* If not a proper boolean, try to parse the arg as an integer */
	 /* If that fails too, don't overwrite the error message */
	 if (Tcl_GetIntFromObj(NULL, arg, &value.int32) != TCL_OK)
	   return TCL_ERROR;
	 value.int32 = (value.int32 != 0);
	 /* Recovered from the error situation */
	 Tcl_ResetResult(interp);
      }
      dbus_message_iter_append_basic(iter, DBUS_TYPE_BOOLEAN, &value.int32);
      break;
    case DBUS_TYPE_DOUBLE:
      if (Tcl_GetDoubleFromObj(interp, arg, &value.real) != TCL_OK)
	return TCL_ERROR;
      dbus_message_iter_append_basic(iter, DBUS_TYPE_DOUBLE, &value.real);
      break;
    case DBUS_TYPE_UNIX_FD:
      value.str = Tcl_GetString(arg);
      chan = Tcl_GetChannel(interp, value.str, &mode);
      if (chan == NULL) return TCL_ERROR;
      value.fd = -1;
      if (mode & TCL_READABLE) {
	 Tcl_GetChannelHandle(chan, TCL_READABLE, &value.ptr);
	 value.fd = PTR2INT(value.ptr);
      }
      if (mode & TCL_WRITABLE) {
	 Tcl_GetChannelHandle(chan, TCL_WRITABLE, &value.ptr);
	 value.fd = PTR2INT(value.ptr);
      }
      dbus_message_iter_append_basic(iter, DBUS_TYPE_UNIX_FD, &value.fd);
      break;
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_ArrayArg --
 *
 * 	Add a Tcl list or dict as an array argument to a DBus message
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointers in DBusMessageIter and DBusSignatureIter are advanced
 * 	passed the processed part of the signature. In case of an error,
 * 	the interp Result variable contains a problem description.
 *
 *----------------------------------------------------------------------
 */

static int DBus_ArrayArg(Tcl_Interp *interp, DBusConnection *conn,
			 DBusMessageIter *iter, DBusSignatureIter *sig,
			 Tcl_Obj *const arg)
{
   int objc, c;
   Tcl_Obj **objv;
   DBusSignatureIter sigsub;

   c = dbus_signature_iter_get_current_type(sig);
   if (c != DBUS_TYPE_DICT_ENTRY) {
      if (Tcl_ListObjGetElements(interp, arg, &objc, &objv) != TCL_OK)
	return TCL_ERROR;
      while (objc > 0) {
	 if (DBus_Argument(interp, conn, iter, sig, c, *objv) != TCL_OK)
	   return TCL_ERROR;
	 ++objv; --objc;
      }
   } else {
      dbus_signature_iter_recurse(sig, &sigsub);
      if (DBus_DictArg(interp, conn, iter, &sigsub, arg))
	return TCL_ERROR;
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_DictArg --
 *
 * 	Add a dict as an array of dictentry arguments to a DBus message
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointers in DBusMessageIter and DBusSignatureIter are advanced
 * 	passed the processed part of the signature. In case of an error,
 * 	the interp Result variable contains a problem description.
 *
 *----------------------------------------------------------------------
 */

static int DBus_DictArg(Tcl_Interp *interp, DBusConnection *conn,
			DBusMessageIter *iter, DBusSignatureIter *sig,
			Tcl_Obj *const arg)
{
   int keytype, valtype, done;
   Tcl_Obj *key, *val;
   Tcl_DictSearch search;
   DBusMessageIter msgsub;

   keytype = dbus_signature_iter_get_current_type(sig);
   dbus_signature_iter_next(sig);
   valtype = dbus_signature_iter_get_current_type(sig);
   if (Tcl_DictObjFirst(interp, arg, &search, &key, &val, &done) != TCL_OK)
     return TCL_ERROR;
   for (; !done; Tcl_DictObjNext(&search, &key, &val, &done)) {
      dbus_message_iter_open_container(iter, DBUS_TYPE_DICT_ENTRY, NULL, &msgsub);
      if (DBus_BasicArg(interp, &msgsub, keytype, key) != TCL_OK) break;
      if (DBus_Argument(interp, conn, &msgsub, sig, valtype, val) != TCL_OK)
	break;
      dbus_message_iter_close_container(iter, &msgsub);
   }
   Tcl_DictObjDone(&search);
   if (!done) return TCL_ERROR;
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_VariantArg --
 *
 * 	Adds a variant argument to a DBus message by autodetecting the
 *	type of the provided variable
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointers in DBusMessageIter and DBusSignatureIter are advanced
 * 	passed the processed part of the signature. In case of an error,
 * 	the interp Result variable contains a problem description.
 *
 *----------------------------------------------------------------------
 */

static int DBus_VariantArg(Tcl_Interp *interp, DBusConnection *conn,
			   DBusMessageIter *iter, Tcl_Obj *const arg)
{
   int i = 0, num = DBUS_TYPE_STRING;
   char **str, *sign;
   const Tcl_ObjType *objtype;
   DBusMessageIter msgsub;
   DBusSignatureIter sigsub;
   static const char *objtypes[] = {
      "string", "int", "wideInt", "double", "boolean", "list", "dict", NULL
   };
   const int types[] = {
      DBUS_TYPE_STRING, DBUS_TYPE_INT32, DBUS_TYPE_INT64,
      DBUS_TYPE_DOUBLE, DBUS_TYPE_BOOLEAN,
      DBUS_TYPE_STRING, DBUS_TYPE_STRING
   };

   objtype = arg->typePtr;
   if (objtype != NULL) {
      for (i = 0, str = (char **)objtypes; *str != NULL; i++, str++) {
	 if (strcmp(*str, objtype->name) == 0) break;
      }
      num = (*str == NULL ? DBUS_TYPE_STRING : types[i]);
   }
   switch (i) {
    case 5: /* list */
      sign = "as";
    case 6: /* dict */
      if (i == 6) sign = "a{ss}";
      dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT,
					   sign, &msgsub);
      dbus_signature_iter_init(&sigsub, sign);
      num = 1;
      if (DBus_ArgList(interp, conn, &msgsub, &sigsub, &num, &arg) != TCL_OK)
	return TCL_ERROR;
      dbus_message_iter_close_container(iter, &msgsub);
      break;
    default:
      dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT,
					   (char *)&num, &msgsub);
      if (DBus_BasicArg(interp, &msgsub, num, arg) != TCL_OK)
	return TCL_ERROR;
      dbus_message_iter_close_container(iter, &msgsub);
      break;
   }
   return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DBus_Argument --
 *
 * 	Add a Tcl_Obj as the appropriate argument to a DBus message
 *
 * Results:
 * 	TCL_ERROR if errors were encountered, TCL_OK otherwise.
 *
 * Side effects:
 * 	Pointers in DBusMessageIter and DBusSignatureIter are advanced
 * 	passed the processed part of the signature. In case of an error,
 * 	the interp Result variable contains a problem description.
 *
 *----------------------------------------------------------------------
 */

static int DBus_Argument(Tcl_Interp *interp, DBusConnection *conn,
			 DBusMessageIter *iter, DBusSignatureIter *sig,
			 int argtype, Tcl_Obj *const arg)
{
   DBusMessageIter msgsub;
   DBusSignatureIter sigsub;
   int objc, len, num, rc = TCL_OK;
   Tcl_Obj **objv, *tmp, *str;
   const Tcl_ObjType *objtype;
   char *sign, type[2] = {'\0', '\0'};

   switch (argtype) {
    case DBUS_TYPE_UNIX_FD:
      if (!dbus_connection_can_send_type(conn, DBUS_TYPE_UNIX_FD)) {
	 Tcl_AppendResult(interp, "DBus connection doesn't support "
			  "file descriptor passing", NULL);
	 return TCL_ERROR;
      }
      /* Fall through */
    case DBUS_TYPE_STRING:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_UINT64:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_DOUBLE:
      if (DBus_BasicArg(interp, iter, argtype, arg) != TCL_OK)
	return TCL_ERROR;
      break;
    case DBUS_TYPE_STRUCT:
      if (Tcl_ListObjGetElements(interp, arg, &objc, &objv) != TCL_OK)
	return TCL_ERROR;
      dbus_signature_iter_recurse(sig, &sigsub);
      dbus_message_iter_open_container(iter, DBUS_TYPE_STRUCT, NULL, &msgsub);
      if (DBus_ArgList(interp, conn, &msgsub, &sigsub, &objc, objv) != TCL_OK)
	rc = TCL_ERROR;
      else if (dbus_signature_iter_get_current_type(&sigsub) != DBUS_STRUCT_END_CHAR) {
	 sign = dbus_signature_iter_get_signature(sig);
	 Tcl_AppendResult(interp, "Not enough elements in list ",
		"representing structure: \"", sign, "\"", NULL);
	 dbus_free(sign);
	 rc = TCL_ERROR;
      }
      if (rc == TCL_OK)
	dbus_message_iter_close_container(iter, &msgsub);
      break;
    case DBUS_TYPE_ARRAY:
      dbus_signature_iter_recurse(sig, &sigsub);
      sign = dbus_signature_iter_get_signature(&sigsub);
      dbus_message_iter_open_container(iter, DBUS_TYPE_ARRAY, sign, &msgsub);
      dbus_free(sign);
      rc = DBus_ArrayArg(interp, conn, &msgsub, &sigsub, arg);
      if (rc == TCL_OK)
	dbus_message_iter_close_container(iter, &msgsub);
      break;
    case DBUS_TYPE_VARIANT:
      objtype = arg->typePtr;
      if (objtype == NULL)
	/* Make a copy so the internal rep of the original won't be changed */
	tmp = Tcl_DuplicateObj(arg);
      else
	tmp = arg;
      Tcl_IncrRefCount(tmp);
      if ((objtype == NULL || strcmp("list", objtype->name) == 0) &&
	  Tcl_ListObjLength(NULL, tmp, &len) == TCL_OK && len == 2 &&
	  Tcl_ListObjIndex(NULL, tmp, 0, &str) == TCL_OK &&
	  dbus_signature_validate_single(Tcl_GetString(str), NULL)) {
	 /* Argument is a 2-element list and the first element is a */
	 /* valid signature containing exactly one complete type */
	 sign = Tcl_GetString(str);
	 dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT,
					      sign, &msgsub);
	 dbus_signature_iter_init(&sigsub, sign);
	 Tcl_ListObjIndex(NULL, tmp, 1, &str);
	 num = 1;
	 rc = DBus_ArgList(interp, conn, &msgsub, &sigsub, &num, &str);
	 if (rc == TCL_OK)
	   dbus_message_iter_close_container(iter, &msgsub);
      } else {
	 rc = DBus_VariantArg(interp, conn, iter, arg);
      }
      Tcl_DecrRefCount(tmp);
      break;
    case DBUS_TYPE_INVALID:
      /* Will catch the error later */
      break;
    default:
      type[0] = dbus_signature_iter_get_current_type(sig);
      sign = dbus_signature_iter_get_signature(sig);
      Tcl_AppendResult(interp, "Unsupported argument type: \"", type,
		       "/", sign, "\"", NULL);
      dbus_free(sign);
      return TCL_ERROR;
   }
   return rc;
}
