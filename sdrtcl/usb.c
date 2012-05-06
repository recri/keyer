/* tcl interface for libusb */

#include <tcl.h>
#include <string.h>
#include <libusb.h>

#define MY_INIT Usb_Init
#define MY_PACKAGE_NAME	"usb"
#define MY_PACKAGE_VERSION "1.0"
#define MY_NAMESPACE "usb"

/* Compatibility version for TCL stubs */
#ifndef MY_TCL_STUBS_VERSION
#define MY_TCL_STUBS_VERSION "8.5"
#endif
#ifndef MY_TK_STUBS_VERSION
#define MY_TK_STUBS_VERSION "8.5"
#endif

/*
** this is what we need to do widget-control
** and usbsoftrock with serial number matching.
*/

/*
** error translations.
*/
static int usb_error(ClientData clientData, Tcl_Interp *interp, int libusb_status) {
  char *errstr = NULL;
  switch (libusb_status) {
  case LIBUSB_SUCCESS: break;
  case LIBUSB_ERROR_IO: errstr = "Input/output error."; break;
  case LIBUSB_ERROR_INVALID_PARAM: errstr = "Invalid parameter."; break;
  case LIBUSB_ERROR_ACCESS: errstr = "Access denied (insufficient permissions)."; break;
  case LIBUSB_ERROR_NO_DEVICE: errstr = "No such device (it may have been disconnected)."; break;
  case LIBUSB_ERROR_NOT_FOUND: errstr = "Entity not found."; break;
  case LIBUSB_ERROR_BUSY: errstr = "Resource busy."; break;
  case LIBUSB_ERROR_TIMEOUT: errstr = "Operation timed out."; break;
  case LIBUSB_ERROR_OVERFLOW: errstr = "Overflow."; break;
  case LIBUSB_ERROR_PIPE: errstr = "Pipe error."; break;
  case LIBUSB_ERROR_INTERRUPTED: errstr = "System call interrupted (perhaps due to signal)."; break;
  case LIBUSB_ERROR_NO_MEM: errstr = "Insufficient memory."; break;
  case LIBUSB_ERROR_NOT_SUPPORTED: errstr = "Operation not supported or unimplemented on this platform."; break;
  case LIBUSB_ERROR_OTHER: errstr = "Other error."; break;
  default: {
    static char buff[256];
    sprintf(buff, "undefined libusb error %d", libusb_status);
    errstr = buff; break;
  }
  }
  if (errstr == NULL) return TCL_OK;
  Tcl_SetResult(interp, errstr, TCL_STATIC);
  return TCL_ERROR;
}

/*
** argument manglers
*/
static int usb_get_long(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, long *val) {
  if (objc <= objn) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("argument %d is greater than count %d", objn, objc));
    return TCL_ERROR;
  }
  if (Tcl_GetLongFromObj(interp, objv[objn], val) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_get_int(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, int *val) {
  if (objc <= objn) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("argument %d is greater than count %d", objn, objc));
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[objn], val) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_get_bytes(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, unsigned char **bytes, int *bytes_length) {
  if (objc <= objn) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("argument %d is greater than count %d", objn, objc));
    return TCL_ERROR;
  }
  *bytes = Tcl_GetByteArrayFromObj(objv[objn], bytes_length);
  return TCL_OK;
}

static int usb_get_uint16_t(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, uint16_t *val, char *cname, char *pname) {
  int ival;
  if (usb_get_int(clientData, interp, objc, objv, objn, &ival) != TCL_OK) {
    return TCL_ERROR;
  }
  if ((uint16_t)ival != ival) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s: %s: integer value %d is not an 16 bit result", cname, pname, ival));
    return TCL_ERROR;
  }
  *val = (uint16_t)ival;
  return TCL_OK;
}

static int usb_get_uint8_t(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, uint8_t *val, char *cname, char *pname) {
  int ival;
  if (usb_get_int(clientData, interp, objc, objv, objn, &ival) != TCL_OK) {
    return TCL_ERROR;
  }
  if ((uint8_t)ival != ival) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s: %s: integer value %d is not an 8 bit result", cname, pname, ival));
    return TCL_ERROR;
  }
  *val = (uint8_t)ival;
  return TCL_OK;
}

static int usb_get_libusb_device(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, libusb_device **dev) {
  long val;
  if (usb_get_long(clientData, interp, objc, objv, objn, &val) != TCL_OK) {
    return TCL_ERROR;
  }
  *dev = (libusb_device *)val;
  return TCL_OK;
}

static int usb_get_libusb_device_handle(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[], int objn, libusb_device_handle **handle) {
  long val;
  if (usb_get_long(clientData, interp, objc, objv, objn, &val) != TCL_OK) {
    return TCL_ERROR;
  }
  *handle = (libusb_device_handle *)val;
  return TCL_OK;
}

/*
** entry points
*/
static int usb_set_debug(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  int level;
  if (usb_get_int(clientData, interp, objc, objv, 1, &level) != TCL_OK) {
    return TCL_ERROR;
  }
  libusb_set_debug(NULL, level);
}

static int usb_init(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  return usb_error(clientData, interp, libusb_init(NULL));
}
  
static int usb_exit(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_exit(NULL);
  return TCL_OK;
}

static int usb_get_device_list(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device **list;
  int n = libusb_get_device_list(NULL, &list), i;
  Tcl_Obj *blist = Tcl_NewListObj(0, NULL);
  if (n < 0) {
    Tcl_DecrRefCount(blist);
    return usb_error(clientData, interp, n);
  }
  for (i = 0; i < n; i += 1) {
    if (Tcl_ListObjAppendElement(interp, blist, Tcl_NewLongObj((long)list[i])) == TCL_ERROR) {
      libusb_free_device_list(list, 1);
      Tcl_DecrRefCount(blist);
      return TCL_ERROR;
    }
  }
  libusb_free_device_list(list, 0);
  Tcl_SetObjResult(interp, blist);
  return TCL_OK;
}

static int usb_get_device_descriptor(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device *dev;
  struct libusb_device_descriptor desc;
  Tcl_Obj *dlist = Tcl_NewListObj(0, NULL);
  if (usb_get_libusb_device(clientData, interp, objc, objv, 1, &dev) != TCL_OK ||
      usb_error(clientData, interp, libusb_get_device_descriptor(dev, &desc)) != TCL_OK) {
    Tcl_DecrRefCount(dlist);
    return TCL_ERROR;
  }
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bLength",-1));	/** Size of this descriptor (in bytes) */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bLength));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bDescriptorType",-1));/** Descriptor type */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bDescriptorType));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bcdUSB",-1));	/** USB specification release number in binary-coded decimal. */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bcdUSB));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bDeviceClass",-1));	/** USB-IF class code for the device */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bDeviceClass));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bDeviceSubClass",-1));/** USB-IF subclass code for the device */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bDeviceSubClass));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bDeviceProtocol",-1));/** USB-IF protocol code for the device */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bDeviceProtocol));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bMaxPacketSize0",-1));/** Maximum packet size for endpoint 0 */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bMaxPacketSize0));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("idVendor",-1));	/** USB-IF vendor ID */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.idVendor));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("idProduct",-1));	/** USB-IF product ID */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.idProduct));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bcdDevice",-1));	/** Device release number in binary-coded decimal */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bcdDevice));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("iManufacturer",-1));/** Index of string descriptor describing manufacturer */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.iManufacturer));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("iProduct",-1));	/** Index of string descriptor describing product */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.iProduct));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("iSerialNumber",-1));/** Index of string descriptor containing device serial number */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.iSerialNumber));
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewStringObj("bNumConfigurations",-1));/** Number of possible configurations */
  Tcl_ListObjAppendElement(interp, dlist, Tcl_NewIntObj(desc.bNumConfigurations));
  Tcl_SetObjResult(interp, dlist);
  return TCL_OK;
}

static int usb_get_bus_number(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device *dev;
  if (usb_get_libusb_device(clientData, interp, objc, objv, 1, &dev) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewIntObj(libusb_get_bus_number(dev)));
  return TCL_OK;
}

static int usb_get_device_address(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device *dev;
  if (usb_get_libusb_device(clientData, interp, objc, objv, 1, &dev) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewIntObj(libusb_get_device_address(dev)));
  return TCL_OK;
}

static int usb_unref_device(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device *dev;
  if (usb_get_libusb_device(clientData, interp, objc, objv, 1, &dev) != TCL_OK)
    return TCL_ERROR;
  libusb_unref_device(dev);
  return TCL_OK;
}

static int usb_open(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device *dev;
  libusb_device_handle *handle;
  if (usb_get_libusb_device(clientData, interp, objc, objv, 1, &dev) != TCL_OK ||
      usb_error(clientData, interp, libusb_open((libusb_device *)dev, &handle)) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewLongObj((long)handle));
  return TCL_OK;
}
  
static int usb_close(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK) {
    return TCL_ERROR;
  }
  libusb_close(handle);
  return TCL_OK;
}

static int usb_claim_interface(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  int iface;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 2, &iface) != TCL_OK ||
      usb_error(clientData, interp, libusb_claim_interface(handle, iface)) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_release_interface(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  int iface;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 2, &iface) != TCL_OK ||
      usb_error(clientData, interp, libusb_release_interface(handle, iface)) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_kernel_driver_active(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  int iface;
  int active;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 2, &iface) != TCL_OK ||
      usb_error(clientData, interp, active = libusb_kernel_driver_active(handle, iface)) != TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewIntObj(active));
  return TCL_OK;
}

static int usb_detach_kernel_driver(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  int iface;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 2, &iface) != TCL_OK ||
      usb_error(clientData, interp, libusb_detach_kernel_driver(handle, iface)) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_attach_kernel_driver(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  int iface;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 2, &iface) != TCL_OK ||
      usb_error(clientData, interp, libusb_attach_kernel_driver(handle, iface)) != TCL_OK) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

static int usb_control_transfer(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  uint8_t request_type, request;
  uint16_t value, index;
  unsigned char *bytes;
  int bytes_length;
  unsigned char data[1024];
  int length, timeout;
  // fprintf(stderr, "usb_control_transfer: %s %s %s %s\n", Tcl_GetString(objv[0]), Tcl_GetString(objv[1]), Tcl_GetString(objv[2]), Tcl_GetString(objv[3]));
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_uint8_t(clientData, interp, objc, objv, 2, &request_type, "usb::control_transfer", "request_type") != TCL_OK ||
      usb_get_uint8_t(clientData, interp, objc, objv, 3, &request, "usb::control_transfer", "request") != TCL_OK ||
      usb_get_uint16_t(clientData, interp, objc, objv, 4, &value, "usb::control_transfer", "value") != TCL_OK ||
      usb_get_uint16_t(clientData, interp, objc, objv, 5, &index, "usb::control_transfer", "index") != TCL_OK ||
      usb_get_bytes(clientData, interp, objc, objv, 6, &bytes, &bytes_length) != TCL_OK ||
      usb_get_int(clientData, interp, objc, objv, 7, &timeout) != TCL_OK) {
    return TCL_ERROR;
  }
  if (bytes_length > sizeof(data)) {
    return TCL_ERROR;
  }
  memcpy(data, bytes, bytes_length);
  length = libusb_control_transfer(handle, request_type, request, value, index, data, bytes_length, timeout);
  if (length >= sizeof(data) || length < 0) {
    return usb_error(clientData, interp, length);
  }
  Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(data, length));
  return TCL_OK;
}

static int usb_get_descriptor(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  uint8_t desc_type, desc_index;
  unsigned char data[1024];
  int length;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_uint8_t(clientData, interp, objc, objv, 2, &desc_type, "usb::get_descriptor", "desc_type") != TCL_OK ||
      usb_get_uint8_t(clientData, interp, objc, objv, 3, &desc_index, "usb::get_descriptor", "desc_index") != TCL_OK) {
    return TCL_ERROR;
  }
  length = libusb_get_descriptor(handle, desc_type,desc_index, data, sizeof(data));
  if (length >= sizeof(data) || length < 0) {
    return usb_error(clientData, interp, length);
  }
  Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(data, length));
  return TCL_OK;
}

static int usb_get_string_descriptor(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  libusb_device_handle *handle;
  uint8_t desc_index;
  uint16_t langid;
  unsigned char data[1024];
  int length;
  if (usb_get_libusb_device_handle(clientData, interp, objc, objv, 1, &handle) != TCL_OK ||
      usb_get_uint8_t(clientData, interp, objc, objv, 2, &desc_index, "usb::get_string_descriptor", "desc_index") != TCL_OK ||
      usb_get_uint16_t(clientData, interp, objc, objv, 3, &langid, "usb::get_string_descriptor", "langid") != TCL_OK) {
    return TCL_ERROR;
  }
  length = libusb_get_string_descriptor(handle, desc_index,langid, data, sizeof(data));
  if (length >= sizeof(data) || length < 0) {
    return usb_error(clientData, interp, length);
  }
  Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(data, length));
  return TCL_OK;
}

int MY_INIT(Tcl_Interp *interp) {
  int i;
  if (interp == 0) return TCL_ERROR;
#ifdef USE_TCL_STUBS
  /* (char*) cast is required to avoid compiler warning/error for Tcl < 8.4. */
  if (Tcl_InitStubs(interp, (char*)MY_TCL_STUBS_VERSION, 0) == NULL) {
    return TCL_ERROR;
  }
#endif  
#ifdef USE_TK_STUBS
  /* (char*) cast is required to avoid compiler warning/error. */
  if (Tk_InitStubs(interp, (char*)MY_TCL_STUBS_VERSION, 0) == NULL) {
    return TCL_ERROR;
  }
#endif
  
  Tcl_PkgProvide(interp, (char*)MY_PACKAGE_NAME, (char*)MY_PACKAGE_VERSION);
  
#ifdef MY_NAMESPACE
  Tcl_Eval(interp, "namespace eval " MY_NAMESPACE " { }");
#endif
  
  Tcl_CreateObjCommand(interp, "usb::set_debug", usb_set_debug, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::init", usb_init, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::exit", usb_exit, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_device_list", usb_get_device_list, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_device_descriptor", usb_get_device_descriptor, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_bus_number", usb_get_bus_number, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_device_address", usb_get_device_address, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::unref_device", usb_unref_device, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::open", usb_open, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::close", usb_close, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::claim_interface", usb_claim_interface, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::release_interface", usb_release_interface, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::kernel_driver_active", usb_kernel_driver_active, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::detach_kernel_driver", usb_detach_kernel_driver, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::attach_kernel_driver", usb_attach_kernel_driver, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::control_transfer", usb_control_transfer, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_descriptor", usb_get_descriptor, NULL, NULL);
  Tcl_CreateObjCommand(interp, "usb::get_string_descriptor", usb_get_string_descriptor, NULL, NULL);
  
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_PER_INTERFACE", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_PER_INTERFACE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_AUDIO", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_AUDIO), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_COMM", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_COMM), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_HID", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_HID), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_PRINTER", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_PRINTER), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_PTP", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_PTP), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_MASS_STORAGE", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_MASS_STORAGE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_HUB", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_HUB), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_DATA", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_DATA), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::CLASS_VENDOR_SPEC", -1), NULL, Tcl_NewIntObj(LIBUSB_CLASS_VENDOR_SPEC), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_DEVICE", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_DEVICE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_CONFIG", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_CONFIG), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_STRING", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_STRING), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_INTERFACE", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_INTERFACE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_ENDPOINT", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_ENDPOINT), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_HID", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_HID), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_REPORT", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_REPORT), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_PHYSICAL", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_PHYSICAL), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::DT_HUB", -1), NULL, Tcl_NewIntObj(LIBUSB_DT_HUB), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ENDPOINT_IN", -1), NULL, Tcl_NewIntObj(LIBUSB_ENDPOINT_IN), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ENDPOINT_OUT", -1), NULL, Tcl_NewIntObj(LIBUSB_ENDPOINT_OUT), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TYPE_CONTROL", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TYPE_CONTROL), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TYPE_ISOCHRONOUS", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TYPE_ISOCHRONOUS), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TYPE_BULK", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TYPE_BULK), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TYPE_INTERRUPT", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TYPE_INTERRUPT), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TYPE_MASK", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TYPE_MASK), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_GET_STATUS", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_GET_STATUS), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_CLEAR_FEATURE", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_CLEAR_FEATURE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SET_FEATURE", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SET_FEATURE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SET_ADDRESS", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SET_ADDRESS), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_GET_DESCRIPTOR", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_GET_DESCRIPTOR), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SET_DESCRIPTOR", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SET_DESCRIPTOR), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_GET_CONFIGURATION", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_GET_CONFIGURATION), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SET_CONFIGURATION", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SET_CONFIGURATION), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_GET_INTERFACE", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_GET_INTERFACE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SET_INTERFACE", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SET_INTERFACE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_SYNCH_FRAME", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_SYNCH_FRAME), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_TYPE_STANDARD", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_TYPE_STANDARD), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_TYPE_CLASS", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_TYPE_CLASS), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_TYPE_VENDOR", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_TYPE_VENDOR), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::REQUEST_TYPE_RESERVED", -1), NULL, Tcl_NewIntObj(LIBUSB_REQUEST_TYPE_RESERVED), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::RECIPIENT_DEVICE", -1), NULL, Tcl_NewIntObj(LIBUSB_RECIPIENT_DEVICE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::RECIPIENT_ENDPOINT", -1), NULL, Tcl_NewIntObj(LIBUSB_RECIPIENT_ENDPOINT), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::RECIPIENT_OTHER", -1), NULL, Tcl_NewIntObj(LIBUSB_RECIPIENT_OTHER), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_SYNC_TYPE_NONE", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_SYNC_TYPE_NONE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_SYNC_TYPE_ASYNC", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_SYNC_TYPE_ASYNC), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_SYNC_TYPE_ADAPTIVE", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_SYNC_TYPE_ADAPTIVE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_SYNC_TYPE_SYNC", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_SYNC_TYPE_SYNC), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_USAGE_TYPE_DATA", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_USAGE_TYPE_DATA), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_USAGE_TYPE_FEEDBACK", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_USAGE_TYPE_FEEDBACK), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::ISO_USAGE_TYPE_IMPLICIT", -1), NULL, Tcl_NewIntObj(LIBUSB_ISO_USAGE_TYPE_IMPLICIT), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_COMPLETED", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_COMPLETED), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_ERROR", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_ERROR), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_TIMED_OUT", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_TIMED_OUT), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_CANCELLED", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_CANCELLED), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_STALL", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_STALL), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_NO_DEVICE", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_NO_DEVICE), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_OVERFLOW", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_OVERFLOW), TCL_GLOBAL_ONLY);

  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_SHORT_NOT_OK", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_SHORT_NOT_OK), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_FREE_BUFFER", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_FREE_BUFFER), TCL_GLOBAL_ONLY);
  Tcl_ObjSetVar2(interp, Tcl_NewStringObj("usb::TRANSFER_FREE_TRANSFER", -1), NULL, Tcl_NewIntObj(LIBUSB_TRANSFER_FREE_TRANSFER), TCL_GLOBAL_ONLY);

  return TCL_OK;
}

