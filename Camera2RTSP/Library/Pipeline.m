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
//    PipelineContext *ctx = (PipelineContext *)data;
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


static GstFlowReturn need_data (GstElement * appsrc, guint unused, PipelineContext *ctx)
{
    if(!ctx) return GST_FLOW_ERROR;
    
    return GST_FLOW_OK;
}

static GstFlowReturn new_sample (GstElement *sink, PipelineContext *ctx) {
    NSLog(@"NEW SAMPLE -- CALLBACK");
    if(!ctx) return GST_FLOW_EOS;
    GstSample *sample;
    sample = gst_app_sink_pull_sample (GST_APP_SINK (ctx->primary->appsink));
    if (sample) {
        NSLog(@"NEW SAMPLE -- RECEIVED");
    }
    return GST_FLOW_OK;
}




// ######################################## HLS ########################################

static gboolean hls_bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
    //    PipelineContext *ctx = (PipelineContext *)data;
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





// ######################################## RTSP ########################################

static gboolean rtsp_bus_call(GstBus *bus, GstMessage *msg, gpointer data)
{
    //    PipelineContext *ctx = (PipelineContext *)data;
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


static PipelineContext * ctx_create () {
    PipelineContext *ctx = (PipelineContext *)malloc(sizeof(PipelineContext));
    if (!ctx) return NULL; // Handle memory allocation failure
    
    ctx->primary = (PrimaryPipeline *)malloc(sizeof(PrimaryPipeline));
    if (!ctx->primary) {
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    
    ctx->primary->queue = [[BufferQueue alloc] init];
    ctx->primary->pipeline = NULL;
    ctx->primary->appsrc = NULL;
    ctx->primary->appsink = NULL;
    ctx->primary->width = 0;
    ctx->primary->height = 0;

    ctx->rtsp = (RTSPPipeline *)malloc(sizeof(RTSPPipeline));
    if (!ctx->rtsp) {
        free(ctx->primary);
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    ctx->rtsp->pipeline = NULL;
    ctx->rtsp->appsrc = NULL;

    
    ctx->hls = (HLSPipeline *)malloc(sizeof(HLSPipeline));
    if (!ctx->hls) {
        free(ctx->rtsp);
        free(ctx->primary);
        free(ctx);
        return NULL; // Handle memory allocation failure
    }
    ctx->hls->pipeline = NULL;
    ctx->hls->appsrc = NULL;

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
        self.isRunning = NO;
        self.ctx = nil;

    }
    return self;
}

- (void)startHLS {
    
}

- (void)startRTSP:(NSString*)rtsp {
    gchar *url = (gchar *)[rtsp UTF8String];
}

- (void)startPrimary {
    
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
        ctx_free(self.ctx);
        [self.lock unlock];
        return;
    }
    
    GstElement *appsrcElement = gst_bin_get_by_name_recurse_up(GST_BIN (pipeline), "source");
    if (appsrcElement) {
        self.ctx->primary->appsrc = appsrcElement;
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
    guint bus_watch_id =gst_bus_add_watch(bus, primary_bus_call, self.ctx);
    gst_object_unref(bus);

    // Set the pipeline to playing state
    GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
    NSLog(@"set the pipeline to PLAYING state. %d", ret);

    if (ret == GST_STATE_CHANGE_FAILURE) {
        NSLog(@"Failed to set the pipeline to PLAYING state.");
        gst_object_unref(self.ctx->primary->pipeline);
        live_status(false);
        ctx_free(self.ctx);
        [self.lock unlock];
        return;
    }
    



    self.ctx->primary->pipeline = pipeline;
    live_status(true);
    _isRunning = YES;
    [self.lock unlock];
    g_main_loop_run(self.ctx->mainLoop);
    live_status(false);
    _isRunning = NO;
    g_source_remove (bus_watch_id);

    ctx_free(self.ctx);
    self.ctx = nil;
}


- (void)stop {
}

- (void)addBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

@end
