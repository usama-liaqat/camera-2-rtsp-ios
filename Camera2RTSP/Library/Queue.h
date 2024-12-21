//
//  Queue.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#ifndef Queue_h
#define Queue_h
#import <Foundation/Foundation.h>
#import "Types.h"


NS_ASSUME_NONNULL_BEGIN

@interface Queue : NSObject
@property (nonatomic) NSMutableArray<id> *queue;
@property (nonatomic) NSConditionLock *lock;
@property (nonatomic) NSString *name;
@property (nonatomic) int index;

- (instancetype)initWithName:(NSString *) name;
- (void)enqueue:(id)buffer;
- (id)dequeue;
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

#endif /* Queue_h */
