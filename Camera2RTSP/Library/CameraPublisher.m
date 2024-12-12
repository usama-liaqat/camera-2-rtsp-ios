//
//  CameraPublisher.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#import "CameraPublisher.h"


static void get_sample_buffer(PublisherContext *ctx, CMSampleBufferRef sbuf,GstClockTime *outTimestamp,GstClockTime *outDuration ) {
    CMSampleTimingInfo time_info;
    GstClockTime timestamp, avf_timestamp, duration, input_clock_now, input_clock_diff, running_time;
    CMItemCount num_timings;
    GstClock *clock;
    CMTime now;

    timestamp = GST_CLOCK_TIME_NONE;
    duration = GST_CLOCK_TIME_NONE;
    if (CMSampleBufferGetOutputSampleTimingInfoArray(sbuf, 1, &time_info, &num_timings) == noErr) {
    avf_timestamp = gst_util_uint64_scale (GST_SECOND,
            time_info.presentationTimeStamp.value, time_info.presentationTimeStamp.timescale);

    if (CMTIME_IS_VALID (time_info.duration) && time_info.duration.timescale != 0)
      duration = gst_util_uint64_scale (GST_SECOND,
          time_info.duration.value, time_info.duration.timescale);

        now = CMClockGetTime(ctx->inputClock);
    input_clock_now = gst_util_uint64_scale (GST_SECOND,
        now.value, now.timescale);
    input_clock_diff = input_clock_now - avf_timestamp;

    GST_OBJECT_LOCK (ctx->appsrc);
    clock = GST_ELEMENT_CLOCK (ctx->appsrc);
    if (clock) {
      running_time = gst_clock_get_time (clock) - ctx->appsrc->base_time;
      /* We use presentationTimeStamp to determine how much time it took
       * between capturing and receiving the frame in our delegate
       * (e.g. how long it spent in AVF queues), then we subtract that time
       * from our running time to get the actual timestamp.
       */
      if (running_time >= input_clock_diff)
        timestamp = running_time - input_clock_diff;
      else
        timestamp = running_time;

      GST_DEBUG_OBJECT (ctx->appsrc, "AVF clock: %"GST_TIME_FORMAT ", AVF PTS: %"GST_TIME_FORMAT
          ", AVF clock diff: %"GST_TIME_FORMAT
          ", running time: %"GST_TIME_FORMAT ", out PTS: %"GST_TIME_FORMAT,
          GST_TIME_ARGS (input_clock_now), GST_TIME_ARGS (avf_timestamp),
          GST_TIME_ARGS (input_clock_diff),
          GST_TIME_ARGS (running_time), GST_TIME_ARGS (timestamp));
    } else {
      /* no clock, can't set timestamps */
      timestamp = GST_CLOCK_TIME_NONE;
    }
    GST_OBJECT_UNLOCK (ctx->appsrc);
    }

    *outTimestamp = timestamp;
    *outDuration = duration;
}

static gboolean bus_call(GstBus *bus, GstMessage *msg, gpointer data) {
    PublisherContext *ctx = (PublisherContext *)data;
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"BUS -- Message received: %s", message_type_name);
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
    if (buffer != nil) {
        CMSampleBufferRef sampleBuffer = buffer.sampleBuffer;
        int width =  buffer.width;
        int height = buffer.height;
        NSString *type = buffer.type;
        
        const char *format = [type UTF8String];
        double ptsSeconds = CMTimeGetSeconds(buffer.pts);
        double dtsSeconds = CMTimeGetSeconds(buffer.dts);
        
        NSString *timestampStr = gstClockTimeToString(buffer.timestamp);
        NSString *durationStr = gstClockTimeToString(buffer.duration);

        // Log the values from the dictionary
//        NSLog(@"SampleBuffer: %@", sampleBuffer);
        NSDictionary *logDict = @{
            @"Width" : @(width),
            @"Height" : @(height),
            @"PTS" : @(ptsSeconds),
            @"DTS" : @(dtsSeconds),
            @"Type" : type,
            @"Timestamp" : timestampStr,
            @"Duration" : durationStr,
            @"Offset" : @(ctx->offset),
        };

        NSLog(@"BUFFER DATA ---- %@", logDict);
        
        if (width != ctx->width || height != ctx->height) {
            ctx->width = width;
            ctx->height = height;
            NSLog(@"Different Height.");
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
            NSLog(@"Error: imageBuffer is NULL.");
            return GST_FLOW_ERROR;
        }
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
        if (bufferSize == 0) {
            g_printerr("Error: Data size is zero, invalid buffer\n");
            return GST_FLOW_ERROR;
        }
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        GstBuffer *gstBuffer = gst_buffer_new_allocate(NULL, bufferSize, NULL);

        GstMapInfo map;
        if (gst_buffer_map(gstBuffer, &map, GST_MAP_WRITE)) {
            memcpy(map.data, baseAddress, bufferSize);
            gst_buffer_unmap(gstBuffer, &map);
        } else {
            NSLog(@"Failed to map GstBuffer.");
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            gst_buffer_unref(gstBuffer); // Ensure buffer is unreferenced on failure
            return GST_FLOW_ERROR;
        }
 
        
        GstClockTime gst_pts = isnan(ptsSeconds) ? GST_CLOCK_TIME_NONE: (ptsSeconds * GST_SECOND);
        GstClockTime gst_dts = isnan(dtsSeconds) ? GST_CLOCK_TIME_NONE: (dtsSeconds * GST_SECOND);
        
        GST_BUFFER_OFFSET (gstBuffer) = ctx->offset++;
        GST_BUFFER_OFFSET_END (gstBuffer) = GST_BUFFER_OFFSET (gstBuffer) + 1;
        GST_BUFFER_PTS (gstBuffer) = gst_pts;
        GST_BUFFER_DTS (gstBuffer) = gst_dts;
        GST_BUFFER_TIMESTAMP(gstBuffer) = buffer.timestamp;
        GST_BUFFER_DURATION(gstBuffer) = buffer.duration;
        
        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), gstBuffer);
        NSLog(@"pushing buffer to appsrc: %s", gst_flow_get_name(ret));
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        [buffer free];
        return ret;
    } else {
        NSLog(@"No data in buffer queue.");
    }
    
    NSLog(@"GST_FLOW_ERROR Last");



    
    return GST_FLOW_ERROR;

}

@implementation CameraPublisher

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSLock alloc] init];
        gst_init(nil, nil);
        gst_debug_set_default_threshold(GST_LEVEL_ERROR);
        self.isRunning = NO;
        self.ctx = (PublisherContext *)malloc(sizeof(PublisherContext)); // Initialize the struct with default values
        self.ctx->pipeline = NULL;
        self.ctx->appsrc = NULL;
        self.ctx->width = 0;
        self.ctx->height = 0;
        self.ctx->offset = 0;
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
    
    self.ctx->mainContext = g_main_context_new();
    self.ctx->mainLoop = g_main_loop_new(self.ctx->mainContext, FALSE);

    gchar *pipeline_description = g_strdup_printf("appsrc name=source ! videoconvert ! video/x-raw,format=I420 ! queue ! x264enc tune=zerolatency key-int-max=30 ! queue ! h264parse ! rtspclientsink location=%s protocols=tcp", url);
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
        g_signal_connect (appsrcElement, "need-data", (GCallback) need_data, self.ctx);
    } else {
        NSLog(@"Failed to retrieve the appsrc element.");
    }

    // Add a bus to the pipeline
    GstBus *bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_call, self.ctx);
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

    g_main_context_unref(self.ctx->mainContext);
    self.ctx->mainContext = NULL;

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
    
    
    GstClockTime timestamp, duration;

    get_sample_buffer(self.ctx, sampleBuffer, &timestamp, &duration);
    
    if (timestamp == GST_CLOCK_TIME_NONE) {
        NSLog(@"Received nil timestamp.");
        return;
    }

    
    BufferItem *item = [[BufferItem alloc] initWithSampleBuffer:sampleBuffer timestamp:timestamp duration:duration];
    if(item != nil) {
        [self.ctx->queue insert:item];
    }
}

@end
