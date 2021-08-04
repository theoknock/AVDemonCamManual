/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Application delegate.
*/

@import Foundation;
@import UIKit;
@import AVFoundation;

#import "AVCamManualCameraViewController.h"

@protocol MovieAppEventDelegate <NSObject>

@property (nonatomic) AVCaptureMovieFileOutput * movieFileOutput;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

@end

@import UIKit;

@interface AVCamManualAppDelegate : UIResponder <UIApplicationDelegate>

+ (AVCamManualAppDelegate *)sharedAppDelegate;


@property (nonatomic) UIWindow *window;
@property (weak) IBOutlet id<MovieAppEventDelegate> movieAppEventDelegate;

@property (nonatomic) dispatch_queue_t sessionQueue;

@end
