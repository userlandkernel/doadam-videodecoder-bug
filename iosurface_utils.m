#include "iosurface_utils.h"
#include "log.h"
#include "utils.h"

static void * g_data = NULL;

/*
 * Function name: 	iosurface_utils_release_surface
 * Description:		Releases an IOSurface.
 * Returns:			kern_return_t.
 */

kern_return_t iosurface_utils_release_surface(io_connect_t connection, uint32_t surface_id_to_free) {
	
	kern_return_t ret = KERN_SUCCESS;
	uint64_t surface_id = (uint32_t)surface_id_to_free;

	ret = IOConnectCallMethod(connection,
		IOSURFACE_EXTERNAL_METHOD_RELEASE,
		&surface_id, 1,
		NULL, 0,
		NULL, 0,
		NULL, 0);

	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Error releasing surface ID %d", surface_id_to_free);
		goto cleanup;
	}

cleanup:
	return ret;
}


/*
 * Function name: 	iosurface_utils_create_surface
 * Description:		Creates an IOSurface object.
 * Returns:			kern_return_t with the IOKit call. 
 					Additionally, the IOSurface ID will be returned as an output parameter.
 */

kern_return_t iosurface_utils_create_surface(io_connect_t connection, uint32_t * surface_id_out, void * output_buffer_ptr) {
	
	kern_return_t ret = KERN_SUCCESS;
	char buf[0x1000] = {0};

	char output_buffer[IOSURFACE_DICTIONARY_SIZE] = {0};
	size_t output_buffer_size = sizeof(output_buffer);

	strcpy(buf, "<dict>");
	strcat(buf, "<key>IOSurfaceWidth</key>");
	strcat(buf, "<integer>100</integer>");
	strcat(buf, "<key>IOSurfaceHeight</key>");
	strcat(buf, "<integer>100</integer>");
	strcat(buf, "<key>IOSurfaceElementHeight</key>");
	strcat(buf, "<integer>10</integer>");
	strcat(buf, "<key>IOSurfaceElementWidth</key>");
	strcat(buf, "<integer>10</integer>");
	strcat(buf, "<key>IOSurfaceBytesPerElement</key>");
	strcat(buf, "<integer>1000</integer>");
	strcat(buf, "<key>IOSurfacePixelFormat</key>");
	strcat(buf, "<integer>875836518</integer>");
	strcat(buf, "<key>IOSurfaceIsGlobal</key>");
	strcat(buf, "<true/>");
	strcat(buf, "<key>IOSurfaceAllocSize</key><integer>352256</integer>");
	strcat(buf, "<key>IOSurfaceCacheMode</key><integer>256</integer>");
	//strcat(buf, "<key>IOSurfaceNonPurgeable</key><false/>");
	//strcat(buf, "<key>IOSurfacePreallocPages</key><true/>");
	//strcat(buf, "<key>IOSurfacePrefetchPages</key><true/>");


	/* Start plane definition */
	strcat(buf, "<key>IOSurfacePlaneInfo</key>");
	strcat(buf, "<array>");

	/* First plane */
	strcat(buf, "<dict>");
	strcat(buf, "<key>IOSurfacePlaneWidth</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneHeight</key><integer>2</integer>");
	strcat(buf, "<key>IOSurfacePlaneBytesPerElement</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneBitsPerBlock</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneElementWidth</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneElementHeight</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneBytesPerRow</key><integer>1</integer>");


	strcat(buf, "</dict>");

	/* Second plane */
	strcat(buf, "<dict>");
	strcat(buf, "<key>IOSurfacePlaneWidth</key><integer>10</integer>");
	strcat(buf, "<key>IOSurfacePlaneHeight</key><integer>100</integer>");
	strcat(buf, "<key>IOSurfacePlaneBytesPerElement</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneBitsPerBlock</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneElementWidth</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneElementHeight</key><integer>1</integer>");
	strcat(buf, "<key>IOSurfacePlaneBytesPerRow</key><integer>23</integer>");


	strcat(buf, "</dict>");

	/* End plane definition */
	strcat(buf, "</array>");

	//sprintf(buf + strlen(buf), "<key>IOSurfaceAddress</key><integer>0x%llx</integer>", g_data);
	strcat(buf, "</dict>");

	ret = IOConnectCallMethod(connection,
		IOSURFACE_EXTERNAL_METHOD_CREATE,
		NULL,
		0,
		buf,
		strlen(buf) + 1,
		NULL,NULL,
		output_buffer, &output_buffer_size);

	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Error creating IOSurface");
		goto cleanup;
	}

	*surface_id_out = *(uint32_t*)(output_buffer + IOSURFACE_SURFACE_ID_OFFSET);
	if (output_buffer_ptr)
	{
		memcpy(output_buffer_ptr, output_buffer, sizeof(output_buffer));
	}



cleanup:
	return ret;
}



/*
 * Function name: 	iosurface_utils_get_connection
 * Description:		Obtains a connection to an IOSurfaceRoot object.
 * Returns:			kern_return_t from the kernel. Accepts also an output parameter for an io_connect_t
 */
kern_return_t iosurface_utils_get_connection(io_connect_t * conn_out) {

	kern_return_t ret = KERN_SUCCESS;
	io_connect_t connection = 0;
	mach_port_t master_port = 0;
	io_iterator_t itr = 0;
	io_service_t service = 0;


	ret = host_get_io_master(mach_host_self(), &master_port);
	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Failed getting master port");
		goto cleanup;
	}

	ret = IOServiceGetMatchingServices(master_port, IOServiceMatching(IOSURFACE_IOKIT_SERVICE), &itr);
	if (KERN_SUCCESS != ret)
	{
		ERROR_LOG("Failed getting matching services");
		goto cleanup;
	}

	while(IOIteratorIsValid(itr) && (service = IOIteratorNext(itr))) {
		ret = IOServiceOpen(service, mach_task_self(), 0, &connection);
		if (KERN_SUCCESS != ret)
		{
			continue;
		}
	}

	if (NULL == g_data)
	{
		g_data = malloc(0x1000*2 - 10);
		if (g_data)
		{
			memset(g_data, 0x41, (0x1000*2) - 10);
		}
	}

cleanup:

	if (KERN_SUCCESS == ret)
	{
		*conn_out = connection;
	}

	if (itr)
	{
		itr = 0;
	}

	return ret;

}