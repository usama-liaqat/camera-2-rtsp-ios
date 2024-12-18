//
//  Types.h
//  Camera2RTSP
//
//  Created by Usama Liaqat on 07/12/2024.
//

#import <Foundation/Foundation.h>
#ifndef Types_h
#define Types_h

typedef NS_ENUM(NSInteger, StatusCode) {
    portAvailable = 0,
    serverStarted = 1,
    publishingStarted = 2,
    publishingStopped = 3,
    
    
    portNotAvailable = 4,
    serverError = 5,
    publishingError = 6,
    brightnessError = 7,
    flipError = 7,
    serverStopped = 8,
};

typedef void (^MessageCallback)(BOOL status, NSString * _Nonnull message, StatusCode code);
typedef void (^StatusCallback)(BOOL status);

#endif /* Types_h */
