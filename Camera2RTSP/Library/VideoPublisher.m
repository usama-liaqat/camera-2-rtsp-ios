//
//  VideoPublisher.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 18/12/2024.
//

#import "VideoPublisher.h"


@implementation VideoPublisher

- (instancetype)initWithSourceandOutputURI:(NSString *)source_url outputURI:(NSString*)output_url {
    self = [super init];
    NSLog(@"initWithSourceUrl ");
    if (self) {
        _source_url = source_url;
        _output_url = output_url;
        _publish = true;
    }
    return self;
}

- (void)pipeline {
    NSLog(@"startPublishing ");
    NSString *local_rtsp_url = [NSString stringWithUTF8String:[_source_url UTF8String]];
    NSString *cloud_rtsp_url = [NSString stringWithUTF8String:[_output_url UTF8String]];
    NSString *command = [NSString stringWithFormat:@"-f rtsp -i %@ -c:v copy -f rtsp -rtsp_transport tcp %@", local_rtsp_url, cloud_rtsp_url];
    NSLog(@"pipeline %s", [command UTF8String]);

    self.session = [FFmpegKit execute:command];
    
    ReturnCode *returnCode = [self.session getReturnCode];
    if ([ReturnCode isSuccess:returnCode]) {
        
        // SUCCESS
        
    } else if ([ReturnCode isCancel:returnCode]) {
        // CANCEL
        NSLog(@"Command Canceled with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[self.session getState]], returnCode, [self.session getFailStackTrace]);
        
    } else {
        // FAILURE
        NSLog(@"Command failed with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[self.session getState]], returnCode, [self.session getFailStackTrace]);
    }
}

- (void)start {
    _publish = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pipeline];
    });
}

- (void)stop {
    NSLog(@"stopPublishing ");
    _publish = false;
    NSArray *list = [FFmpegKit listSessions];
    for (int i = 0; i < [list count]; i++) {
        FFmpegSession *session = [list objectAtIndex:i];
        long sessionId = [session getSessionId];
        [FFmpegKit cancel:sessionId];
    }
}

@end
