//
//  GstBufferWrapper.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#ifndef GstBufferWrapper_h
#define GstBufferWrapper_h
#import <Foundation/Foundation.h>
#include <gst/gst.h>

NS_ASSUME_NONNULL_BEGIN
@interface GstBufferWrapper : NSObject
@property (nonatomic, assign) GstBuffer *data;
- (instancetype)initWithBuffer:(GstBuffer *)buffer;
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END


#endif /* GstBufferWrapper_h */
