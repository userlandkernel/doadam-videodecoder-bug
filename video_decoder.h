#import <VideoToolbox/VideoToolbox.h>

#ifndef __VIDEO_DECODER_H_
#define __VIDEO_DECODER_H_




typedef struct decoding_session_e {

	CMVideoFormatDescriptionRef video_description;
	VTDecompressionSessionRef decoder_session;
} decoding_session_t;




OSStatus video_decoder_create_session(decoding_session_t * session);
void video_decoder_cleanup_session(decoding_session_t * session);
OSStatus video_decoder_write_oob(decoding_session_t * session, int offset, uint32_t surface_id);

#endif /* __VIDEO_DECODER_H_ */