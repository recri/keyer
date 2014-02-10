#include "dbustcl.h"

/*
 *----------------------------------------------------------------------
 * 
 * DBus_ValidNameChars
 * 
 * 	Count the number of valid D-Bus name characters. Valid D-Bus name
 *	characters are "[A-Z][a-z][0-9]_".
 * 
 * Results:
 * 	Returns the number of valid name characters found.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_ValidNameChars(char* s)
{
   int cnt = 0;
   while ((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z') ||
	  (*s >= '0' && *s <= '9') || *s == '_') {
      s++;
      cnt++;
   }
   return cnt;
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_CheckBusName
 * 
 * 	Check if a user provided dbus name is valid. Passing a bad name
 * 	to dbus_bus_request_name or dbus_bus_release_name results in a
 *	panic, so instead of relying on the check from libdbus it has to
 * 	be recreated here.
 * 
 * Results:
 * 	Returns 1 if true, 0 if false.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_CheckBusName(Tcl_Obj* name)
{
   char* s;
   int length, n, unique = 0, periods = 0;

   s = Tcl_GetStringFromObj(name, &length);
   /* Bus names must not exceed the maximum name length */
   if (length > DBUS_MAXIMUM_NAME_LENGTH) return FALSE;
   /* Bus names that start with a colon (':') character are unique
      connection names. */
   if (*s == ':') {
      unique = 1;
      s++;
   }

   for (periods = 0; TRUE; periods++) {
      /* Only elements that are part of a unique connection name may begin with
         a digit, elements in other bus names must not begin with a digit. */
      if (!unique && *s >= '0' && *s <= '9') return FALSE;
      /* In addition to the normal set of valid characters, bus names may
       * contain dash ('-') characters */
      length = 0;
      while (*s == '-' || (n = DBus_ValidNameChars(s)) != 0) {
	 if (*s == '-') n = 1;
	 s += n;
	 length += n;
      }
      /* Bus names may not contain empty elements */
      if (length == 0) return FALSE;
      if (*s == '\0') break;
      if (*s++ != '.') return FALSE;
   }
   /* Bus names must contain at least one '.' (period) character */
   return (periods >= 1);
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_CheckIntfName
 * 
 * 	Check if a user provided dbus interface name is valid. Passing a
 *	bad name to dbus_bus_request_name or dbus_bus_release_name results
 *	in a panic, so instead of relying on the check from libdbus it has
 * 	to be recreated here.
 * 
 * Results:
 * 	Returns the number of separators found. Since valid interface
 *	names must have one or more separators the result can be treated
 *	as a boolean.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_CheckIntfName(Tcl_Obj* name)
{
   char* s;
   int length, n, periods;

   s = Tcl_GetStringFromObj(name, &length);
   /* Interface names must not exceed the maximum name length */
   if (length > DBUS_MAXIMUM_NAME_LENGTH) return FALSE;

   for (periods = 0; TRUE; periods++) {
      /* Interface name elements must not start with a digit */
      if (*s >= '0' && *s <= '9') return FALSE;
      /* Interface names may not contain empty elements */
      if ((n = DBus_ValidNameChars(s)) == 0) return FALSE;
      s += n;
      if (*s == '\0') break;
      if (*s++ != '.') return FALSE;
   }
   /* Interface names must contain at least one '.' (period) character */
   return periods;
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_CheckPath
 * 
 * 	Check if a user provided dbus path is valid. Passing a bad path
 * 	to dbus functions results in a panic, so instead of relying on the
 *	check from libdbus it has to be recreated here.
 * 
 * Results:
 * 	Returns 1 if true, 0 if false.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_CheckPath(Tcl_Obj* name)
{
   char *s;
   int length, n;

   s = Tcl_GetStringFromObj(name, &length);
   /* Paths may not be "" and must not exceed the maximum name length */
   if (length == 0 || length > DBUS_MAXIMUM_NAME_LENGTH) return FALSE;
   /* Paths must start with '/' */
   if (*s != '/') return FALSE;
   /* Test for path of exactly "/" as it would fail the trailing '/' check */
   if (length == 1) return TRUE;

   while (*s == '/') {
      /* no empty path components allowed */
      if ((n = DBus_ValidNameChars(++s)) == 0) return FALSE;
      s += n;
   }
   return (*s == '\0');
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_CheckMember
 * 
 * 	Check if a user provided dbus member is valid. Passing a bad member
 * 	to dbus functions results in a panic, so instead of relying on the
 *	check from libdbus it has to be recreated here.
 * 
 * Results:
 * 	Returns 1 if true, 0 if false.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_CheckMember(Tcl_Obj* name)
{
   char *s;
   int length;

   s = Tcl_GetStringFromObj(name, &length);
   /* Members may not be "" and must not exceed the maximum name length */
   if (length == 0 || length > DBUS_MAXIMUM_NAME_LENGTH) return FALSE;
   /* Members must not start with a digit */
   if (*s >= '0' && *s <= '9') return FALSE;
   s += DBus_ValidNameChars(s);
   return (*s == '\0');
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_CheckName
 * 
 * 	Check if a user provided string contains only valid characters.
 * 
 * Results:
 * 	Returns 1 if true, 0 if false.
 * 
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_CheckName(Tcl_Obj* name)
{
   char *s;
   int length;

   s = Tcl_GetStringFromObj(name, &length);
   /* Names may not be "" and must not exceed the maximum name length */
   if (length == 0 || length > DBUS_MAXIMUM_NAME_LENGTH) return FALSE;
   s += DBus_ValidNameChars(s);
   return (s == '\0');
}

/*
 *----------------------------------------------------------------------
 * 
 * DBus_BusType
 *	Check the Tcl variable for a valid bus type specification.
 *
 * Results:
 *	The bus type index, or -1 if the bus type was invalid.
 *
 * Side effects:
 * 	None.
 * 
 *----------------------------------------------------------------------
 */

int DBus_BusType(Tcl_Interp *interp, Tcl_Obj *const arg)
{
   int index;
   static const char *bustypes[] = {
      "session", "system", "starter", NULL
   };
   if (Tcl_GetIndexFromObj(NULL, arg, bustypes,
			   "", TCL_EXACT, &index) == TCL_OK) {
      return index;
   }
   if (Tcl_StringMatch(Tcl_GetString(arg), "dbus*")) 
     return N_BUS_TYPES;
   if (interp != NULL)
     Tcl_SetObjResult(interp, 
		      Tcl_ObjPrintf("bad busId \"%s\"", Tcl_GetString(arg)));
   return -1;
}

/*
 *----------------------------------------------------------------------
 * 
 * DBusValidateCmd
 *	Validate strings against various D-Bus rules
 * 
 * Results:
 *	A standard Tcl result.
 * 
 * Side effects:
 * 	On return, the result value of the interpreter contains a boolean
 *	indicating if the string passed validation.
 * 
 *----------------------------------------------------------------------
 */

int DBusValidateCmd(ClientData dummy, Tcl_Interp *interp,
		    int objc, Tcl_Obj *const objv[])
{
   int index, rc;

   static const char *options[] = {
      "interface", "member", "name", "path", "signature", NULL
   };
   enum options {
      DBUS_INTF, DBUS_MEMBER, DBUS_NAME, DBUS_PATH, DBUS_SIG
   };
   if (objc != 3) {
      Tcl_WrongNumArgs(interp, 1, objv, "class string");
      return TCL_ERROR;
   }
   if (Tcl_GetIndexFromObj(interp, objv[1], options,
			   "class", 0, &index) != TCL_OK) {
      return TCL_ERROR;
   }
   switch ((enum options) index) {
    case DBUS_INTF:
      rc = DBus_CheckIntfName(objv[2]);
      break;
    case DBUS_MEMBER:
      rc = DBus_CheckMember(objv[2]);
      break;
    case DBUS_NAME:
      rc = DBus_CheckBusName(objv[2]);
      break;
    case DBUS_PATH:
      rc = DBus_CheckPath(objv[2]);
      break;
    case DBUS_SIG:
      rc = dbus_signature_validate(Tcl_GetString(objv[2]), NULL);
      break;
    default:
      return TCL_ERROR;
   }
   Tcl_SetObjResult(interp, Tcl_NewBooleanObj(rc));
   return TCL_OK;
}
