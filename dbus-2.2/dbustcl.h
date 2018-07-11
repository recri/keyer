#include "tcl.h"
#include <string.h>
#include <stdint.h>
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

enum {
   TCL_DBUS_SESSION,
   TCL_DBUS_SYSTEM,
   TCL_DBUS_STARTER,
   TCL_DBUS_SHARED,
   TCL_DBUS_PRIVATE
};

#define TCL_DBUS_DEFAULT TCL_DBUS_SESSION

#ifndef SYSTEMBUSADDRESS
/* The system bus address as defined in /etc/dbus-1/system.conf */
#define SYSTEMBUSADDRESS "unix:path=/var/run/dbus/system_bus_socket"
#endif

#ifdef DBUS_MEM_DEBUG
#undef ckalloc
#define ckalloc(size) DBus_Alloc(size, __FILE__, __LINE__)
#undef attemptckalloc
#define attemptckalloc(size) DBus_AttemptAlloc(size, __FILE__, __LINE__)
#undef ckfree
#define ckfree(ptr) DBus_Free(ptr, __FILE__, __LINE__)
#undef Tcl_IncrRefCount
#define Tcl_IncrRefCount(ptr) DBus_RefCount(ptr, +1, __FILE__, __LINE__)
#undef Tcl_DecrRefCount
#define Tcl_DecrRefCount(ptr) DBus_RefCount(ptr, -1, __FILE__, __LINE__)
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
#define DBUS_UINT64_MASK 0x8000000000000000UL
#else
typedef long long dbustcl_int64_t;
typedef unsigned long long dbustcl_uint64_t;
#define DBUS_UINT64_FORMAT "%llu"
#define DBUS_UINT64_MASK 0x8000000000000000ULL
#endif

typedef struct Tcl_DBusBus Tcl_DBusBus;

extern dbus_int32_t dataSlot;
extern const char *busnames[];

typedef struct {
   Tcl_Interp *interp;
   Tcl_Obj *script;
} Tcl_DBusScriptData;

typedef struct {
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

typedef struct {
   Tcl_HashTable bus;
   Tcl_Obj *defaultbus;
   int dbusid;
} Tcl_DBusThreadData;

#define INT2PTR(p) ((void *)(intptr_t)(p))
#define PTR2INT(p) ((int)(intptr_t)(p))

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
   void *ptr;
   int fd;
} DBus_Value;

struct Tcl_DBusBus {
   Tcl_Obj *name;
   Tcl_HashTable *snoop;
   Tcl_DBusHandlerData *fallback;
   int type;
};

typedef struct {
   Tcl_Channel chan;
} Tcl_DBusWatchData;

/* dbusMain.c */
#ifdef DBUS_MEM_DEBUG
extern char *DBus_Alloc(int, char*, int);
extern char *DBus_AttemptAlloc(int, char*, int);
extern void DBus_Free(char*, char*, int);
extern void DBus_RefCount(Tcl_Obj *, int, char*, int);
#endif
extern void Tcl_DBusErrorCode(Tcl_Interp*, char*, DBusError);
extern const char *DBus_InterpPath(Tcl_Interp*);
extern Tcl_DBusThreadData *DBus_GetThreadData(Tcl_Interp*);
extern DBusConnection *DBus_GetConnection(Tcl_Interp*, Tcl_Obj *const);
extern int Tcl_CheckHashEmpty(Tcl_HashTable*);
extern void DBus_Close(Tcl_Interp*, DBusConnection*);
extern void DBus_InterpDelete(ClientData, Tcl_Interp*);

/* dbusCommand.c */
extern void DBusDispatchCancel(DBusConnection*);
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
#ifndef _WIN32
extern dbus_bool_t DBus_AddWatch(DBusWatch*, void*);
extern void DBus_RemoveWatch(DBusWatch*, void*);
extern void DBus_ToggleWatch(DBusWatch*, void*);
#endif
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
extern int DBus_ArgList(Tcl_Interp*, DBusConnection*, DBusMessageIter*,
		DBusSignatureIter*, int*, Tcl_Obj*const[]);
extern int DBus_BasicArg(Tcl_Interp*, DBusMessageIter*, int, Tcl_Obj*const);

/* dbusValidate.c */
extern int DBus_CheckBusName(Tcl_Obj*);
extern int DBus_CheckPath(Tcl_Obj*);
extern int DBus_CheckMember(Tcl_Obj*);
extern int DBus_CheckName(Tcl_Obj*);
extern int DBus_CheckIntfName(Tcl_Obj*);
extern int DBus_CheckSignature(Tcl_Obj*);
extern int DBus_BusType(Tcl_Interp *, Tcl_Obj **const);
extern int DBusValidateCmd(ClientData, Tcl_Interp*, int, Tcl_Obj *const[]);
