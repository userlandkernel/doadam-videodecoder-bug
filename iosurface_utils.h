/*
	API for basic communication with IOSurfaceRootUserClient
*/

#include <mach/mach.h>
#include <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>



#ifndef IOSURFACE_UTILS_H_
#define IOSURFACE_UTILS_H_

#define IOSURFACE_IOKIT_SERVICE											("IOSurfaceRoot")

#define IOSURFACE_EXTERNAL_METHOD_CREATE								(0)
#define IOSURFACE_EXTERNAL_METHOD_RELEASE								(1)

#define IOSURFACE_DICTIONARY_SIZE										(0xBC8)
#define IOSURFACE_SURFACE_ID_OFFSET                                                                            (0x10)


kern_return_t iosurface_utils_get_connection(io_connect_t * conn_out);
kern_return_t iosurface_utils_create_surface(io_connect_t connection, uint32_t * surface_id_out, void * output_buffer);
kern_return_t iosurface_utils_release_surface(io_connect_t connection, uint32_t surface_id_to_free);

#endif /* IOSURFACE_UTILS_H_ */