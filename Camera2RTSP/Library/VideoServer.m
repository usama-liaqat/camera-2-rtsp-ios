//
//  VideoServer.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 18/12/2024.
//

#import "VideoServer.h"

static void server_get_sample_buffer(GlobalContext *ctx, CMSampleBufferRef sbuf,GstClockTime *outTimestamp,GstClockTime *outDuration ) {
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

static GstFlowReturn server_need_data (GstElement * appsrc, guint unused, StreamContext *ctx) {
    GstBuffer *buffer;
    guint size;
    GstFlowReturn ret;

    size = ctx->videoInfo->width * ctx->videoInfo->height * 2;

    buffer = gst_buffer_new_allocate (NULL, size, NULL);

    /* this makes the image black/white */
    gst_buffer_memset (buffer, 0, ctx->white ? 0xff : 0x0, size);

    ctx->white = !ctx->white;

    /* increment the timestamp every 1/2 second */
    GST_BUFFER_PTS (buffer) = ctx->timestamp;
    GST_BUFFER_DURATION (buffer) = gst_util_uint64_scale_int (1, GST_SECOND, 30);
    ctx->timestamp += GST_BUFFER_DURATION (buffer);

    g_signal_emit_by_name (appsrc, "push-buffer", buffer, &ret);
    gst_buffer_unref (buffer);
    return GST_FLOW_OK;
}


static void media_configure (GstRTSPMediaFactory * factory, GstRTSPMedia * media, GlobalContext *context)
{
    g_print( "media_configure Call %s \n", context->rtsp_url );

    GstElement *element, *appsrc;
    GstCaps *caps;
    StreamContext *ctx;
    
    ctx = (StreamContext *)malloc(sizeof(StreamContext));
    ctx->videoInfo = (VideoInfo *)malloc(sizeof(VideoInfo));
    ctx->videoInfo->width = 1280;
    ctx->videoInfo->height = 720;
    ctx->white = FALSE;
    ctx->timestamp = 0;

    g_object_set_data_full (G_OBJECT (media), "rtsp-extra-data", ctx, (GDestroyNotify) ctx_free);
    element = gst_rtsp_media_get_element (media);
    caps = gst_caps_new_simple ("video/x-raw",
                                "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1,
//                                "media", G_TYPE_STRING, "video",
                                "framerate", GST_TYPE_FRACTION, 30, 1,
                                "width", G_TYPE_INT, 1280,
                                "height", G_TYPE_INT, 720,
                                "format", G_TYPE_STRING, "RGB16",
                                NULL);
    
    ctx->appsrc = appsrc = gst_bin_get_by_name_recurse_up (GST_BIN (element), "video-src");
    gst_util_set_object_arg (G_OBJECT (appsrc), "format", "time");
    g_object_set (G_OBJECT (appsrc), "caps", caps, NULL);
    g_signal_connect (appsrc, "need-data", (GCallback) server_need_data, ctx);
    
    gst_object_unref (appsrc);
    gst_caps_unref (caps);
    gst_object_unref (element);
}

static GstRTSPFilterResult client_filter (GstRTSPServer *server, GstRTSPClient *client, gpointer user_data)
{
  /* Simple filter that shuts down all clients. */
  return GST_RTSP_FILTER_REMOVE;
}

static void ctx_free (StreamContext * ctx)
{
    gst_object_unref (ctx->appsrc);
    g_free (ctx);
}

BOOL isPortAvailable(int port) {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return NO;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (connect(sockfd, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
        // Connection successful, port is in use
        close(sockfd);
        return NO;
    }

    // Connection failed, port is available
    close(sockfd);
    return YES;
}

@implementation VideoServer

- (instancetype)init {
    self = [super init];
    _globalContext = (GlobalContext *)malloc(sizeof(GlobalContext)); // Initialize the struct with default values
    _globalContext->inputClock = CMClockGetHostTimeClock();

    return self;
}

- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status {
    @autoreleasepool {
        int port = 554;
        if (isPortAvailable(port)) {
            NSLog(@"Port %d is available.", port);
        } else {
            NSLog(@"Port %d is not available.", port);
            live_status(false);
            return;
        }
    }
    
    GstRTSPMountPoints *mounts;
    GstRTSPMediaFactory *factory;
    gchar *launch_string;
    gchar *Port = "554";
    gst_init(0, nil);
    
    _server = gst_rtsp_server_new ();
    g_object_set (_server, "service", Port, NULL);
    mounts = gst_rtsp_server_get_mount_points (_server);
    
    launch_string = g_strdup_printf("( appsrc name=video-src ! videoconvert ! video/x-raw,format=I420 ! videorate ! video/x-raw,framerate=25/1  ! vtenc_h264 ! rtph264pay name=pay0 pt=96 )");
    g_print("%s\n", launch_string);
    
    factory = gst_rtsp_media_factory_new ();
    gst_rtsp_media_factory_set_launch (factory, launch_string);
    gst_rtsp_media_factory_set_shared (factory, TRUE);
    gst_rtsp_media_factory_set_enable_rtcp (factory, TRUE);
    gst_rtsp_media_factory_set_latency (factory,1);
    gst_rtsp_mount_points_add_factory (mounts, "/live", factory);
    
    gchar *rtsp_url = g_strdup_printf("rtsp://127.0.0.1:%s/live", Port);
    g_print("stream ready at %s\n", rtsp_url);
    _globalContext->rtsp_url = rtsp_url;
    
    g_signal_connect (factory, "media-configure", (GCallback) media_configure, _globalContext);

    
    GMainContext *mainContext = g_main_context_new();
    g_object_unref (mounts);
    gst_rtsp_server_attach (_server, mainContext);
    
 

    
    live_status(true);
    
    _mainLoop = g_main_loop_new (mainContext, FALSE);
    g_main_loop_run (_mainLoop);
    live_status(false);
    
    
    gst_rtsp_server_client_filter (_server, client_filter, NULL);
    gst_rtsp_thread_pool_cleanup();
    g_main_loop_unref(_mainLoop);
    g_main_context_unref(mainContext);
    g_object_unref(_server);
}


- (void)stop {
    if(_mainLoop != nil){
        g_main_loop_quit(_mainLoop);
    }
}

- (void)addBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) {
        NSLog(@"Received nil sampleBuffer.");
        return;
    }

    
    BufferItem *item = [[BufferItem alloc] initWithSampleBuffer:sampleBuffer timestamp:nil duration:nil];
    if(item != nil) {
        [self.globalContext->queue insert:item];
    }
}
@end
