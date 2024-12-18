//
//  CameraPublisher.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//



#ifndef CameraPublisher_h
#define CameraPublisher_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#include <gst/gst.h>
#include <gst/app/app.h>
#include <gst/rtsp/rtsp.h>

#include "Types.h"
#import "BufferQueue.h"


typedef struct {
    GMainLoop * _Nonnull mainLoop;
    GstElement * _Nonnull pipeline;
    GstElement * _Nonnull appsrc;
    int width;
    int height;
    int offset;
    BufferQueue * _Nonnull queue; // Add mutable array
    CMClockRef _Nonnull inputClock;
    GstClockTime timestamp;
} PublisherContext;

static GstFlowReturn need_data(GstElement * _Nonnull appsrc, guint unused, PublisherContext * _Nonnull ctx);


NS_ASSUME_NONNULL_BEGIN

@interface CameraPublisher : NSObject
@property (nonatomic) PublisherContext *ctx;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL isRunning;


- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status;
- (void)stop;
- (void)addBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END

#endif /* CameraPublish_h */
