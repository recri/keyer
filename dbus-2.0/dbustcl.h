#include "tcl.h"
#include <string.h>
#include <dbus/dbus.h>

#ifndef WIN32
#include <dlfcn.h>
#else
#include <windows.h>
#define RTLD_NOW 2
#define dlopen(lib, flags) LoadLibrary(lib)
#define dlsym(handle, symbol) (void *)GetProcAddress(handle, symbol)
#endif

/* The minimum version of the dbus library */
#define REQMAJOR 1
#define REQMINOR 2
#define REQMICRO 1

#define N_BUS_TYPES 3

#define NO_DBUS_MEM_DEBUG
#ifdef DBUS_MEM_DEBUG
#undef ckalloc
#define ckalloc(size) DBus_Alloc(size, __FILE__, __LINE__)
#undef ckfree
#define ckfree(ptr) DBus_Free(ptr, __FILE__, __LINE__)
#define refcount(str, obj) printf("%s ref count = %d\n", str, obj->refCount)
#endif

#define DBUSFLAG_ASYNC		1 << 0	/* No implicit result from method */
#define DBUSFLAG_NOREPLY	1 << 1	/* Caller doesn't want a result */
#define DBUSFLAG_FALLBACK	1 << 2	/* Fallback handler */
#define DBUSFLAG_DETAILS	1 << 3	/* Provide variant details */

/*
 * Some special tricks for 64-bit numbers. We can't rely on dbus_int64_t and
 * dbus_uint64_t because they can have the wrong size when compiling a 32-bit
 * application on a 64-bit machine.
 */

#ifdef TCL_WIDE_INT_IS_LONG
typedef long dbustcl_int64_t;
typedef unsigned long dbustcl_uint64_t;
#define DBUS_UINT64_FORMAT "%lu"
#else
typedef long long dbustcl_int64_t;
typedef unsigned long long dbustcl_uint64_t;
#define DBUS_UINT64_FORMAT "%llu"
#endif

typedef struct Tcl_DBusBus Tcl_DBusBus;

extern Tcl_HashTable bus;
extern Tcl_DBusBus *defaultbus;

typedef struct {
   Tcl_Interp *interp;
   Tcl_Obj *script;
} Tcl_DBusScriptData;

typedef struct {
   Tcl_DBusBus *dbus;
   Tcl_HashTable *signal, *method;
   int flags;
} Tcl_DBusHandlerData;

typedef struct {
   Tcl_Interp *interp;
   Tcl_Obj *script;
   int flags;
} Tcl_DBusMonitorData;

typedef struct {
   Tcl_Obj *script;
   int flags;
} Tcl_DBusSignalData;

typedef struct {
   Tcl_Interp *interp;
   Tcl_Obj *script;
   DBusConnection *conn;
   int flags;
} Tcl_DBusMethodData;

typedef struct {
   Tcl_Interp *interp;
   Tcl_Obj *script;
   DBusConnection *conn;
   int flags;
} Tcl_CallData;

typedef struct {
   Tcl_Event event;
   Tcl_Interp *interp;
   Tcl_Obj *script;
   DBusConnection *conn;
   DBusMessage *msg;
   int flags;
} Tcl_DBusEvent;

typedef union {
   char *str;
   dbus_uint32_t uint32;
   dbus_int32_t int32;
   dbus_uint16_t uint16;
   dbus_int16_t int16;
   dbustcl_uint64_t uint64;
   dbustcl_int64_t int64;
   double real;
   unsigned char byte;
} DBus_Value;

struct Tcl_DBusBus {
   DBusConnection *conn;
   Tcl_HashTable *snoop;
   Tcl_DBusHandlerData *fallback;
   int type;
};

/* dbusMain.c */
extern char *DBus_Alloc(int, char*, int);
extern void DBus_Free(char*, char*, int);
extern const char *DBus_InterpPath(Tcl_Interp*);
extern Tcl_DBusBus *DBus_GetConnection(Tcl_Interp*, Tcl_Obj *const);
extern int Tcl_CheckHashEmpty(Tcl_HashTable*);
extern void DBus_Disconnect(Tcl_Interp*, Tcl_HashEntry*);
extern void DBus_InterpDelete(ClientData, Tcl_Interp*);
  
/* dbusCommand.c */
extern Tcl_Command TclInitDBusCmd(Tcl_Interp*);
extern int DBus_MemoryError(Tcl_Interp*);

/* dbusEvent.c */
extern void DBus_SetupProc(ClientData, int);
extern void DBus_CheckProc(ClientData, int);
extern DBusHandlerResult DBus_Message(DBusConnection*, DBusMessage*, void*);
extern void DBus_Unregister(DBusConnection*, void*);
extern void DBus_CallResult(DBusPendingCall*, void*);
extern dbus_bool_t DBus_AddTimeout(DBusTimeout*, void*);
extern void DBus_RemoveTimeout(DBusTimeout*, void*);
extern void DBus_ToggleTimeout(DBusTimeout*, void*);
extern int DBusListenCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern int DBusMethodCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern int DBusUnknownCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern DBusHandlerResult DBus_Monitor(DBusConnection*, DBusMessage*, void*);
extern int DBusMonitorCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);

/* dbusMessage.c */
extern Tcl_Obj *DBus_MessageInfo(Tcl_Interp*, DBusMessage*);
extern Tcl_Obj *DBus_IterList(Tcl_Interp*, DBusMessageIter*, int);
extern int DBus_SendMessage(Tcl_Interp*, DBusConnection*, int, const char*,
		const char*, const char*, const char*, dbus_uint32_t,
		const char*, int, Tcl_Obj*const[]);
extern int DBus_Error (Tcl_Interp*, DBusConnection*, const char*,
		const char*, dbus_uint32_t, const char*);
extern int DBusCallCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern int DBusSignalCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern int DBusMethodReturnCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
extern int DBusErrorCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);

/* dbusSignature.c */
extern int DBus_ArgList(Tcl_Interp*, DBusMessageIter*, 
		DBusSignatureIter*, int*, Tcl_Obj*const[]);

/* dbusValidate.c */
extern int DBus_CheckBusName(Tcl_Obj*);
extern int DBus_CheckPath(Tcl_Obj*);
extern int DBus_CheckMember(Tcl_Obj*);
extern int DBus_CheckName(Tcl_Obj*);
extern int DBus_CheckIntfName(Tcl_Obj*);
extern int DBus_BusType(Tcl_Interp*, Tcl_Obj *const);
extern int DBusValidateCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
