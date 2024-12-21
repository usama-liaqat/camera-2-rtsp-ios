//
//  VideoServer.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 18/12/2024.
//

#import "VideoServer.h"

static GstFlowReturn server_need_data (GstElement * appsrc, guint unused, StreamContext *ctx) {

    
    BufferItem *buffer = [ctx->globalCtx->queue dequeue];
    NSLog(@"NEED_DATA  ---  buffer -> %@", buffer);
    
    if (buffer != nil) {
        CMSampleBufferRef sampleBuffer = buffer.sampleBuffer;
        int width =  buffer.width;
        int height = buffer.height;
        NSString *type = buffer.type;
        
        const char *format = [type UTF8String];
        
        NSDictionary *logDict = @{
            @"Width" : @(width),
            @"Height" : @(height),
            @"Type" : type,
        };
        NSLog(@"NEED_DATA  ---  %@", logDict);

        
        if (width != ctx->videoInfo->width || height != ctx->videoInfo->height) {
            ctx->videoInfo->width = width;
            ctx->videoInfo->height = height;
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
        
        GST_BUFFER_PTS (gstBuffer) = ctx->timestamp;
        GST_BUFFER_DURATION (gstBuffer) = gst_util_uint64_scale_int (1, GST_SECOND, 30);
        ctx->timestamp += GST_BUFFER_DURATION (gstBuffer);
        
        GstFlowReturn ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), gstBuffer);
        NSLog(@"NEED_DATA  ---  pushing buffer to appsrc: %s", gst_flow_get_name(ret));
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        return ret;
    } else {
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
    }


    
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
    ctx->globalCtx = context;

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
    _globalContext->queue = [[BufferQueue alloc] init];

    _globalContext->inputClock = CMClockGetHostTimeClock();

    return self;
}

- (void)start:(NSString*)output_rtsp withCallback:(StatusCallback)live_status {
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
    
    launch_string = g_strdup_printf("( "
                                    "appsrc name=video-src ! "
                                    "videoflip method=clockwise ! "
                                    "videorate ! video/x-raw,framerate=30/1 ! "
                                    "videoscale ! video/x-raw,width=1080,height=1920 ! "
                                    "videoconvert ! video/x-raw,format=I420 ! "
                                    "vtenc_h264 bitrate=5000 allow-frame-reordering=false realtime=true ! "
                                    "rtph264pay name=pay0 pt=96 "
                                    ")");
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
    NSString *local_rtsp_url = [NSString stringWithUTF8String:rtsp_url];
    _videoPublisher = [[VideoPublisher alloc] initWithSourceandOutputURI:local_rtsp_url outputURI:output_rtsp];
    [[self videoPublisher] start];
    _mainLoop = g_main_loop_new (mainContext, FALSE);
    g_main_loop_run (_mainLoop);
    live_status(false);
    [[self videoPublisher] stop];
    
    
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

    
    BufferItem *item = [[BufferItem alloc] initWithSampleBuffer:sampleBuffer];
    if(item != nil) {
        [self.globalContext->queue enqueue:item];
    }
}
@end
