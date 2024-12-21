//
//  Logger.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#ifndef Logger_h
#define Logger_h
#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelWarn,
    LogLevelError,
    LogLevelLog,
    LogLevelNone
};

NS_ASSUME_NONNULL_BEGIN

@interface Logger : NSObject
@property (nonatomic, assign) LogLevel logLevel;
@property (nonatomic, assign) NSString * name;

- (instancetype)initWithNameAndLevel:(NSString *) name logLevel:(LogLevel) level;
- (void)log:(NSString *)message, ...;
- (void)debug:(NSString *)message, ...;
- (void)info:(NSString *)message, ...;
- (void)warn:(NSString *)message, ...;
- (void)error:(NSString *)message, ...;

@end

NS_ASSUME_NONNULL_END

#endif /* Logger_h */
