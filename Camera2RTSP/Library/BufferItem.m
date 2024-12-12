//
//  BufferItem.m
//  Camera2RTSP
//
//  Created by Usama Liaqat on 12/12/2024.
//

#import "BufferItem.h"

@implementation BufferItem

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer timestamp:(GstClockTime)timestamp duration:(GstClockTime)duration {
    self = [super init];
    if (self) {
        if (!sampleBuffer) {
            NSLog(@"Received nil sampleBuffer.");
            return nil;
        }
        
        self.sampleBuffer = sampleBuffer; // Retain the sample buffer
        CFRetain(self.sampleBuffer); // Increment the retain count to manage memory
        
        // Get the format description
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        if (!formatDesc) {
            NSLog(@"Failed to get format description from sample buffer.");
            return nil;
        }
        
        // Extract dimensions
        CGSize dimensions = CMVideoFormatDescriptionGetPresentationDimensions(formatDesc, true, true);
        self.width = (int)dimensions.width;
        self.height = (int)dimensions.height;
        
        // Extract PTS and DTS
        self.pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        self.dts = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
        
        // Extract media type
        self.mediaType = CMFormatDescriptionGetMediaSubType(formatDesc);
        
        // Convert media type (FourCharCode) to string
        self.type = [NSString stringWithFormat:@"%c%c%c%c",
                     (self.mediaType >> 24) & 0xFF,
                     (self.mediaType >> 16) & 0xFF,
                     (self.mediaType >> 8) & 0xFF,
                     self.mediaType & 0xFF];
        self.timestamp = timestamp;
        self.duration = duration;
    }
    return self;
}


- (void)dealloc {
    if (self.sampleBuffer) {
        CFRelease(self.sampleBuffer);
    }
    NSLog(@"BufferItem deallocated and cleared.");

}

@end
