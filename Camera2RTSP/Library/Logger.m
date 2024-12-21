//
//  Logger.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 21/12/2024.
//

#import "Logger.h"


@implementation Logger

- (instancetype)init {
    self = [super init];
    if (self) {
        self.logLevel = LogLevelDebug;
    }
    return self;
}

- (instancetype)initWithNameAndLevel:(NSString *) name logLevel:(LogLevel) level {
    self = [super init];
    if (self) {
        self.logLevel = level;
        self.name = name;
    }
    return self;
}

- (NSString *)currentDateTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    return dateString;
}

- (void)logMessage:(NSString *)message level:(LogLevel)level {
    if (level == self.logLevel) {
        NSString *levelString;
        switch (level) {
            case LogLevelDebug:
                levelString = @"DEBUG";
                break;
            case LogLevelInfo:
                levelString = @"INFO";
                break;
            case LogLevelWarn:
                levelString = @"WARN";
                break;
            case LogLevelError:
                levelString = @"ERROR";
                break;
            case LogLevelLog:
                levelString = @"LOG";
                break;
            default:
                levelString = @"LOG";
                break;
        }
        
        NSString *dateTimeStamp = [self currentDateTimeString];
        NSLog(@"[%@] [%@] %@ --- %@", dateTimeStamp, levelString, self.name,message);
    }
}

- (void)log:(NSString *)message, ... {
    if (self.logLevel == LogLevelNone) return;
    va_list args;
    va_start(args, message);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    [self logMessage:formattedMessage level:LogLevelLog];
}
- (void)debug:(NSString *)message, ... {
    if (self.logLevel == LogLevelNone) return;
    va_list args;
    va_start(args, message);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    [self logMessage:formattedMessage level:LogLevelDebug];

}
- (void)info:(NSString *)message, ... {
    if (self.logLevel == LogLevelNone) return;
    va_list args;
    va_start(args, message);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    [self logMessage:formattedMessage level:LogLevelInfo];

}
- (void)warn:(NSString *)message, ... {
    if (self.logLevel == LogLevelNone) return;
    va_list args;
    va_start(args, message);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    [self logMessage:formattedMessage level:LogLevelWarn];

}
- (void)error:(NSString *)message, ... {
    if (self.logLevel == LogLevelNone) return;
    va_list args;
    va_start(args, message);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    va_end(args);
    [self logMessage:formattedMessage level:LogLevelError];
}


@end
