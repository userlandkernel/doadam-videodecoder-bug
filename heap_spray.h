

#include <mach/mach.h>
#ifndef __HEAP_SPRAY_H_
#define __HEAP_SPRAY_H_

#define NUMBER_OF_OBJECTS_TO_SPRAY					(30)
#define NUMBER_OF_SURFACES_TO_SPRAY					((NUMBER_OF_OBJECTS_TO_SPRAY / 2) / 2)


kern_return_t heap_spray_start_spraying(void);
kern_return_t heap_spray_init(void);
void heap_spray_cleanup(void);
uint32_t heap_spray_get_sprayed_surface_id(uint32_t index);
mach_port_t heap_spray_get_sprayed_preallocated_msg(uint32_t index);

void* heap_spray_get_surface_object(uint32_t surface_id);
void* heap_spray_get_io_surface_root(void);


#endif /* __HEAP_SPRAY_H_ */