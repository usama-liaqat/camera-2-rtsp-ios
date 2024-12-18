//
//  CameraPublisher.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#import "CameraPublisher.h"

static gboolean bus_call(GstBus *bus, GstMessage *msg, gpointer data) {
//    PublisherContext *ctx = (PublisherContext *)data;
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"BUS -- Message received: %s", message_type_name);
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_PROGRESS:
            NSLog(@"BUS -- Progress message received.");
            break;
        case GST_MESSAGE_BUFFERING:
            NSLog(@"BUS -- Buffering message received.");
            break;
        case GST_MESSAGE_ERROR: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_error(msg, &err, &debug_info);
            NSLog(@"BUS -- Error received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_WARNING: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_warning(msg, &err, &debug_info);
            NSLog(@"BUS -- Warning received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_EOS: {
            NSLog(@"BUS -- End-of-Stream reached.");
            break;
        }
        case GST_MESSAGE_STATE_CHANGED: {
            GstState old_state, new_state, pending_state;
            gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
            NSLog(@"BUS -- Pipeline state changed from %s to %s.",
                  gst_element_state_get_name(old_state),
                  gst_element_state_get_name(new_state));
            break;
        }
        default:
            break;
    }
    return TRUE;
}


NSString *gstClockTimeToString(GstClockTime time) {
    guint64 seconds = GST_TIME_AS_SECONDS(time);
    guint64 nanoseconds = GST_TIME_AS_NSECONDS(time);

    // Calculate minutes, seconds, and milliseconds
    guint64 minutes = seconds / 60;
    seconds = seconds % 60;
    
    guint64 milliseconds = nanoseconds / 1000000;
    
    // Format as MM:SS.mmm
    return [NSString stringWithFormat:@"%02llu:%02llu.%03llu", minutes, seconds, milliseconds];
}


static GstFlowReturn need_data (GstElement * appsrc, guint unused, PublisherContext *ctx)
{
    
    BufferItem *buffer = [ctx->queue pop];
    NSLog(@"NEED_DATA  ---  buffer -> %@", buffer);

    if (buffer != nil) {
        CMSampleBufferRef sampleBuffer = buffer.sampleBuffer;
        int width =  buffer.width;
        int height = buffer.height;
        NSString *type = buffer.type;
        
        const char *format = [type UTF8String];

        // Log the values from the dictionary
//        NSLog(@"SampleBuffer: %@", sampleBuffer);
        NSDictionary *logDict = @{
            @"Width" : @(width),
            @"Height" : @(height),
            @"Type" : type,
            @"Offset" : @(ctx->offset),
        };

        NSLog(@"NEED_DATA  ---  %@", logDict);
        
        if (width != ctx->width || height != ctx->height) {
            ctx->width = width;
            ctx->height = height;
            NSLog(@"NEED_DATA  ---  Different Height.");
            GstCaps *caps = gst_caps_new_simple("video/x-raw",
                                                "format", G_TYPE_STRING, format,
                                                "width", G_TYPE_INT, (guint)width,
                                                "height", G_TYPE_INT, (guint)height,
                                                "framerate", GST_TYPE_FRACTION, 30, 1,
                                                NULL);
            gst_app_src_set_caps(GST_APP_SRC(appsrc), caps);
            gst_caps_unref(caps);
        }
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!imageBuffer) {
            NSLog(@"NEED_DATA  ---  Error: imageBuffer is NULL.");
            return GST_FLOW_ERROR;
        }
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
        if (bufferSize == 0) {
            g_printerr("NEED_DATA  ---  Error: Data size is zero, invalid buffer\n");
            return GST_FLOW_ERROR;
        }
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        GstBuffer *gstBuffer = gst_buffer_new_allocate(NULL, bufferSize, NULL);

        GstMapInfo map;
        if (gst_buffer_map(gstBuffer, &map, GST_MAP_WRITE)) {
            memcpy(map.data, baseAddress, bufferSize);
            gst_buffer_unmap(gstBuffer, &map);
        } else {
            NSLog(@"NEED_DATA  ---  Failed to map GstBuffer.");
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            gst_buffer_unref(gstBuffer); // Ensure buffer is unreferenced on failure
            return GST_FLOW_ERROR;
        }
 
        
//        GstClockTime gst_pts = isnan(ptsSeconds) ? GST_CLOCK_TIME_NONE: (ptsSeconds * GST_SECOND);
//        GstClockTime gst_dts = isnan(dtsSeconds) ? GST_CLOCK_TIME_NONE: (dtsSeconds * GST_SECOND);
//        
//        GST_BUFFER_OFFSET (gstBuffer) = ctx->offset++;
//        GST_BUFFER_OFFSET_END (gstBuffer) = GST_BUFFER_OFFSET (gstBuffer) + 1;
////        GST_BUFFER_PTS (gstBuffer) = gst_pts;
////        GST_BUFFER_DTS (gstBuffer) = gst_dts;
//        GST_BUFFER_TIMESTAMP(gstBuffer) = buffer.timestamp;
//        GST_BUFFER_DURATION(gstBuffer) = buffer.duration;
        
        GST_BUFFER_PTS (gstBuffer) = ctx->timestamp;
        GST_BUFFER_DURATION (gstBuffer) = gst_util_uint64_scale_int (1, GST_SECOND, 30);
        ctx->timestamp += GST_BUFFER_DURATION (gstBuffer);
        
        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), gstBuffer);
        NSLog(@"NEED_DATA  ---  pushing buffer to appsrc: %s", gst_flow_get_name(ret));
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return ret;
    } else {
        NSLog(@"NEED_DATA  ---  No data in buffer queue.");
    }
    
    NSLog(@"NEED_DATA  ---  GST_FLOW_ERROR Last");



    
    return GST_FLOW_ERROR;

}

@implementation CameraPublisher

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSLock alloc] init];
        gst_init(nil, nil);
        gst_debug_set_default_threshold(GST_LEVEL_FIXME);
        self.isRunning = NO;
        self.ctx = (PublisherContext *)malloc(sizeof(PublisherContext)); // Initialize the struct with default values
        self.ctx->pipeline = NULL;
        self.ctx->appsrc = NULL;
        self.ctx->width = 0;
        self.ctx->height = 0;
        self.ctx->offset = 0;
        self.ctx->timestamp = 0;
        self.ctx->queue = [[BufferQueue alloc] init];
        self.ctx->inputClock = CMClockGetHostTimeClock();

    }
    return self;
}

- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status {
    [self.lock lock];
    if (self.isRunning) {
        NSLog(@"Pipeline is already running. Aborting start.");
        live_status(true);
        [self.lock unlock];
        return;
    }
//    gst_debug_set_threshold_for_name("appsrc", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("videoconvert", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("x264enc", GST_LEVEL_DEBUG);
//    gst_debug_set_threshold_for_name("rtspclientsink", GST_LEVEL_DEBUG);
    
    gchar *url = (gchar *)[rtsp UTF8String];
    
    self.ctx->mainLoop = g_main_loop_new(NULL, FALSE);
    
    gchar *pipeline_description = g_strdup_printf("appsrc name=source ! "
                                                  "queue ! videoflip method=clockwise ! "
                                                  "videorate skip-to-first=true ! video/x-raw,framerate=30/1 ! "
                                                  "videoscale ! video/x-raw,width=1080,height=1920 ! "
                                                  "queue ! videoconvert ! video/x-raw,format=I420 ! "
                                                  "vtenc_h264 bitrate=5000 allow-frame-reordering=false realtime=true ! "
                                                  "queue ! h264parse config-interval=-1 ! "
                                                  "rtspclientsink location=%s latency=1 debug=true", url);
    g_print("%s\n", pipeline_description);

    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_description, &error);
    if (!pipeline) {
        NSLog(@"Failed to create GStreamer pipeline: %s", error->message);
        g_clear_error(&error);
        live_status(false);
        [self.lock unlock];
        return;
    }
    
    GstElement *appsrcElement = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "source");
    if (appsrcElement) {
        self.ctx->appsrc = appsrcElement;
        g_object_set(appsrcElement,
             "format", GST_FORMAT_TIME,
             "do-timestamp", (gboolean)true,
             "is-live", (gboolean)true,
             NULL
         );
        g_signal_connect (appsrcElement, "need-data", (GCallback) need_data, self.ctx);
    } else {
        NSLog(@"Failed to retrieve the appsrc element.");
    }

    // Add a bus to the pipeline
    GstBus *bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
    guint bus_watch_id =gst_bus_add_watch(bus, bus_call, self.ctx);
    gst_object_unref(bus);

    // Set the pipeline to playing state
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);

    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        gst_object_unref(self.ctx->pipeline);
        live_status(false);
        [self.lock unlock];
        return;
    }
    



    self.ctx->pipeline = pipeline;
    self.ctx->inputClock = CMClockGetHostTimeClock();
    live_status(true);
    _isRunning = YES;
    [self.lock unlock];
    g_main_loop_run(self.ctx->mainLoop);
    live_status(false);
    _isRunning = NO;
    g_source_remove (bus_watch_id);

    g_main_loop_unref(self.ctx->mainLoop);
    self.ctx->mainLoop = NULL;
    
    if(self.ctx->pipeline) {
        gst_element_set_state(self.ctx->pipeline, GST_STATE_NULL);
        if(GST_OBJECT_REFCOUNT(self.ctx->pipeline)){
            gst_object_unref(self.ctx->pipeline);
        }
        self.ctx->pipeline = NULL;
    }
    
    if (self.ctx->appsrc) {
        if(GST_OBJECT_REFCOUNT(self.ctx->appsrc)){
            gst_object_unref(self.ctx->appsrc);
        }
        self.ctx->appsrc = NULL;
    }
}


- (void)stop {
    [self.lock lock];
    if(self.isRunning && self.ctx->mainLoop != NULL){
        g_main_loop_quit(self.ctx->mainLoop);
    }
    [self.lock unlock];

}

- (void)addBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.ctx->appsrc) {
        NSLog(@"appsrc is not initialized.");
        return;
    }
    if (!sampleBuffer) {
        NSLog(@"Received nil sampleBuffer.");
        return;
    }

    
    BufferItem *item = [[BufferItem alloc] initWithSampleBuffer:sampleBuffer];
    if(item != nil) {
        [self.ctx->queue insert:item];
        GstState state, pending;
        GstStateChangeReturn ret;
        ret = gst_element_get_state(self.ctx->pipeline, &state, &pending, GST_SECOND);

        if (ret == GST_STATE_CHANGE_SUCCESS) {
            if (state == GST_STATE_PLAYING) {
                NSLog(@"STATUS --- Pipeline is in the PLAYING state.");
            } else if (state == GST_STATE_PAUSED) {
                NSLog(@"STATUS --- Pipeline is in the PAUSED state.");
            } else if (state == GST_STATE_READY) {
                NSLog(@"STATUS --- Pipeline is in the READY state.");
            } else {
                NSLog(@"STATUS --- Pipeline is in some other state.");
            }
        } else if (ret == GST_STATE_CHANGE_ASYNC) {
            NSLog(@"STATUS --- State change is asynchronous, waiting for completion...");
        } else if (ret == GST_STATE_CHANGE_NO_PREROLL) {
            NSLog(@"STATUS --- Pipeline is live and does not need preroll.");
        } else {
            NSLog(@"STATUS --- Failed to get pipeline state.");
        }
    }
}

@end
