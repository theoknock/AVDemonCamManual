/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

@import UIKit;

#import "AVCamManualAppDelegate.h"

static double (^ _Nonnull control_property_value)(double, double, double, double) = ^ double (double control_value, double property_value_min, double property_value_max, double gamma) {
    return ((pow(control_value, gamma) * (property_value_max - property_value_min)) + property_value_min);
};

static double (^ _Nonnull property_control_value)(double, double, double, double) = ^ double (double property_value, double property_value_min, double property_value_max, double inverse_gamma) {
    return pow((property_value - property_value_min) / (property_value_max - property_value_min), 1.f / inverse_gamma);
};

static double (^ _Nonnull rescale_value)(double, double, double, double, double) = ^ double (double value, double value_min, double value_max, double new_value_min, double new_value_max) {
    return (new_value_max - new_value_min) * (value - value_min) / (value_max - value_min) + new_value_min;
};

@interface AVCamManualCameraViewController : UIViewController

@property (nonatomic) AVCaptureMovieFileOutput * _Nullable movieFileOutput;
- (void)captureOutput:(AVCaptureFileOutput * _Nullable)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL * _Nonnull)outputFileURL fromConnections:(NSArray * _Nonnull)connections error:(NSError * _Nullable)error;

@end
