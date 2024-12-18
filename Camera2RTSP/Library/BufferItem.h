//
//  BufferItem.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#ifndef BufferItem_h
#define BufferItem_h
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#include <gst/gst.h>

NS_ASSUME_NONNULL_BEGIN

@interface BufferItem : NSObject


@property (nonatomic) CMSampleBufferRef sampleBuffer;

@property (nonatomic) int width;
@property (nonatomic) int height;

@property (nonatomic) FourCharCode mediaType;
@property (nonatomic) NSString *type;
@property (nonatomic) int index;


- (instancetype) initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

#endif /* BufferItem_h */
