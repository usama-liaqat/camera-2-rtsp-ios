//
//  CameraPublish.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 07/12/2024.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#ifndef CameraPublish_h
#define CameraPublish_h
#include <gst/gst.h>
#include <gst/app/app.h>
#include <gst/rtsp/rtsp.h>

#include "Types.h"

typedef struct {
    GstElement * _Nonnull pipeline;
    GstElement * _Nonnull appsrc;
    GMainContext * _Nonnull mainContext;
} PipelineContext;

NS_ASSUME_NONNULL_BEGIN

@interface CameraPublish : NSObject
@property (nonatomic) GMainLoop *mainLoop;
@property (nonatomic) PipelineContext *pipelineContext;


- (void)start:(NSString*)rtsp withCallback:(StatusCallback)live_status;
- (void)run:(NSString*)rtsp withCallback:(StatusCallback)live_status;
- (void)stop;
- (void)addBuffer:(CMSampleBufferRef)sampleBuffer;
- (NSData *)sampleBufferToData:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END

#endif /* CameraPublish_h */
