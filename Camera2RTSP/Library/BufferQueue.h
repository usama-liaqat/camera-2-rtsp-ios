//
//  BufferQueue.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#ifndef BufferQueue_h
#define BufferQueue_h
#import <Foundation/Foundation.h>

#import "BufferItem.h"

typedef enum _QueueState {
  NO_BUFFERS = 1,
  HAS_BUFFER_OR_STOP_REQUEST,
} QueueState;

NS_ASSUME_NONNULL_BEGIN

@interface BufferQueue : NSObject
@property (nonatomic) NSMutableArray<BufferItem *> *queue;
@property (nonatomic) NSConditionLock *lock;
@property (nonatomic) int index;


- (void)insert:(BufferItem*)buffer;
- (BufferItem *)pop;
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

#endif /* BufferQueue_h */
