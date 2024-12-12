//
//  CameraPublish.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 07/12/2024.
//

#import "CameraPublish.h"

static gboolean bus_call(GstBus *bus, GstMessage *msg, gpointer data) {
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"Message received: %s", message_type_name);
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_PROGRESS:
            NSLog(@"Progress message received.");
            break;
        case GST_MESSAGE_BUFFERING:
            NSLog(@"Buffering message received.");
            break;
        case GST_MESSAGE_ERROR: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_error(msg, &err, &debug_info);
            NSLog(@"Error received: %s", err->message);
            if (debug_info) {
                NSLog(@"Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_WARNING: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_warning(msg, &err, &debug_info);
            NSLog(@"Warning received: %s", err->message);
            if (debug_info) {
                NSLog(@"Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_EOS: {
            NSLog(@"End-of-Stream reached.");
            break;
        }
        case GST_MESSAGE_STATE_CHANGED: {
            GstState old_state, new_state, pending_state;
            gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
            NSLog(@"Pipeline state changed from %s to %s.",
                  gst_element_state_get_name(old_state),
                  gst_element_state_get_name(new_state));
            break;
        }
        default:
            break;
    }
    return TRUE;
}

@implementation CameraPublish

- (instancetype)init {
    self = [super init];
    if (self) {
        gst_init(nil, nil);
        gst_debug_set_default_threshold(GST_LEVEL_FIXME);
        _pipelineContext = (PipelineContext *)malloc(sizeof(PipelineContext)); // Initialize the struct with default values
    }
    return self;
}

- (void)run:(NSString*)rtsp withCallback:(StatusCallback)live_status {
//    gst_debug_set_threshold_for_name("videoconvert",GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("x264enc",GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("rtspclientsink",GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("capsfilter", GST_LEVEL_DEBUG);

    gchar *rtsp_url = (gchar *)[rtsp UTF8String];

    gchar *pipeline_description = g_strdup_printf("avfvideosrc device-index=1 fps=30 ! videoconvert ! queue ! x264enc tune=zerolatency key-int-max=30 ! queue ! rtspclientsink location=%s protocols=tcp debug=true", rtsp_url);
    g_print("%s\n", pipeline_description);

    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_description, &error);
    if (!pipeline) {
        NSLog(@"Failed to create GStreamer pipeline: %s", error->message);
        g_clear_error(&error);
        live_status(false);
        return;
    }

    // Add a bus to the pipeline
    GstBus *bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_call, NULL);  // Attach the bus call function
    gst_object_unref(bus);  // Unref the bus after adding the watch
    
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);

    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        gst_object_unref(pipeline);
        live_status(false);
        return;
    }
    _pipelineContext->mainContext = g_main_context_new();
    _mainLoop = g_main_loop_new(_pipelineContext->mainContext, FALSE);
    g_print("start pushing at %s\n", rtsp_url);
    live_status(true);
    g_main_loop_run(_mainLoop);
    live_status(false);
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    g_main_context_unref(_pipelineContext->mainContext);
    g_main_loop_unref(_mainLoop);
    g_print("stop pushing at %s\n", rtsp_url);
    _mainLoop = NULL;
}
- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status {
    gst_debug_set_threshold_for_name("appsrc", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("videoconvert", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("x264enc", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("rtspclientsink", GST_LEVEL_DEBUG);
    
    gchar *url = (gchar *)[rtsp UTF8String];
    
    _pipelineContext->mainContext = g_main_context_new();
    _mainLoop = g_main_loop_new(_pipelineContext->mainContext, FALSE);

    gchar *pipeline_description = g_strdup_printf("appsrc name=source ! videoconvert ! video/x-raw,format=I420 ! queue ! x264enc tune=zerolatency key-int-max=30 ! queue ! h264parse ! rtspclientsink location=%s protocols=tcp debug=true", url);
    g_print("%s\n", pipeline_description);

    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_description, &error);
    if (!pipeline) {
        NSLog(@"Failed to create GStreamer pipeline: %s", error->message);
        g_clear_error(&error);
        live_status(false);
        return;
    }
    
    GstElement *appsrcElement = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "source");
    if (appsrcElement) {
        _pipelineContext->appsrc = appsrcElement;
        GstCaps *caps = gst_caps_new_simple("video/x-raw",
                                            "format", G_TYPE_STRING, "BGRA",
                                            "width", G_TYPE_INT, 1920,
                                            "height", G_TYPE_INT, 1080,
                                            "framerate", GST_TYPE_FRACTION, 30, 1,
                                            NULL);
        gst_app_src_set_caps(GST_APP_SRC(_pipelineContext->appsrc), caps);
        gst_caps_unref(caps);
    } else {
        NSLog(@"Failed to retrieve the appsrc element.");
    }

    // Add a bus to the pipeline
    GstBus *bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_call, NULL);
    gst_object_unref(bus);

    // Set the pipeline to playing state
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);

    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        gst_object_unref(_pipelineContext->pipeline);
        live_status(false);
        return;
    }
    



    _pipelineContext->pipeline = pipeline;
    live_status(true);
    g_main_loop_run(_mainLoop);
    live_status(false);

    g_main_context_unref(_pipelineContext->mainContext);
    _pipelineContext->mainContext = NULL;

    g_main_loop_unref(_mainLoop);
    _mainLoop = NULL;
    
    if(_pipelineContext->pipeline) {
        gst_element_set_state(_pipelineContext->pipeline, GST_STATE_NULL);
        if(GST_OBJECT_REFCOUNT(_pipelineContext->pipeline)){
            gst_object_unref(_pipelineContext->pipeline);
        }
        _pipelineContext->pipeline = NULL;
    }
    
    if (_pipelineContext->appsrc) {
        if(GST_OBJECT_REFCOUNT(_pipelineContext->appsrc)){
            gst_object_unref(_pipelineContext->appsrc);
        }
        _pipelineContext->appsrc = NULL;
    }
}


- (void)stop {
    if(_mainLoop != NULL){
        g_main_loop_quit(_mainLoop);
    }
}

- (void)addBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!_pipelineContext->appsrc) {
        NSLog(@"appsrc is not initialized.");
        return;
    }
    if (!sampleBuffer) {
        NSLog(@"Received nil sampleBuffer.");
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        NSLog(@"Error: imageBuffer is NULL.");
        return;
    }
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    NSLog(@"Resolution: %zu x %zu", width,height);  // Example: 1920 x 1080
    NSLog(@"Pixel format: %u", pixelFormat);  // Example: kCVPixelFormatType_32BGRA

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    if (bufferSize == 0) {
        g_printerr("Error: Data size is zero, invalid buffer\n");
        return;
    }
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Create GstBuffer
    GstBuffer *gstBuffer = gst_buffer_new_allocate(NULL, bufferSize, NULL);
    CMTime pts = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    CMTime dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
    GstClockTime gst_pts = CMTimeGetSeconds(pts) * GST_SECOND;
    GstClockTime gst_dts = CMTimeGetSeconds(dts) * GST_SECOND;

    
    if (!gstBuffer) {
        NSLog(@"Failed to allocate GstBuffer.");
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return;
    }
    
    GstMapInfo map;
    if (gst_buffer_map(gstBuffer, &map, GST_MAP_WRITE)) {
        memcpy(map.data, baseAddress, bufferSize);
        gst_buffer_unmap(gstBuffer, &map);
    } else {
        NSLog(@"Failed to map GstBuffer.");
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        gst_buffer_unref(gstBuffer); // Ensure buffer is unreferenced on failure
        return;
    }
    

    // Check if gstBuffer is valid before pushing
    if (GST_IS_BUFFER(gstBuffer)) {
        GST_BUFFER_PTS (gstBuffer) = gst_pts;
        GST_BUFFER_DTS (gstBuffer) = gst_dts;
        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(_pipelineContext->appsrc), gstBuffer);
        NSLog(@"pushing buffer to appsrc: %s", gst_flow_get_name(ret));

        if (ret != GST_FLOW_OK) {
            NSLog(@"Failed to push buffer to appsrc. Flow return: %d", ret);
        }
    } else {
        NSLog(@"Invalid GstBuffer.");
    }

    // Do not unref until you are sure it is not used anymore
    gst_buffer_unref(gstBuffer);
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}



@end
