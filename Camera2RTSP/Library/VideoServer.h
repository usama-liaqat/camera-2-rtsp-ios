//
//  VideoServer.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 18/12/2024.
//

#ifndef VideoServer_h
#define VideoServer_h
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


#include <gst/gst.h>
#include <gst/app/app.h>
#include <gst/rtsp-server/rtsp-server.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


#include "Types.h"
#import "BufferQueue.h"
#import "VideoPublisher.h"


typedef struct {
    gchar * _Nullable rtsp_url;
    MessageCallback _Nullable message_callback;
    GstElement * _Nonnull appsrc;
    BufferQueue * _Nonnull queue; // Add mutable array
    CMClockRef _Nonnull inputClock;
} GlobalContext;

typedef struct {
    int width;
    int height;
    int offset;
} VideoInfo;

typedef struct {
    GstElement * _Nonnull appsrc;
    GlobalContext * _Nonnull globalCtx;
    VideoInfo * _Nonnull videoInfo;
    int frames;
    gboolean white;
    GstClockTime timestamp;
} StreamContext;

static GstFlowReturn server_need_data(GstElement * _Nonnull appsrc, guint unused, StreamContext * _Nonnull ctx);
static void media_configure (GstRTSPMediaFactory * _Nonnull factory, GstRTSPMedia * _Nonnull media, GlobalContext * _Nonnull ctx);
static void ctx_free(StreamContext * _Nonnull ctx);


NS_ASSUME_NONNULL_BEGIN

typedef void (^StatusCallback)(BOOL status);


@interface VideoServer : NSObject
@property (nonatomic) GstRTSPServer *server;
@property (nonatomic) GMainLoop *mainLoop;
@property (nonatomic) GlobalContext *globalContext;
@property (nonatomic, nullable) VideoPublisher *videoPublisher;


- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status;
- (void)stop;
- (void)addBuffer:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
#endif /* VideoServer_h */
