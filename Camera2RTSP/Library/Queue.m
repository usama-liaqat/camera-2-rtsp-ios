//
//  Queue.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#import "Queue.h"



#define BUFFER_QUEUE_SIZE     2


@implementation Queue

- (instancetype)init {
    self = [super init];
    if (self) {
        self.lock = [[NSConditionLock alloc] initWithCondition:NO_BUFFERS];
        self.queue = [[NSMutableArray alloc] initWithCapacity:BUFFER_QUEUE_SIZE];
        self.index = 0;
        self.name = @"Queue";

    }
    return self;
}

- (instancetype)initWithName:(NSString *) name {
    self = [super init];
    if (self) {
        self.name = name;
    }
    return self;
}

- (void)enqueue:(id)buffer {
    [self.lock lock];
    if ([self.queue count] == BUFFER_QUEUE_SIZE){
            [self.queue removeLastObject];
    }

    [self.queue insertObject:buffer atIndex:0];
    NSLog(@"ENQUEUE --- %@ --- Queue Items -> %lu", self.name, (unsigned long)self.queue.count);
    [self.lock unlockWithCondition:HAS_BUFFER_OR_STOP_REQUEST];
}

- (id)dequeue {
    [self.lock lockWhenCondition:HAS_BUFFER_OR_STOP_REQUEST]; // Wait for data to be available
    id buffer = nil;
    if (self.queue.count > 0) {
        // Pop the first buffer from the queue
        buffer = [self.queue lastObject];
        [self.queue removeLastObject]; // Remove the first element
    }
    
    NSLog(@"DEQUEUE --- %@ --- Queue Items -> %lu", self.name,(unsigned long)self.queue.count);

    [self.lock unlockWithCondition:(self.queue.count == 0 ? NO_BUFFERS : HAS_BUFFER_OR_STOP_REQUEST)];
    return buffer;
}

- (void)dealloc {
    [self.lock lock];
    [self.queue removeAllObjects]; // Empty the queue
    [self.lock unlock];
    NSLog(@"DEALLOCATED --- %@ ---  deallocated and cleared.",self.name);
}

@end
