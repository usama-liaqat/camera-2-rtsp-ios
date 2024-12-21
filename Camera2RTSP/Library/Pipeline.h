//
//  Pipeline.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 20/12/2024.
//

#ifndef Pipeline_h
#define Pipeline_h
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#include <gst/gst.h>
#include <gst/app/app.h>
#include <gst/rtsp/rtsp.h>

#include "Types.h"
#import "BufferQueue.h"



typedef struct {
    GstElement * _Nonnull pipeline;
    GstElement * _Nonnull appsrc;
    GstElement * _Nonnull appsink;
    GstState state;
    guint bus_watch_id;
    int width;
    int height;
    GstClockTime timestamp;
    BufferQueue * _Nonnull queue;
} PrimaryPipeline;

typedef struct {
    GstElement * _Nonnull pipeline;
    GstElement * _Nonnull appsrc;
    GstState state;
    guint bus_watch_id;
} HLSPipeline;

typedef struct {
    GstElement * _Nonnull pipeline;
    GstElement * _Nonnull appsrc;
    GstState state;
    guint bus_watch_id;
} RTSPPipeline;

typedef struct {
    PrimaryPipeline * _Nonnull primary;
    HLSPipeline * _Nonnull hls;
    RTSPPipeline * _Nonnull rtsp;
    GMainLoop * _Nonnull mainLoop;
} PipelineContext;

static gboolean primary_bus_call(GstBus * _Nonnull bus, GstMessage * _Nonnull msg, gpointer _Nonnull data);
static gboolean hls_bus_call(GstBus * _Nonnull bus, GstMessage * _Nonnull msg, gpointer _Nonnull data);
static gboolean rtsp_bus_call(GstBus * _Nonnull bus, GstMessage * _Nonnull msg, gpointer _Nonnull data);

static GstFlowReturn dispatch_buffer (GstBuffer * _Nonnull buffer, GstElement * _Nonnull appsrc);
static GstFlowReturn dispatch_appsink_sample (GstSample * _Nonnull sample, PipelineContext * _Nonnull ctx);
static GstFlowReturn new_sample (GstElement * _Nonnull sink, PipelineContext * _Nonnull ctx);
static GstFlowReturn need_data(GstElement * _Nonnull appsrc, guint unused, PipelineContext * _Nonnull ctx);


static PipelineContext * _Nullable ctx_create (void);
static void ctx_free (PipelineContext * _Nonnull ctx);

NS_ASSUME_NONNULL_BEGIN

@interface Pipeline : NSObject
@property (nonatomic, nullable) PipelineContext *ctx;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL isRunning;
- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status;
- (void)stop;
- (void)addBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END


#endif /* Pipeline_h */
