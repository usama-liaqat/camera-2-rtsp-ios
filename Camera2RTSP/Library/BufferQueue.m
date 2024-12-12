//
//  BufferQueue.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#import <Foundation/Foundation.h>
#import "BufferQueue.h"



@implementation BufferQueue

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSConditionLock alloc] initWithCondition:0];
        self.queue = [NSMutableArray array];
    }
    return self;
}

- (void)insert:(BufferItem*)buffer {
    [self.lock lock];
    [self.queue addObject:buffer];
    NSLog(@"INSERT --- Buffer Queue Items -> %lu", (unsigned long)self.queue.count);
    [self.lock unlockWithCondition:1];
}

- (BufferItem *)pop {
    [self.lock lockWhenCondition:1]; // Wait for data to be available
    BufferItem *buffer = nil;
    if (self.queue.count > 0) {
        // Pop the first buffer from the queue
        buffer = [self.queue firstObject];
        [self.queue removeObjectAtIndex:0]; // Remove the first element
    }
    
    NSLog(@"POP --- Buffer Queue Items -> %lu", (unsigned long)self.queue.count);

    [self.lock unlockWithCondition:(self.queue.count > 0 ? 1 : 0)];
    return buffer;
}

- (void)dealloc {
    [self.lock lock];
    for (BufferItem *buffer in self.queue) {
        [buffer free];
    }
    [self.queue removeAllObjects]; // Empty the queue
    [self.lock unlock];

    NSLog(@"BufferQueue deallocated and cleared.");
}

@end
