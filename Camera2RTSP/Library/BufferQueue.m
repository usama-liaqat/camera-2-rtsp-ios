//
//  BufferQueue.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#import <Foundation/Foundation.h>
#import "BufferQueue.h"

#define BUFFER_QUEUE_SIZE     2


@implementation BufferQueue

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSConditionLock alloc] initWithCondition:NO_BUFFERS];
        self.queue = [[NSMutableArray alloc] initWithCapacity:BUFFER_QUEUE_SIZE];
        self.index = 0;
    }
    return self;
}

- (void)insert:(BufferItem*)buffer {
    [self.lock lock];
    buffer.index = self.index++;
    if ([self.queue count] == BUFFER_QUEUE_SIZE){
            [self.queue removeLastObject];
    }

    [self.queue insertObject:buffer atIndex:0];
    NSLog(@"INSERT --- Buffer Queue Items -> %lu -- %d", (unsigned long)self.queue.count, buffer.index);
    [self.lock unlockWithCondition:HAS_BUFFER_OR_STOP_REQUEST];
}

- (BufferItem *)pop {
    [self.lock lockWhenCondition:HAS_BUFFER_OR_STOP_REQUEST]; // Wait for data to be available
    BufferItem *buffer = nil;
    if (self.queue.count > 0) {
        // Pop the first buffer from the queue
        buffer = [self.queue lastObject];
        [self.queue removeLastObject]; // Remove the first element
    }
    
    NSLog(@"POP --- Buffer Queue Items -> %lu -- %d", (unsigned long)self.queue.count,buffer.index);

    [self.lock unlockWithCondition:(self.queue.count == 0 ? NO_BUFFERS : HAS_BUFFER_OR_STOP_REQUEST)];
    return buffer;
}

- (void)dealloc {
    [self.lock lock];
    [self.queue removeAllObjects]; // Empty the queue
    [self.lock unlock];

    NSLog(@"BufferQueue deallocated and cleared.");
}

@end
