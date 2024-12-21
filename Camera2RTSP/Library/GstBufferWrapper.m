//
//  GstBufferWrapper.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#import "GstBufferWrapper.h"


@implementation GstBufferWrapper
- (instancetype)initWithBuffer:(GstBuffer *)buffer {
    self = [super init];
    if (self) {
        _data = gst_buffer_copy(buffer);
    }
    return self;
}

- (void)dealloc {
    if (self.data) {
        gst_buffer_unref(self.data);
    }
}
@end
