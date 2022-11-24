/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

@import UIKit;

#import "AVCamManualAppDelegate.h"

static double (^propertyValueFromNormalizedControlValue)(double, double, double) = ^ double (double control_value, double property_value_min, double property_value_max) {
    return (control_value * (property_value_max - property_value_min)) + property_value_min;
};

static double (^normalizedControlValueFromPropertyValue)(double, double, double) = ^ double (double property_value, double property_value_min, double property_value_max) {
    return (property_value - property_value_min) / ( property_value_max - property_value_min);
};


@interface AVCamManualCameraViewController : UIViewController

@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

@end
