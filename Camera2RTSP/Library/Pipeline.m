//
//  Pipeline.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 20/12/2024.
//

#import "Pipeline.h"

// ######################################## PRIMARY ########################################

static gboolean primary_bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
    PipelineContext *ctx = (PipelineContext *)data;
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"BUS -- PRIMARY -- Message received: %s", message_type_name);
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_PROGRESS:
            NSLog(@"BUS -- PRIMARY -- Progress message received.");
            break;
        case GST_MESSAGE_BUFFERING:
            NSLog(@"BUS -- PRIMARY -- Buffering message received.");
            break;
        case GST_MESSAGE_ERROR: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_error(msg, &err, &debug_info);
            NSLog(@"BUS -- PRIMARY -- Error received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- PRIMARY -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_WARNING: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_warning(msg, &err, &debug_info);
            NSLog(@"BUS -- PRIMARY -- Warning received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- PRIMARY -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_EOS: {
            NSLog(@"BUS -- PRIMARY -- End-of-Stream reached.");
            break;
        }
        case GST_MESSAGE_STATE_CHANGED: {
            GstState old_state, new_state, pending_state;
            gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
            ctx->primary->state = new_state;
            NSLog(@"BUS -- PRIMARY -- Pipeline state changed from %s to %s.",
                  gst_element_state_get_name(old_state),
                  gst_element_state_get_name(new_state));
            break;
        }
        default:
            break;
    }
    return TRUE;
}


static GstFlowReturn primary_need_data (GstElement * appsrc, guint unused, PipelineContext *ctx)
{
    if(!ctx) return GST_FLOW_ERROR;
    
    BufferItem *buffer = [ctx->primary->queue dequeue];
//    NSLog(@"NEED_DATA  ---  buffer -> %@", buffer);

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
            @"Timestamp" : @(ctx->primary->timestamp),
        };

//        NSLog(@"NEED_DATA --- PRIMARY  ---  %@", logDict);
        
        if (width != ctx->primary->width || height != ctx->primary->height) {
            ctx->primary->width = width;
            ctx->primary->height = height;
//            NSLog(@"NEED_DATA --- PRIMARY  ---  Different Height.");
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
//            NSLog(@"NEED_DATA --- PRIMARY  ---  Error: imageBuffer is NULL.");
            return GST_FLOW_ERROR;
        }
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
        if (bufferSize == 0) {
//            g_printerr("NEED_DATA --- PRIMARY  ---  Error: Data size is zero, invalid buffer\n");
            return GST_FLOW_ERROR;
        }
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        GstBuffer *gstBuffer = gst_buffer_new_allocate(NULL, bufferSize, NULL);

        GstMapInfo map;
        if (gst_buffer_map(gstBuffer, &map, GST_MAP_WRITE)) {
            memcpy(map.data, baseAddress, bufferSize);
            gst_buffer_unmap(gstBuffer, &map);
        } else {
//            NSLog(@"NEED_DATA --- PRIMARY  ---  Failed to map GstBuffer.");
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            gst_buffer_unref(gstBuffer); // Ensure buffer is unreferenced on failure
            return GST_FLOW_ERROR;
        }
        
        GST_BUFFER_PTS (gstBuffer) = ctx->primary->timestamp;
        GST_BUFFER_DURATION (gstBuffer) = gst_util_uint64_scale_int (1, GST_SECOND, 30);
        ctx->primary->timestamp += GST_BUFFER_DURATION (gstBuffer);
        
        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), gstBuffer);
        NSLog(@"NEED_DATA --- PRIMARY  ---  pushing buffer to appsrc: %s", gst_flow_get_name(ret));
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return ret;
    } else {
//        NSLog(@"NEED_DATA --- PRIMARY  ---  No data in buffer queue.");
    }
    
//    NSLog(@"NEED_DATA --- PRIMARY  ---  GST_FLOW_ERROR Last");



    
//    return GST_FLOW_ERROR;
    
    return GST_FLOW_OK;
}


static GstFlowReturn dispatch_buffer (GstBuffer *buffer, GstElement *appsrc) {
    GstFlowReturn ret;
    g_signal_emit_by_name (appsrc, "push-buffer", buffer, &ret);
    NSLog(@"NEW_SAMPLE  --- BUFFER pushing buffer to appsrc: %s", gst_flow_get_name(ret));

    return ret;
}

static GstFlowReturn dispatch_appsink_sample (GstSample *sample, PipelineContext *ctx) {
    GstBuffer *buffer = gst_sample_get_buffer (sample);
//    GstSegment *seg = gst_sample_get_segment (sample);
//    GstClockTime pts, dts, timestamp, duration;
    
    if (buffer) {
//        pts = GST_BUFFER_PTS (buffer);
//        if (GST_CLOCK_TIME_IS_VALID (pts))
//            pts = gst_segment_to_running_time (seg, GST_FORMAT_TIME, pts);
//        
//        dts = GST_BUFFER_DTS (buffer);
//        if (GST_CLOCK_TIME_IS_VALID (dts))
//            dts = gst_segment_to_running_time (seg, GST_FORMAT_TIME, dts);
//        
//        timestamp = GST_BUFFER_TIMESTAMP (buffer);
//        if (GST_CLOCK_TIME_IS_VALID (timestamp))
//            timestamp = gst_segment_to_running_time (seg, GST_FORMAT_TIME, timestamp);
//        
//        duration = GST_BUFFER_DURATION(buffer);
//        
//        NSDictionary *logDict = @{
//            @"pts" : @(pts),
//            @"dts" : @(dts),
//            @"timestamp" : @(timestamp),
//            @"duration" : @(duration),
//        };
//
//        NSLog(@"NEW_SAMPLE  ---  %@", logDict);
//        
//        GST_BUFFER_PTS (buffer) = pts;
//        GST_BUFFER_DTS (buffer) = dts;
//        GST_BUFFER_TIMESTAMP (buffer) = timestamp;
//        GST_BUFFER_DURATION (buffer) = duration;
        
//        if(ctx->rtsp->state == GST_STATE_PLAYING && ctx->rtsp->appsrc){
//            dispatch_buffer(buffer, ctx->rtsp->appsrc);
//        }
        
        GstBufferWrapper *item = [[GstBufferWrapper alloc] initWithBuffer:buffer];
        if(ctx->rtsp->enable){
            [ctx->rtsp->queue enqueue:item];
        }
        
        if(ctx->hls->enable){
            [ctx->hls->queue enqueue:item];
        }
    }
    /* we don't need the appsink sample anymore */
//    gst_buffer_unref(buffer);
    
    return GST_FLOW_OK;
}

static GstFlowReturn new_sample (GstElement *sink, PipelineContext *ctx) {
    NSLog(@"NEW_SAMPLE -- CALLBACK");
    if(!ctx) return GST_FLOW_EOS;
    GstSample *sample;
    sample = gst_app_sink_pull_sample (GST_APP_SINK (ctx->primary->appsink));
    if (sample) {
        NSLog(@"NEW_SAMPLE -- RECEIVED");
        GstFlowReturn status = dispatch_appsink_sample(sample, ctx);
        gst_sample_unref (sample);
        return status;;
    }
    return GST_FLOW_OK;
}




// ######################################## HLS ########################################

static gboolean hls_bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
    PipelineContext *ctx = (PipelineContext *)data;
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"BUS -- HLS -- Message received: %s", message_type_name);
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_PROGRESS:
            NSLog(@"BUS -- HLS -- Progress message received.");
            break;
        case GST_MESSAGE_BUFFERING:
            NSLog(@"BUS -- HLS -- Buffering message received.");
            break;
        case GST_MESSAGE_ERROR: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_error(msg, &err, &debug_info);
            NSLog(@"BUS -- HLS -- Error received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- HLS -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_WARNING: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_warning(msg, &err, &debug_info);
            NSLog(@"BUS -- HLS -- Warning received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- HLS -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_EOS: {
            NSLog(@"BUS -- HLS -- End-of-Stream reached.");
            break;
        }
        case GST_MESSAGE_STATE_CHANGED: {
            GstState old_state, new_state, pending_state;
            gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
            ctx->hls->state = new_state;
            NSLog(@"BUS -- HLS -- Pipeline state changed from %s to %s.",
                  gst_element_state_get_name(old_state),
                  gst_element_state_get_name(new_state));
            break;
        }
        default:
            break;
    }
    return TRUE;
}

static GstFlowReturn hls_need_data (GstElement * appsrc, guint unused, PipelineContext *ctx)
{
    if(!ctx) return GST_FLOW_ERROR;
    
    
    return GST_FLOW_OK;
}





// ######################################## RTSP ########################################

static gboolean rtsp_bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
    PipelineContext *ctx = (PipelineContext *)data;
    const gchar *message_type_name = gst_message_type_get_name(GST_MESSAGE_TYPE(msg));
    NSLog(@"BUS -- RTSP -- Message received: %s", message_type_name);
    switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_PROGRESS:
            NSLog(@"BUS -- RTSP -- Progress message received.");
            break;
        case GST_MESSAGE_BUFFERING:
            NSLog(@"BUS -- RTSP -- Buffering message received.");
            break;
        case GST_MESSAGE_ERROR: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_error(msg, &err, &debug_info);
            NSLog(@"BUS -- RTSP -- Error received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- RTSP -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_WARNING: {
            GError *err;
            gchar *debug_info;
            gst_message_parse_warning(msg, &err, &debug_info);
            NSLog(@"BUS -- RTSP -- Warning received: %s", err->message);
            if (debug_info) {
                NSLog(@"BUS -- RTSP -- Debug Info: %s", debug_info);
            }
            g_error_free(err);
            g_free(debug_info);
            break;
        }
        case GST_MESSAGE_EOS: {
            NSLog(@"BUS -- RTSP -- End-of-Stream reached.");
            break;
        }
        case GST_MESSAGE_STATE_CHANGED: {
            GstState old_state, new_state, pending_state;
            gst_message_parse_state_changed(msg, &old_state, &new_state, &pending_state);
            ctx->rtsp->state = new_state;
            NSLog(@"BUS -- RTSP -- Pipeline state changed from %s to %s.",
                  gst_element_state_get_name(old_state),
                  gst_element_state_get_name(new_state));
            break;
        }
        default:
            break;
    }
    return TRUE;
}

static GstFlowReturn rtsp_need_data (GstElement * appsrc, guint unused, PipelineContext *ctx)
{
    if(!ctx) return GST_FLOW_ERROR;
    NSLog(@"NEED_DATA  ---  RTSP  ---  buffer");
    GstBufferWrapper *buffer = [ctx->rtsp->queue dequeue];
    
    if (buffer != nil && buffer.data != nil) {
        
//        GST_BUFFER_PTS (buffer.data) = ctx->rtsp->timestamp;
//        GST_BUFFER_DURATION (buffer.data) = GST_BUFFER_DURATION (buffer.data);
//        ctx->rtsp->timestamp += GST_BUFFER_DURATION (buffer.data);
        
        NSLog(@"NEED_DATA  ---  RTSP  --- Data--- %@", buffer);
        GstFlowReturn ret = dispatch_buffer(buffer.data, appsrc);
//        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), buffer.data);
        NSLog(@"NEED_DATA  ---  RTSP  ---  pushing buffer to appsrc: %s", gst_flow_get_name(ret));
        return ret;
    }


    
    return GST_FLOW_OK;
}


static PipelineContext * ctx_create (void) {
    PipelineContext *ctx = (PipelineContext *)malloc(sizeof(PipelineContext));
    if (!ctx) return NULL; // Handle memory allocation failure
    
    ctx->primary = (PrimaryPipeline *)malloc(sizeof(PrimaryPipeline));
    if (!ctx->primary) {
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    
    ctx->primary->queue = [[Queue alloc] initWithName:@"PRIMARY"];
    ctx->primary->state = GST_STATE_NULL;
    ctx->primary->pipeline = NULL;
    ctx->primary->appsrc = NULL;
    ctx->primary->appsink = NULL;
    ctx->primary->width = 0;
    ctx->primary->height = 0;
    ctx->primary->timestamp = 0;

    ctx->rtsp = (RTSPPipeline *)malloc(sizeof(RTSPPipeline));
    if (!ctx->rtsp) {
        free(ctx->primary);
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    ctx->rtsp->queue = [[Queue alloc] initWithName:@"RTSP"];
    ctx->rtsp->enable = NO;
    ctx->rtsp->state = GST_STATE_NULL;
    ctx->rtsp->pipeline = NULL;
    ctx->rtsp->appsrc = NULL;
    ctx->rtsp->timestamp = 0;

    
    ctx->hls = (HLSPipeline *)malloc(sizeof(HLSPipeline));
    if (!ctx->hls) {
        free(ctx->rtsp);
        free(ctx->primary);
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    ctx->hls->queue = [[Queue alloc] initWithName:@"HLS"];
    ctx->hls->enable = NO;
    ctx->hls->state = GST_STATE_NULL;
    ctx->hls->pipeline = NULL;
    ctx->hls->appsrc = NULL;
    ctx->hls->timestamp = 0;

    return ctx;
}

static void ctx_free (PipelineContext * ctx)
{
    if (!ctx) return;
    if(ctx->mainLoop) {
        g_main_loop_unref(ctx->mainLoop);
        ctx->mainLoop = NULL;
    }
    if (ctx->primary) {
        if (ctx->primary->pipeline) {
            if(GST_OBJECT_REFCOUNT(ctx->primary->pipeline)){
                gst_object_unref(ctx->primary->pipeline);
            }
        }
        if (ctx->primary->appsrc) {
            if(GST_OBJECT_REFCOUNT(ctx->primary->appsrc)){
                gst_object_unref(ctx->primary->appsrc);
            }
        }
        if (ctx->primary->appsink) {
            if(GST_OBJECT_REFCOUNT(ctx->primary->appsink)){
                gst_object_unref(ctx->primary->appsink);
            }
        }
        free(ctx->primary);
        ctx->primary = NULL;
    }
    
    if (ctx->hls) {
        if (ctx->hls->pipeline) {
            if(GST_OBJECT_REFCOUNT(ctx->hls->pipeline)){
                gst_object_unref(ctx->hls->pipeline);
            }
        }
        if (ctx->hls->appsrc) {
            if(GST_OBJECT_REFCOUNT(ctx->hls->appsrc)){
                gst_object_unref(ctx->hls->appsrc);
            }
        }
        free(ctx->hls);
        ctx->hls = NULL;
    }
    
    if (ctx->rtsp) {
        if (ctx->rtsp->pipeline) {
            if(GST_OBJECT_REFCOUNT(ctx->rtsp->pipeline)){
                gst_object_unref(ctx->rtsp->pipeline);
            }
        }
        if (ctx->rtsp->appsrc) {
            if(GST_OBJECT_REFCOUNT(ctx->rtsp->appsrc)){
                gst_object_unref(ctx->rtsp->appsrc);
            }
        }
        free(ctx->rtsp);
        ctx->rtsp = NULL;
    }
    free(ctx);
}



@implementation Pipeline

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSLock alloc] init];
        gst_init(nil, nil);
        gst_debug_set_default_threshold(GST_LEVEL_FIXME);
//        gst_debug_set_threshold_for_name("rtspclientsink", GST_LEVEL_DEBUG);
//        gst_debug_set_threshold_for_name("appsrc", GST_LEVEL_DEBUG);
        self.isRunning = NO;
        self.ctx = nil;

    }
    return self;
}

- (void)startHLS {
    if(!self.ctx) {
        return;
    }
    HLSPipeline *hlsCtx = self.ctx->hls;
    
}

- (BOOL)startRTSP:(NSString*)rtsp {
    if(!self.ctx) {
        return NO;
    }
    gchar *url = (gchar *)[rtsp UTF8String];
    RTSPPipeline *rtspCtx = self.ctx->rtsp;
    gchar *pipeline_description = g_strdup_printf("appsrc name=media-source ! "
                                                  "queue ! h264parse config-interval=-1 ! "
                                                  "rtspclientsink location=%s protocols=tcp latency=1 debug=true", url);
    g_print("pipeline -> rtsp -> %s\n", pipeline_description);
    
    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_description, &error);
    if (!pipeline) {
        NSLog(@"Failed to create GStreamer pipeline: %s", error->message);
        return NO;
    }
    
    rtspCtx->enable = YES;
    
    GstElement *appsrc = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "media-source");
    if (appsrc) {
        rtspCtx->appsrc = appsrc;
        GstCaps *caps = gst_caps_new_simple ("video/x-h264",
                                    "stream-format", G_TYPE_STRING, "byte-stream",
                                    "alignment", G_TYPE_STRING, "nal",
                                    NULL);
        g_object_set(appsrc,
             "caps", caps,
             "format", GST_FORMAT_TIME,
             "do-timestamp", (gboolean)true,
             "is-live", (gboolean)true,
             NULL
         );
        g_signal_connect (appsrc, "need-data", (GCallback) rtsp_need_data, self.ctx);
        gst_caps_unref (caps);
    } else {
        NSLog(@"Failed to retrieve the appsrc element.");
    }
    
    // Add a bus to the pipeline
    GstBus *bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
    rtspCtx->bus_watch_id =gst_bus_add_watch(bus, rtsp_bus_call, self.ctx);
    gst_object_unref(bus);
    
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);
    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        return NO;
    }

    rtspCtx->pipeline = pipeline;
    
    return YES;
}

- (BOOL)startPrimary {
    if(!self.ctx) {
        return NO;
    }
    PrimaryPipeline *primaryCtx = self.ctx->primary;
    
    gchar *pipeline_description = g_strdup_printf("appsrc name=video-source ! "
                                                  "queue ! videoflip method=clockwise ! "
                                                  "videorate skip-to-first=true ! video/x-raw,framerate=30/1 ! "
                                                  "videoscale ! video/x-raw,width=1080,height=1920 ! "
                                                  "queue ! videoconvert ! video/x-raw,format=I420 ! "
                                                  "vtenc_h264 bitrate=5000 allow-frame-reordering=false realtime=true ! "
                                                  "queue ! h264parse config-interval=-1 ! "
                                                  "appsink name=video-sink");
    g_print("pipeline -> primary -> %s\n", pipeline_description);

    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_description, &error);
    if (!pipeline) {
        NSLog(@"Failed to create GStreamer pipeline: %s", error->message);
        return NO;
    }
    
    GstElement *appsrc = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "video-source");
    if (appsrc) {
        primaryCtx->appsrc = appsrc;
        g_object_set(appsrc,
             "format", GST_FORMAT_TIME,
             "do-timestamp", (gboolean)true,
             "is-live", (gboolean)true,
             NULL
         );
        g_signal_connect (appsrc, "need-data", (GCallback) primary_need_data, self.ctx);
    } else {
        NSLog(@"Failed to retrieve the appsrc element.");
    }
    
    GstElement *appsink = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "video-sink");
    if (appsink) {
        primaryCtx->appsink = appsink;
        GstCaps *caps = gst_caps_new_simple ("video/x-h264",
                                    "stream-format", G_TYPE_STRING, "byte-stream",
                                    "alignment", G_TYPE_STRING, "nal",
                                    NULL);
        g_object_set (appsink,
//                      "sync", FALSE,
                      "caps",caps,
                      "drop", TRUE,
                      "emit-signals", TRUE,
//                      "max-buffers", 100,
                      NULL);
        g_signal_connect (appsink, "new-sample", G_CALLBACK (new_sample), self.ctx);
        gst_caps_unref (caps);

    } else {
        NSLog(@"Failed to retrieve the appsink element.");
    }

    // Add a bus to the pipeline
    GstBus *bus = gst_pipeline_get_bus(GST_PIPELINE(pipeline));
    primaryCtx->bus_watch_id =gst_bus_add_watch(bus, primary_bus_call, self.ctx);
    gst_object_unref(bus);

    // Set the pipeline to playing state
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);

    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        return NO;
    }
    



    primaryCtx->pipeline = pipeline;
    
    return YES;

    
}

- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status {
    [self.lock lock];
    if (self.isRunning) {
        NSLog(@"Pipeline is already running. Aborting start.");
        live_status(true);
        [self.lock unlock];
        return;
    }
    self.ctx = ctx_create();
    
    
    self.ctx->mainLoop = g_main_loop_new(NULL, FALSE);
    
    BOOL primaryStatus = [self startPrimary];
    if(!primaryStatus) {
        live_status(false);
        _isRunning = NO;
        ctx_free(self.ctx);
        self.ctx = nil;
        return;
    }
    
    BOOL rtspStatus = [self startRTSP:rtsp];
    if(!rtspStatus) {
        live_status(false);
        _isRunning = NO;
        ctx_free(self.ctx);
        self.ctx = nil;
        return;
    }

    
    live_status(true);
    _isRunning = YES;
    [self.lock unlock];
    g_main_loop_run(self.ctx->mainLoop);
    live_status(false);
    _isRunning = NO;
    if(self.ctx->primary->bus_watch_id) {
        g_source_remove (self.ctx->primary->bus_watch_id);
    }

    ctx_free(self.ctx);
    self.ctx = nil;
}


- (void)stop {
    [self.lock lock];
    if(self.isRunning && self.ctx->mainLoop != NULL){
        g_main_loop_quit(self.ctx->mainLoop);
    }
    [self.lock unlock];
}

- (void)addBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.ctx) {
        NSLog(@"Context is Not Defined");
        return;
    }
    if (!sampleBuffer) {
        NSLog(@"Received nil sampleBuffer.");
        return;
    }

    
    BufferItem *item = [[BufferItem alloc] initWithSampleBuffer:sampleBuffer];
    if(item != nil) {
        [self.ctx->primary->queue enqueue:item];
    }
}

@end
