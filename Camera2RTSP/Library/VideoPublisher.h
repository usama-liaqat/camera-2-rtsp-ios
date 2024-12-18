//
//  VideoPublisher.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 18/12/2024.
//

#ifndef VideoPublisher_h
#define VideoPublisher_h
#import <Foundation/Foundation.h>
#include <ffmpegkit/FFmpegKit.h>

@interface VideoPublisher : NSObject
@property (nonatomic) NSString *source_url;
@property (nonatomic) NSString *output_url;
@property (nonatomic) FFmpegSession *session;
@property (nonatomic) BOOL publish;
- (instancetype)initWithSourceandOutputURI:(NSString *)source_url outputURI:(NSString*)uri;
- (void)start;
- (void)stop;
@end

#endif /* VideoPublisher_h */
