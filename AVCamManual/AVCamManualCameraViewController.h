/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

@import UIKit;

#import "AVCamManualAppDelegate.h"

@interface AVCamManualCameraViewController : UIViewController

@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

@end
