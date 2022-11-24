/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller for camera interface.
 
 Modified by James Alan Bush (The Life of a Demoniac)
 demonicactivity.blogspot.com
 
 */

@import AVFoundation;
@import Photos;

#import "AVCamManualCameraViewController.h"
#import "AVCamManualPreviewView.h"
#import "AVCamManualAppDelegate.h"

static void * SessionRunningContext = &SessionRunningContext;
static void * FocusModeContext = &FocusModeContext;
static void * ExposureModeContext = &ExposureModeContext;
static void * TorchLevelContext = &TorchLevelContext;
static void * LensPositionContext = &LensPositionContext;
static void * ExposureDurationContext = &ExposureDurationContext;
static void * ISOContext = &ISOContext;
static void * ExposureTargetBiasContext = &ExposureTargetBiasContext;
static void * ExposureTargetOffsetContext = &ExposureTargetOffsetContext;
static void * VideoZoomFactorContext = &VideoZoomFactorContext;
static void * PresetsContext = &PresetsContext;

static void * DeviceWhiteBalanceGainsContext = &DeviceWhiteBalanceGainsContext;
static void * WhiteBalanceModeContext = &WhiteBalanceModeContext;

typedef NS_ENUM( NSInteger, AVCamManualSetupResult ) {
    AVCamManualSetupResultSuccess,
    AVCamManualSetupResultCameraNotAuthorized,
    AVCamManualSetupResultSessionConfigurationFailed
};

typedef NS_ENUM( NSInteger, AVCamManualCaptureMode ) {
    AVCamManualCaptureModePhoto = 0,
    AVCamManualCaptureModeMovie = 1
};

@interface AVCamManualCameraViewController () <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, weak) IBOutlet AVCamManualPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIImageView * cameraUnavailableImageView;
@property (nonatomic, weak) IBOutlet UIButton *resumeButton;
@property (nonatomic, weak) IBOutlet UIButton *recordButton;
//@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
//@property (nonatomic, weak) IBOutlet UIButton *photoButton;
@property (nonatomic, weak) IBOutlet UIButton *HUDButton;

@property (nonatomic, weak) IBOutlet UIView *manualHUD;

@property (nonatomic, weak) IBOutlet UIView *controlsView;

@property (nonatomic) NSArray *focusModes;
@property (nonatomic, weak) IBOutlet UIView *manualHUDFocusView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *focusModeControl;
@property (nonatomic, weak) IBOutlet UISlider *lensPositionSlider;
@property (nonatomic, weak) IBOutlet UILabel *lensPositionNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *lensPositionValueLabel;

@property (nonatomic) NSArray *exposureModes;
@property (nonatomic, weak) IBOutlet UIView *manualHUDExposureView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *exposureModeControl;
@property (nonatomic, weak) IBOutlet UISlider *exposureDurationSlider;
@property (nonatomic, weak) IBOutlet UILabel *exposureDurationNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureDurationValueLabel;
@property (nonatomic, weak) IBOutlet UISlider *ISOSlider;
@property (nonatomic, weak) IBOutlet UILabel *ISONameLabel;
@property (nonatomic, weak) IBOutlet UILabel *ISOValueLabel;
@property (nonatomic, weak) IBOutlet UISlider *exposureTargetBiasSlider;
@property (nonatomic, weak) IBOutlet UILabel *exposureTargetBiasNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureTargetBiasValueLabel;
@property (nonatomic, weak) IBOutlet UISlider *exposureTargetOffsetSlider;
@property (nonatomic, weak) IBOutlet UILabel *exposureTargetOffsetNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureTargetOffsetValueLabel;

@property (weak, nonatomic) IBOutlet UIView *manualHUDVideoZoomFactorView;
@property (weak, nonatomic) IBOutlet UILabel *videoZoomFactorValueLabel;
@property (weak, nonatomic) IBOutlet UISlider *videoZoomFactorSlider;

@property (weak, nonatomic) IBOutlet UIView *manualHUDTorchLevelView;
@property (weak, nonatomic) IBOutlet UISlider *torchLevelSlider;


@property (nonatomic) NSArray *whiteBalanceModes;
@property (weak, nonatomic) IBOutlet UIView *manualHUDWhiteBalanceView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *whiteBalanceModeControl;
@property (weak, nonatomic) IBOutlet UISlider *temperatureSlider;
@property (weak, nonatomic) IBOutlet UISlider *tintSlider;
@property (weak, nonatomic) IBOutlet UIButton *grayWorldButton;

@property (weak, nonatomic) IBOutlet UIView *coverView;

@property (nonatomic, weak) IBOutlet UIView *manualHUDLensStabilizationView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *lensStabilizationControl;

@property (weak, nonatomic) IBOutlet UIButton *exDurISOPresetsButton;


// Session management
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureDeviceDiscoverySession *videoDeviceDiscoverySession;
@property (nonatomic) AVCaptureDevice *videoDevice;
//@property (nonatomic) AVCapturePhotoOutput *photoOutput;

//@property (nonatomic) NSMutableDictionary<NSNumber *, AVCamManualPhotoCaptureDelegate *> *inProgressPhotoCaptureDelegates;

// Utilities
@property (nonatomic) AVCamManualSetupResult setupResult;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

@end

@implementation AVCamManualCameraViewController

static const float kExposureDurationPower = 5; // Higher numbers will give the slider more sensitivity at shorter durations
static const float kExposureMinimumDuration = 1.0/1000; // Limit exposure duration to a useful range


#pragma mark View Controller Life Cycle

- (void)toggleControlViewVisibility:(NSArray *)views hide:(BOOL)shouldHide
{
    [views enumerateObjectsUsingBlock:^(UIView *  _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        [view setHidden:shouldHide];
        [view setAlpha:(shouldHide) ? 0.0 : 1.0];
    }];
}


- (IBAction)toggleCoverView:(UIButton *)sender {
    [self.coverView setHidden:TRUE];
    [self.coverView setAlpha:0.0];
}



- (IBAction)toggleDisplay:(UIButton *)sender {
    [self.coverView setHidden:FALSE];
    [self.coverView setAlpha:1.0];
    //    [self.previewView.layer setHidden:!self.previewView.layer.isHidden];
    //    [self.view.subviews enumerateObjectsUsingBlock:^(UIView *  _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
    //        [view setHidden:!view.isHidden];
    //        [view setAlpha:!view.isHidden];
    //    }];
    //
    //    [sender setHidden:FALSE];
    //    [sender setAlpha:FALSE];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.session = [[AVCaptureSession alloc] init];
    
    NSArray<NSString *> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    self.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    self.previewView.session = self.session;
    
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    
    self.setupResult = AVCamManualSetupResultSuccess;
    
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            
            if ( [self.session canAddOutput:movieFileOutput] ) {
                [self.session beginConfiguration];
                [self.session addOutput:movieFileOutput];
                self.session.sessionPreset = AVCaptureSessionPreset3840x2160;
                AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
                if ( connection.isVideoStabilizationSupported ) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }
                [self.session commitConfiguration];
                
                self.movieFileOutput = movieFileOutput;
                
                dispatch_async( dispatch_get_main_queue(), ^{
                    self.recordButton.enabled = YES;
                    self.HUDButton.enabled = YES;
                } );
                
                
            }
            
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = AVCamManualSetupResultCameraNotAuthorized;
                }
                dispatch_resume( self.sessionQueue );
            }];
            break;
        }
        default:
        {
            // The user has previously denied access
            self.setupResult = AVCamManualSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    // Setup the capture session.
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
    // so that the main queue isn't blocked, which keeps the UI responsive.
    dispatch_async( self.sessionQueue, ^{
        [self configureSession];
    } );
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    dispatch_async( self.sessionQueue, ^{
        switch ( self.setupResult )
        {
            case AVCamManualSetupResultSuccess:
            {
                // Only setup observers and start the session running if setup succeeded
                [self addObservers];
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
                
                break;
            }
            case AVCamManualSetupResultCameraNotAuthorized:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"AVCamManual doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCamManual" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }];
                    [alertController addAction:settingsAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
            case AVCamManualSetupResultSessionConfigurationFailed:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCamManual" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
        }
    } );
}

- (void)viewDidDisappear:(BOOL)animated
{
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult == AVCamManualSetupResultSuccess ) {
            [self.session stopRunning];
            [self removeObservers];
        }
    } );
    
    [super viewDidDisappear:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        previewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate
{
    // Disable autorotation of the interface when recording is in progress
    return FALSE;// ! self.movieFileOutput.isRecording;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark HUD

- (void)configureManualHUD
{
    // Manual focus controls
    self.focusModes = @[@(AVCaptureFocusModeContinuousAutoFocus), @(AVCaptureFocusModeLocked)];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __autoreleasing NSError *error;
        if ([_videoDevice lockForConfiguration:&error]) {
            [self.focusModeControl setSelectedSegmentIndex:0];
            self.lensPositionSlider.minimumValue = 0.0;
            self.lensPositionSlider.maximumValue = 1.0;
            self.lensPositionSlider.value = 0.0;
            [self changeFocusMode:nil];
            //            self.videoDevice.focusMode == AVCaptureFocusModeContinuousAutoFocus && [self.videoDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
            
            // Manual exposure controls
            self.exposureModes = @[@(AVCaptureExposureModeContinuousAutoExposure), @(AVCaptureExposureModeLocked), @(AVCaptureExposureModeCustom)];
            self.exposureModeControl.enabled = ( self.videoDevice != nil );
            [self.exposureModeControl setSelectedSegmentIndex:0];
            for ( NSNumber *mode in self.exposureModes ) {
                [self.exposureModeControl setEnabled:[self.videoDevice isExposureModeSupported:mode.intValue] forSegmentAtIndex:[self.exposureModes indexOfObject:mode]];
            }
            [self changeExposureMode:nil];

            // Use 0-1 as the slider range and do a non-linear mapping from the slider value to the actual device exposure duration
            self.exposureDurationSlider.minimumValue = 0;
            self.exposureDurationSlider.maximumValue = 1;
            double exposureDurationSeconds = CMTimeGetSeconds( self.videoDevice.exposureDuration );
            double minExposureDurationSeconds = MAX( CMTimeGetSeconds( self.videoDevice.activeFormat.minExposureDuration ), kExposureMinimumDuration );
            double maxExposureDurationSeconds = CMTimeGetSeconds( self.videoDevice.activeFormat.maxExposureDuration );
            // Map from duration to non-linear UI range 0-1
            double p = ( exposureDurationSeconds - minExposureDurationSeconds ) / ( maxExposureDurationSeconds - minExposureDurationSeconds ); // Scale to 0-1
            self.exposureDurationSlider.value = pow( p, 1 / kExposureDurationPower ); // Apply inverse power
            self.exposureDurationSlider.enabled = ( self.videoDevice && self.videoDevice.exposureMode == AVCaptureExposureModeCustom);
            
            // To-Do: Use this to set the exposure duration to 1.0/3.0 sans slider
            // [self.videoDevice setExposureModeCustomWithDuration:kCMTimeInvalid /*CMTimeMakeWithSeconds( (1.0/3.0), 1000*1000*1000 )
            
            self.ISOSlider.minimumValue = self.videoDevice.activeFormat.minISO;
            self.ISOSlider.maximumValue = self.videoDevice.activeFormat.maxISO;
            self.ISOSlider.value = self.videoDevice.ISO;
            self.ISOSlider.enabled = ( self.videoDevice.exposureMode == AVCaptureExposureModeCustom );
            
            self.exposureTargetBiasSlider.minimumValue = self.videoDevice.minExposureTargetBias;
            self.exposureTargetBiasSlider.maximumValue = self.videoDevice.maxExposureTargetBias;
            self.exposureTargetBiasSlider.value = self.videoDevice.exposureTargetBias;
            self.exposureTargetBiasSlider.enabled = ( self.videoDevice != nil );
            
            self.exposureTargetOffsetSlider.minimumValue = self.videoDevice.minExposureTargetBias;
            self.exposureTargetOffsetSlider.maximumValue = self.videoDevice.maxExposureTargetBias;
            self.exposureTargetOffsetSlider.value = self.videoDevice.exposureTargetOffset;
            self.exposureTargetOffsetSlider.enabled = NO;
            
            self.videoZoomFactorSlider.minimumValue = 0.0;
            self.videoZoomFactorSlider.maximumValue = 1.0;
            self.videoZoomFactorSlider.value = normalizedControlValueFromPropertyValue(self.videoDevice.videoZoomFactor, self.videoDevice.minAvailableVideoZoomFactor, self.videoDevice.activeFormat.videoMaxZoomFactor);
            self.videoZoomFactorSlider.enabled = YES;
            
            
            
            // To-Do: Restore these for "color-contrasting" overwhite/overblack subject areas (where luminosity contrasting fails)
            
            // Manual white balance controls
            self.whiteBalanceModes = @[@(AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance), @(AVCaptureWhiteBalanceModeLocked)];
            
            self.whiteBalanceModeControl.enabled = (self.videoDevice != nil);
            self.whiteBalanceModeControl.selectedSegmentIndex = [self.whiteBalanceModes indexOfObject:@(self.videoDevice.whiteBalanceMode)];
            for ( NSNumber *mode in self.whiteBalanceModes ) {
                [self.whiteBalanceModeControl setEnabled:[self.videoDevice isWhiteBalanceModeSupported:mode.intValue] forSegmentAtIndex:[self.whiteBalanceModes indexOfObject:mode]];
            }
            
            AVCaptureWhiteBalanceGains whiteBalanceGains = self.videoDevice.deviceWhiteBalanceGains;
            AVCaptureWhiteBalanceTemperatureAndTintValues whiteBalanceTemperatureAndTint = [self.videoDevice temperatureAndTintValuesForDeviceWhiteBalanceGains:whiteBalanceGains];
            
            self.temperatureSlider.minimumValue = 3000;
            self.temperatureSlider.maximumValue = 8000; //self.videoDevice.maxWhiteBalanceGain;
            self.temperatureSlider.value = whiteBalanceTemperatureAndTint.temperature;
            self.temperatureSlider.enabled = ( self.videoDevice && self.videoDevice.whiteBalanceMode == AVCaptureWhiteBalanceModeLocked );
            
            self.tintSlider.minimumValue = -150;
            self.tintSlider.maximumValue = 150;
            self.tintSlider.value = whiteBalanceTemperatureAndTint.tint;
            self.tintSlider.enabled = ( self.videoDevice && self.videoDevice.whiteBalanceMode == AVCaptureWhiteBalanceModeLocked );
            
            if ([_videoDevice isTorchActive])
                [_videoDevice setTorchMode:0];
            //            else
            //                [_videoDevice setTorchModeOnWithLevel:AVCaptureMaxAvailableTorchLevel error:nil];
        } else {
            NSLog(@"AVCaptureDevice lockForConfiguration returned error\t%@", error);
        }
        [_videoDevice unlockForConfiguration];
    });
}

//- (IBAction)toggleTorch:(id)sender
//{
//    NSLog(@"%s", __PRETTY_FUNCTION__);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        __autoreleasing NSError *error;
//        if ([_videoDevice lockForConfiguration:&error]) {
//            if ([_videoDevice isTorchActive])
//                [_videoDevice setTorchMode:0];
//            else
//                [_videoDevice setTorchModeOnWithLevel:AVCaptureMaxAvailableTorchLevel error:nil];
//        } else {
//            NSLog(@"AVCaptureDevice lockForConfiguration returned error\t%@", error);
//        }
//        [_videoDevice unlockForConfiguration];
//    });
//}

- (IBAction)toggleHUD:(id)sender
{
    [sender setSelected:self.manualHUD.hidden = ! self.manualHUD.hidden];
    [sender setHighlighted:[sender isSelected]];
}

- (IBAction)changeManualHUD:(id)sender
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    UISegmentedControl *control = (UISegmentedControl *)sender;
    
    [self toggleControlViewVisibility:@[self.manualHUDTorchLevelView]      hide:(control.selectedSegmentIndex == 0) ? NO : YES];
    [self toggleControlViewVisibility:@[self.manualHUDFocusView]           hide:(control.selectedSegmentIndex == 1) ? NO : YES];
    [self toggleControlViewVisibility:@[self.manualHUDExposureView]        hide:(control.selectedSegmentIndex == 2) ? NO : YES];
    [self toggleControlViewVisibility:@[self.manualHUDVideoZoomFactorView] hide:(control.selectedSegmentIndex == 3) ? NO : YES];
    [self toggleControlViewVisibility:@[self.manualHUDWhiteBalanceView] hide:(control.selectedSegmentIndex == 4) ? NO : YES];
    //    [self toggleControlViewVisibility:@[self.manualHUDPresetsView] hide:(control.selectedSegmentIndex == 5) ? NO : YES];
}

- (void)setSlider:(UISlider *)slider highlightColor:(UIColor *)color
{
    if (slider.tag != -1)
        slider.tintColor = color;
    
    if ( slider == self.lensPositionSlider ) {
        self.lensPositionNameLabel.textColor = self.lensPositionValueLabel.textColor = slider.tintColor;
    }
    else if ( slider == self.exposureDurationSlider ) {
        self.exposureDurationNameLabel.textColor = self.exposureDurationValueLabel.textColor = slider.tintColor;
    }
    else if ( slider == self.ISOSlider ) {
        self.ISONameLabel.textColor = self.ISOValueLabel.textColor = slider.tintColor;
    }
    else if ( slider == self.exposureTargetBiasSlider ) {
        self.exposureTargetBiasNameLabel.textColor = self.exposureTargetBiasValueLabel.textColor = slider.tintColor;
    }
    else if ( slider == self.temperatureSlider ) {
        //        self.temperatureNameLabel.textColor = self.temperatureValueLabel.textColor = slider.tintColor;
    }
    else if ( slider == self.tintSlider ) {
        //        self.tintNameLabel.textColor = self.tintValueLabel.textColor = slider.tintColor;
    }
}

- (IBAction)sliderTouchBegan:(id)sender
{
    UISlider *slider = (UISlider *)sender;
    [self setSlider:slider highlightColor:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0]];
}

- (IBAction)sliderTouchEnded:(id)sender
{
    UISlider *slider = (UISlider *)sender;
    [self setSlider:slider highlightColor:[UIColor yellowColor]];
}

#pragma mark Session Management

// Should be called on the session queue
- (void)configureSession
{
    if ( self.setupResult != AVCamManualSetupResultSuccess ) {
        return;
    }
    
    NSError *error = nil;
    
    [self.session beginConfiguration];
    
    self.session.sessionPreset = AVCaptureSessionPreset3840x2160;
    [self.session setAutomaticallyConfiguresCaptureDeviceForWideColor:TRUE];
    
    // Add video input
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if ( ! videoDeviceInput ) {
        NSLog( @"Could not create video device input: %@", error );
        self.setupResult = AVCamManualSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    if ( [self.session canAddInput:videoDeviceInput] ) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
        self.videoDevice = videoDevice;
        
        // Configure default camera focus and exposure properties (set to manual vs. auto)
        __autoreleasing NSError *error = nil;
        [self.videoDevice lockForConfiguration:&error];
        @try {
            [self.videoDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [self.videoDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        } @catch (NSException *exception) {
            NSLog(@"Error setting focus mode: %@", error.description);
        } @finally {
            [self.videoDevice unlockForConfiguration];
        }
        
        //  Enable low-light boost
        __autoreleasing NSError *automaticallyEnablesLowLightBoostWhenAvailableError = nil;
        [self.videoDevice lockForConfiguration:&automaticallyEnablesLowLightBoostWhenAvailableError];
        @try {
            [self.videoDevice setAutomaticallyEnablesLowLightBoostWhenAvailable:TRUE];
        } @catch (NSException *exception) {
            NSLog(@"Error enabling automatic low light boost: %@", automaticallyEnablesLowLightBoostWhenAvailableError.description);
        } @finally {
            [self.videoDevice unlockForConfiguration];
        }
        
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
            AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
            if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
            }
            
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
            previewLayer.connection.videoOrientation = initialVideoOrientation;
        } );
    }
    else {
        NSLog( @"Could not add video device input to the session" );
        self.setupResult = AVCamManualSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    // Add audio input
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if ( ! audioDeviceInput ) {
        NSLog( @"Could not create audio device input: %@", error );
    }
    if ( [self.session canAddInput:audioDeviceInput] ) {
        [self.session addInput:audioDeviceInput];
    }
    else {
        NSLog( @"Could not add audio device input to the session" );
    }
    
    
    // We will not create an AVCaptureMovieFileOutput when configuring the session because the AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto
    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    
    [self.session commitConfiguration];
    
    dispatch_async( dispatch_get_main_queue(), ^{
        [self configureManualHUD];
    } );
}

- (IBAction)resumeInterruptedSession:(id)sender
{
    dispatch_async( self.sessionQueue, ^{
        [self.session startRunning];
        self.sessionRunning = self.session.isRunning;
        if ( ! self.session.isRunning ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                NSString *message = NSLocalizedString( @"Unable to resume", @"Alert message when unable to resume the session running" );
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCamManual" message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                [alertController addAction:cancelAction];
                [self presentViewController:alertController animated:YES completion:nil];
            } );
        }
        else {
            dispatch_async( dispatch_get_main_queue(), ^{
                self.resumeButton.hidden = YES;
            } );
        }
    } );
}

- (IBAction)changeCaptureMode:(UISegmentedControl *)captureModeControl
{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        if ( [self.session canAddOutput:movieFileOutput] ) {
            [self.session beginConfiguration];
            [self.session addOutput:movieFileOutput];
            self.session.sessionPreset = AVCaptureSessionPreset3840x2160;
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ( connection.isVideoStabilizationSupported ) {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
            }
            [self.session commitConfiguration];
            
            self.movieFileOutput = movieFileOutput;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                self.recordButton.enabled = YES;
            } );
        }
    } );
}

#pragma mark Device Configuration

- (void)changeCameraWithDevice:(AVCaptureDevice *)newVideoDevice
{
    // Check if device changed
    if ( newVideoDevice == self.videoDevice ) {
        return;
    }
    
    self.manualHUD.userInteractionEnabled = NO;
    //	self.cameraButton.enabled = NO;
    self.recordButton.enabled = NO;
    //	self.photoButton.enabled = NO;
    //	self.captureModeControl.enabled = NO;
    //    self.HUDButton.enabled = NO;
    
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDeviceInput *newVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:nil];
        
        [self.session beginConfiguration];
        
        // Remove the existing device input first, since using the front and back camera simultaneously is not supported
        [self.session removeInput:self.videoDeviceInput];
        if ( [self.session canAddInput:newVideoDeviceInput] ) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDevice];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:newVideoDevice];
            
            [self.session addInput:newVideoDeviceInput];
            self.videoDeviceInput = newVideoDeviceInput;
            self.videoDevice = newVideoDevice;
        }
        else {
            [self.session addInput:self.videoDeviceInput];
        }
        
        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ( connection.isVideoStabilizationSupported ) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        [self.session commitConfiguration];
        
        dispatch_async( dispatch_get_main_queue(), ^{
            [self configureManualHUD];
            
            //			self.cameraButton.enabled = YES;
            self.recordButton.enabled = YES;
            //			self.photoButton.enabled = YES;
            //			self.captureModeControl.enabled = YES;
            self.HUDButton.enabled = YES;
            self.manualHUD.userInteractionEnabled = YES;
        } );
    } );
}

- (IBAction)changeFocusMode:(id)sender
{
    UISegmentedControl *control = sender;
    AVCaptureFocusMode mode = (AVCaptureFocusMode)[self.focusModes[control.selectedSegmentIndex] intValue];
    
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        if ( [self.videoDevice isFocusModeSupported:mode] ) {
            self.videoDevice.focusMode = mode;
        }
        else {
            NSLog( @"Focus mode %@ is not supported. Focus mode is %@.", [self stringFromFocusMode:mode], [self stringFromFocusMode:self.videoDevice.focusMode] );
            self.focusModeControl.selectedSegmentIndex = [self.focusModes indexOfObject:@(self.videoDevice.focusMode)];
        }
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (IBAction)changeLensPosition:(id)sender
{
    UISlider *control = sender;
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        [self.videoDevice setFocusModeLockedWithLensPosition:control.value completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDevice;
        
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            if ( focusMode != AVCaptureFocusModeLocked && device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if ( exposureMode != AVCaptureExposureModeCustom && device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    } );
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self.previewView.layer sublayers] lastObject] captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:[gestureRecognizer view]]];
    [self focusWithMode:self.videoDevice.focusMode exposeWithMode:self.videoDevice.exposureMode atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (IBAction)changeExposureMode:(id)sender
{
    UISegmentedControl *control = sender;
    AVCaptureExposureMode mode = (AVCaptureExposureMode)[self.exposureModes[control.selectedSegmentIndex] intValue];
    self.exposureDurationSlider.enabled = ( mode == AVCaptureExposureModeCustom );
    self.ISOSlider.enabled = ( mode == AVCaptureExposureModeCustom );
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        if ( [self.videoDevice isExposureModeSupported:mode] ) {
            self.videoDevice.exposureMode = mode;
        }
        else {
            NSLog( @"Exposure mode %@ is not supported. Exposure mode is %@.", [self stringFromExposureMode:mode], [self stringFromExposureMode:self.videoDevice.exposureMode] );
            self.exposureModeControl.selectedSegmentIndex = [self.exposureModes indexOfObject:@(self.videoDevice.exposureMode)];
        }
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (IBAction)changeExposureDuration:(id)sender
{
    UISlider *control = sender;
    NSError *error = nil;
    
    double p = pow( control.value, kExposureDurationPower ); // Apply power function to expand slider's low-end range
    double minDurationSeconds = MAX( CMTimeGetSeconds( self.videoDevice.activeFormat.minExposureDuration ), kExposureMinimumDuration );
    double maxDurationSeconds = 1.0/3.0;//CMTimeGetSeconds( self.videoDevice.activeFormat.maxExposureDuration );
    double newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
    //    if (newDurationSeconds > 0.330918 && newDurationSeconds < 0.357056)
    //    {
    //        NSLog(@"newDurationSeconds\t%f", newDurationSeconds);
    //        double newDurationSeconds = 0.3309180;
    //    }
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        [self.videoDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds( newDurationSeconds, 1000*1000*1000 )  ISO:AVCaptureISOCurrent completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (IBAction)changeTorchLevel:(UISlider *)sender
{
    @try {
        __autoreleasing NSError *error;
        if ([_videoDevice lockForConfiguration:&error] && ([[NSProcessInfo processInfo] thermalState] != NSProcessInfoThermalStateCritical && [[NSProcessInfo processInfo] thermalState] != NSProcessInfoThermalStateSerious)) {
            if (sender.value != 0)
                [self->_videoDevice setTorchModeOnWithLevel:sender.value error:&error];
            else
                [self->_videoDevice setTorchMode:AVCaptureTorchModeOff];
        } else {
            NSLog(@"Unable to adjust torch level; thermal state: %lu", [[NSProcessInfo processInfo] thermalState]);
        }
    } @catch (NSException *exception) {
        NSLog(@"AVCaptureDevice lockForConfiguration returned error\t%@", exception);
    } @finally {
        [_videoDevice unlockForConfiguration];
    }
}

- (IBAction)changeISO:(id)sender
{
    UISlider *control = sender;
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        @try {
            [self.videoDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:control.value completionHandler:nil];
        } @catch (NSException *exception) {
            [self.videoDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:AVCaptureISOCurrent completionHandler:nil];
        } @finally {
            
        }
        
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (IBAction)changeExposureTargetBias:(id)sender
{
    UISlider *control = sender;
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        [self.videoDevice setExposureTargetBias:control.value completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

static float (^ _Nonnull rescale)(float, float, float, float, float) = ^ float (float old_value, float old_min, float old_max, float new_min, float new_max) {
    float scaled_value = (new_max - new_min) * (old_value - old_min) / (old_max - old_min) + new_min;
    return scaled_value;
};

- (IBAction)changeVideoZoomFactor:(UISlider *)sender {
    if (![self.videoDevice isRampingVideoZoom] && (sender.value != self.videoDevice.videoZoomFactor)) {
        @try {
            ^{
                __block NSError * e = nil;
                ^{
                    return ([self.videoDevice lockForConfiguration:&e] && !e)
                    ? ^{
                        [self.videoDevice setVideoZoomFactor:propertyValueFromNormalizedControlValue(sender.value, self.videoDevice.minAvailableVideoZoomFactor, self.videoDevice.activeFormat.videoMaxZoomFactor)];
                    }()
                    : ^{
                        NSException * exception = [NSException
                                                   exceptionWithName:e.domain
                                                   reason:e.localizedDescription
                                                   userInfo:@{@"Error Code" : @(e.code)}];
                        @throw exception;
                    }();
                }();
            }();
        } @catch (NSException * exception) {
            NSLog(@"Error configuring camera:\n\t%@\n\t%@\n\t%lu",
                  exception.name,
                  exception.reason,
                  ((NSNumber *)[exception.userInfo valueForKey:@"Error Code"]).unsignedIntegerValue);
        } @finally {
            [self.videoDevice unlockForConfiguration];
        }
    }
}

- (IBAction)changeWhiteBalanceMode:(id)sender
{
    UISegmentedControl *control = sender;
    AVCaptureWhiteBalanceMode mode = (AVCaptureWhiteBalanceMode)[self.whiteBalanceModes[control.selectedSegmentIndex] intValue];
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        if ( [self.videoDevice isWhiteBalanceModeSupported:mode] ) {
            self.videoDevice.whiteBalanceMode = mode;
        }
        else {
            NSLog( @"White balance mode %@ is not supported. White balance mode is %@.", [self stringFromWhiteBalanceMode:mode], [self stringFromWhiteBalanceMode:self.videoDevice.whiteBalanceMode] );
            self.whiteBalanceModeControl.selectedSegmentIndex = [self.whiteBalanceModes indexOfObject:@(self.videoDevice.whiteBalanceMode)];
        }
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)gains
{
    NSError *error = nil;
    
    if ( [self.videoDevice lockForConfiguration:&error] ) {
        AVCaptureWhiteBalanceGains normalizedGains = [self normalizedGains:gains]; // Conversion can yield out-of-bound values, cap to limits
        [self.videoDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:normalizedGains completionHandler:nil];
        [self.videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"Could not lock device for configuration: %@", error );
    }
}

- (IBAction)changeTemperature:(id)sender
{
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .temperature = self.temperatureSlider.value,
        .tint = self.tintSlider.value,
    };
    
    [self setWhiteBalanceGains:[self.videoDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint]];
}

- (IBAction)changeTint:(id)sender
{
    AVCaptureWhiteBalanceTemperatureAndTintValues temperatureAndTint = {
        .temperature = self.temperatureSlider.value,
        .tint = self.tintSlider.value,
    };
    
    [self setWhiteBalanceGains:[self.videoDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:temperatureAndTint]];
}

- (IBAction)lockWithGrayWorld:(id)sender
{
    [self setWhiteBalanceGains:self.videoDevice.grayWorldDeviceWhiteBalanceGains];
}

- (AVCaptureWhiteBalanceGains)normalizedGains:(AVCaptureWhiteBalanceGains)gains
{
    AVCaptureWhiteBalanceGains g = gains;
    
    g.redGain = MAX( 1.0, g.redGain );
    g.greenGain = MAX( 1.0, g.greenGain );
    g.blueGain = MAX( 1.0, g.blueGain );
    
    g.redGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.redGain );
    g.greenGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.greenGain );
    g.blueGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.blueGain );
    
    return g;
}

//- (AVCaptureWhiteBalanceGains)normalizedGains:(AVCaptureWhiteBalanceGains)gains
//{
//    AVCaptureWhiteBalanceGains g = gains;
//
//    g.redGain = MIN( 1.0, self.videoDevice.maxWhiteBalanceGain );
//    g.greenGain = MIN( 1.0, self.videoDevice.maxWhiteBalanceGain );
//    g.blueGain = MIN( 1.0, self.videoDevice.maxWhiteBalanceGain );
//
//        g.redGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.redGain );
//        g.greenGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.greenGain );
//        g.blueGain = MIN( self.videoDevice.maxWhiteBalanceGain, g.blueGain );
//
//    return g;
//}

- (void)resetAppDefaults
{
    NSLog(@"%s\n", __PRETTY_FUNCTION__);
    // Set camera settings to app defaults
    //            dispatch_async( self.sessionQueue, ^{
    //                [self.videoDevice lockForConfiguration:nil];
    //                [self.session beginConfiguration];
    //                //
    //                for (AVCaptureInput * input in self.session.inputs)
    //                    [self.session removeInput:input];
    //                for (AVCaptureOutput * output in self.previewView.session.outputs)
    //                    [self.session removeOutput:output];
    //                for (AVCaptureConnection * connection in self.session.connections)
    //                    [self.session removeConnection:connection];
    //                [self.session commitConfiguration];
    //                [self.videoDevice unlockForConfiguration];
    //                [self.session stopRunning];
    //                dispatch_async(dispatch_get_main_queue(), ^{
    //                    [self viewDidLoad];
    //                });
    //            [self removeObservers];
    
    dispatch_async( dispatch_get_main_queue(), ^{
        [self configureManualHUD];
    });
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        [self viewDidLoad];
    //    });
}

- (IBAction)setPreset:(UIButton *)sender {
    //    [self resetAppDefaults];
    dispatch_async(dispatch_get_main_queue(), ^{
        UISlider *control = self.exposureModeControl;
        NSError *error = nil;
        
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            self.exposureModeControl.selectedSegmentIndex = 2;
            [self changeExposureMode:control];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
        
        control = self.exposureDurationSlider;
        error = nil;
        
        double p = pow( control.value, kExposureDurationPower ); // Apply power function to expand slider's low-end range
        //        double minDurationSeconds = MAX( CMTimeGetSeconds( self.videoDevice.activeFormat.minExposureDuration ), kExposureMinimumDuration );
        double maxDurationSeconds = 1.0/3.0;//CMTimeGetSeconds( self.videoDevice.activeFormat.maxExposureDuration );
        //        double newDurationSeconds = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
        //    if (newDurationSeconds > 0.330918 && newDurationSeconds < 0.357056)
        //    {
        //        NSLog(@"newDurationSeconds\t%f", newDurationSeconds);
        //        double newDurationSeconds = 0.3309180;
        //    }
        
        if ( [self.videoDevice lockForConfiguration:&error] ) {
            [self.videoDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds( maxDurationSeconds, 1000*1000*1000 )  ISO:AVCaptureISOCurrent completionHandler:nil];
            [self.videoDevice unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
        
        self.manualHUD.hidden = FALSE;
        [self toggleControlViewVisibility:@[self.manualHUDExposureView] hide:NO];
        //
        //        control = self.ISOSlider;
        //        error = nil;
        //
        //        if ( [self.videoDevice lockForConfiguration:&error] ) {
        //            [self.videoDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:self.videoDevice.activeFormat.maxISO completionHandler:nil];
        //            [self.videoDevice unlockForConfiguration];
        //        }
        //        else {
        //            NSLog( @"Could not lock device for configuration: %@", error );
        //        }
        //
        //
        //        [sender setTag:(sender.tag == 1) ? 0 : 1];
        //        NSLog(@"sender.tag == %lu\n", sender.tag);
        //        [self.exposureModeControl setSelectedSegmentIndex:2];
        //                    [self changeExposureMode:self.exposureModeControl];
    });
    //    if (sender.tag == 0)
    //    {
    //        // Set camera to optimal exposure duration/ISO settings
    //        dispatch_async( dispatch_get_main_queue(), ^{
    ////            [self.videoDevice lockForConfiguration:nil];
    //
    ////            [self.ISOSlider setValue:self.ISOSlider.maximumValue];
    ////            [self.exposureDurationSlider setValue:self.exposureDurationSlider.maximumValue];
    ////            [self changeISO:self.ISOSlider];
    ////            [self changeExposureDuration:self.exposureDurationSlider];
    ////            [self.videoDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds( (1.0/3.0), 1000*1000*1000 )
    ////                                                             ISO:averageISO
    ////                                               completionHandler:nil];
    //        });
    ////            [self.videoDevice unlockForConfiguration];
    //
    //    }
}


#pragma mark Recording Movies

- (IBAction)toggleMovieRecording:(id)sender
{
    // Retrieve the video preview layer's video orientation on the main queue before entering the session queue. We do this to ensure UI
    // elements are accessed on the main thread and session configuration is done on the session queue.
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
    AVCaptureVideoOrientation previewLayerVideoOrientation = previewLayer.connection.videoOrientation;
    if ( ! self.movieFileOutput.isRecording ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [sender setAlpha:.15];
        });
        
        dispatch_async( self.sessionQueue, ^{
            if ( [UIDevice currentDevice].isMultitaskingSupported ) {
                self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }
            AVCaptureConnection *movieConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            movieConnection.videoOrientation = previewLayerVideoOrientation;
            
            NSString *outputFileName = [NSProcessInfo processInfo].globallyUniqueString;
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mov"]];
            [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [sender setAlpha:1.0];
        });
        dispatch_async( self.sessionQueue, ^{
            [self.movieFileOutput stopRecording];
        });
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    // Enable the Record button to let the user stop the recording
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    // Note that currentBackgroundRecordingID is used to end the background task associated with this recording.
    // This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's isRecording property
    // is back to NO — which happens sometime after this method returns.
    // Note: Since we use a unique file path for each recording, a new recording will not overwrite a recording currently being saved.
    UIBackgroundTaskIdentifier currentBackgroundRecordingID = self.backgroundRecordingID;
    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    
    dispatch_block_t cleanup = ^{
        if ( [[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path] ) {
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
        }
        
        if ( currentBackgroundRecordingID != UIBackgroundTaskInvalid ) {
            [[UIApplication sharedApplication] endBackgroundTask:currentBackgroundRecordingID];
        }
    };
    
    BOOL success = YES;
    
    if ( error ) {
        NSLog( @"Error occurred while capturing movie: %@", error );
        success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
    }
    if ( success ) {
        // Check authorization status
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if ( status == PHAuthorizationStatusAuthorized ) {
                // Save the movie file to the photo library and cleanup
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    // In iOS 9 and later, it's possible to move the file into the photo library without duplicating the file data.
                    // This avoids using double the disk space during save, which can make a difference on devices with limited free disk space.
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    PHAssetCreationRequest *changeRequest = [PHAssetCreationRequest creationRequestForAsset];
                    [changeRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
                } completionHandler:^( BOOL success, NSError *error ) {
                    if ( ! success ) {
                        NSLog( @"Could not save movie to photo library: %@", error );
                    }
                    cleanup();
                }];
            }
            else {
                cleanup();
            }
        }];
    }
    else {
        cleanup();
    }
    
    // Enable the Camera and Record buttons to let the user switch camera and start another recording
    dispatch_async( dispatch_get_main_queue(), ^{
        // Only enable the ability to change camera if the device has more than one camera
        //		self.cameraButton.enabled = ( self.videoDeviceDiscoverySession.devices.count > 1 );
        self.recordButton.alpha = 1.0;
        // TO-DO: Change button image to record.circle.fill
        //		[self.recordButton setTitle:NSLocalizedString( @"Record", @"Recording button record title" ) forState:UIControlStateNormal];
        //		self.captureModeControl.enabled = YES;
    });
}

#pragma mark KVO and Notifications

- (void)addObservers
{
    [self addObserver:self forKeyPath:@"session.running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    [self addObserver:self forKeyPath:@"videoDevice.focusMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:FocusModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.lensPosition" options:NSKeyValueObservingOptionNew context:LensPositionContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:ExposureModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureDuration" options:NSKeyValueObservingOptionNew context:ExposureDurationContext];
    [self addObserver:self forKeyPath:@"videoDevice.ISO" options:NSKeyValueObservingOptionNew context:ISOContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureTargetBias" options:NSKeyValueObservingOptionNew context:ExposureTargetBiasContext];
    [self addObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" options:NSKeyValueObservingOptionNew context:ExposureTargetOffsetContext];
    [self addObserver:self forKeyPath:@"videoDevice.videoZoomFactor" options:NSKeyValueObservingOptionNew context:VideoZoomFactorContext];
    
    [self addObserver:self forKeyPath:@"videoDevice.whiteBalanceMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:WhiteBalanceModeContext];
    [self addObserver:self forKeyPath:@"videoDevice.deviceWhiteBalanceGains" options:NSKeyValueObservingOptionNew context:DeviceWhiteBalanceGainsContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDevice];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self removeObserver:self forKeyPath:@"session.running" context:SessionRunningContext];
    [self removeObserver:self forKeyPath:@"videoDevice.focusMode" context:FocusModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.lensPosition" context:LensPositionContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureMode" context:ExposureModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureDuration" context:ExposureDurationContext];
    [self removeObserver:self forKeyPath:@"videoDevice.ISO" context:ISOContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureTargetBias" context:ExposureTargetBiasContext];
    [self removeObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" context:ExposureTargetOffsetContext];
    [self removeObserver:self forKeyPath:@"videoDevice.videoZoomFactor" context:VideoZoomFactorContext];
    
    [self removeObserver:self forKeyPath:@"videoDevice.whiteBalanceMode" context:WhiteBalanceModeContext];
    [self removeObserver:self forKeyPath:@"videoDevice.deviceWhiteBalanceGains" context:DeviceWhiteBalanceGainsContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    if ( context == FocusModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureFocusMode newMode = [newValue intValue];
            dispatch_async( dispatch_get_main_queue(), ^{
                self.focusModeControl.selectedSegmentIndex = [self.focusModes indexOfObject:@(newMode)];
                self.lensPositionSlider.enabled = ( newMode == AVCaptureFocusModeLocked );
                self.lensPositionSlider.selected = ( newMode == AVCaptureFocusModeLocked );
                
                if ( oldValue && oldValue != [NSNull null] ) {
                    AVCaptureFocusMode oldMode = [oldValue intValue];
                    NSLog( @"focus mode: %@ -> %@", [self stringFromFocusMode:oldMode], [self stringFromFocusMode:newMode] );
                }
                else {
                    NSLog( @"focus mode: %@", [self stringFromFocusMode:newMode] );
                }
            } );
        }
    }
    else if ( context == LensPositionContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureFocusMode focusMode = self.videoDevice.focusMode;
            float newLensPosition = [newValue floatValue];
            dispatch_async( dispatch_get_main_queue(), ^{
                if ( focusMode != AVCaptureFocusModeLocked ) {
                    self.lensPositionSlider.value = newLensPosition;
                }
                
                self.lensPositionValueLabel.text = [NSString stringWithFormat:@"%.1f", newLensPosition];
            } );
        }
    }
    else if ( context == ExposureModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureExposureMode newMode = [newValue intValue];
            if ( oldValue && oldValue != [NSNull null] ) {
                AVCaptureExposureMode oldMode = [oldValue intValue];
                
                if ( oldMode != newMode && oldMode == AVCaptureExposureModeCustom ) {
                    NSError *error = nil;
                    if ( [self.videoDevice lockForConfiguration:&error] ) {
                        self.videoDevice.activeVideoMaxFrameDuration = kCMTimeInvalid;
                        self.videoDevice.activeVideoMinFrameDuration = kCMTimeInvalid;
                        [self.videoDevice unlockForConfiguration];
                    }
                    else {
                        NSLog( @"Could not lock device for configuration: %@", error );
                    }
                }
            }
            dispatch_async( dispatch_get_main_queue(), ^{
                
                self.exposureModeControl.selectedSegmentIndex = [self.exposureModes indexOfObject:@(newMode)];
                self.exposureDurationSlider.enabled = ( newMode == AVCaptureExposureModeCustom );
                self.ISOSlider.enabled = ( newMode == AVCaptureExposureModeCustom );
                self.exposureDurationSlider.selected = ( newMode == AVCaptureExposureModeCustom );
                self.ISOSlider.selected = ( newMode == AVCaptureExposureModeCustom );
                
                
                if ( oldValue && oldValue != [NSNull null] ) {
                    AVCaptureExposureMode oldMode = [oldValue intValue];
                    NSLog( @"exposure mode: %@ -> %@", [self stringFromExposureMode:oldMode], [self stringFromExposureMode:newMode] );
                }
                else {
                    NSLog( @"exposure mode: %@", [self stringFromExposureMode:newMode] );
                }
            } );
        }
    }
    else if ( context == ExposureDurationContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            double newDurationSeconds = CMTimeGetSeconds( [newValue CMTimeValue] );
            AVCaptureExposureMode exposureMode = self.videoDevice.exposureMode;
            
            double minDurationSeconds = MAX( CMTimeGetSeconds( self.videoDevice.activeFormat.minExposureDuration ), kExposureMinimumDuration );
            double maxDurationSeconds = 1.0/3.0; //CMTimeGetSeconds( self.videoDevice.activeFormat.maxExposureDuration );
            // Map from duration to non-linear UI range 0-1
            double p = ( newDurationSeconds - minDurationSeconds ) / ( maxDurationSeconds - minDurationSeconds ); // Scale to 0-1
            dispatch_async( dispatch_get_main_queue(), ^{
                if ( exposureMode != AVCaptureExposureModeCustom ) {
                    self.exposureDurationSlider.value = pow( p, 1 / kExposureDurationPower ); // Apply inverse power
                }
                if ( newDurationSeconds < 1 ) {
                    int digits = MAX( 0, 2 + floor( log10( newDurationSeconds ) ) );
                    self.exposureDurationValueLabel.text = [NSString stringWithFormat:@"1/%.*f", digits, 1/newDurationSeconds];
                }
                else {
                    self.exposureDurationValueLabel.text = [NSString stringWithFormat:@"%.2f", newDurationSeconds];
                }
            } );
        }
    }
    else if ( context == ISOContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newISO = [newValue floatValue];
            AVCaptureExposureMode exposureMode = self.videoDevice.exposureMode;
            
            dispatch_async( dispatch_get_main_queue(), ^{
                if ( exposureMode != AVCaptureExposureModeCustom ) {
                    self.ISOSlider.value = newISO;
                }
                self.ISOValueLabel.text = [NSString stringWithFormat:@"%i", (int)newISO];
            } );
        }
    }
    else if ( context == ExposureTargetBiasContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newExposureTargetBias = [newValue floatValue];
            dispatch_async( dispatch_get_main_queue(), ^{
                self.exposureTargetBiasValueLabel.text = [NSString stringWithFormat:@"%.1f", newExposureTargetBias];
            } );
        }
    }
    else if ( context == ExposureTargetOffsetContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            float newExposureTargetOffset = [newValue floatValue];
            dispatch_async( dispatch_get_main_queue(), ^{
                self.exposureTargetOffsetSlider.value = newExposureTargetOffset;
                self.exposureTargetOffsetValueLabel.text = [NSString stringWithFormat:@"%.1f", newExposureTargetOffset];
            } );
        }
    }
    else if ( context == VideoZoomFactorContext) {
        if ( newValue && newValue != [NSNull null] ) {
            dispatch_async( dispatch_get_main_queue(), ^{
                printf("newZoomFactor == %f\t\t videoZoomFactor == %f\n\n", [newValue floatValue], self.videoDevice.videoZoomFactor);
                [self.videoZoomFactorSlider setValue:normalizedControlValueFromPropertyValue([newValue floatValue], self.videoDevice.minAvailableVideoZoomFactor, self.videoDevice.activeFormat.videoMaxZoomFactor)];
            });
        }
    }
    else if ( context == WhiteBalanceModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureWhiteBalanceMode newMode = [newValue intValue];
            dispatch_async( dispatch_get_main_queue(), ^{
                self.whiteBalanceModeControl.selectedSegmentIndex = [self.whiteBalanceModes indexOfObject:@(newMode)];
                self.temperatureSlider.enabled = ( newMode == AVCaptureWhiteBalanceModeLocked );
                self.tintSlider.enabled = ( newMode == AVCaptureWhiteBalanceModeLocked );
                
                if ( oldValue && oldValue != [NSNull null] ) {
                    AVCaptureWhiteBalanceMode oldMode = [oldValue intValue];
                    NSLog( @"white balance mode: %@ -> %@", [self stringFromWhiteBalanceMode:oldMode], [self stringFromWhiteBalanceMode:newMode] );
                }
            } );
        }
    }
    else if ( context == DeviceWhiteBalanceGainsContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureWhiteBalanceGains newGains;
            [newValue getValue:&newGains];
            AVCaptureWhiteBalanceTemperatureAndTintValues newTemperatureAndTint = [self.videoDevice temperatureAndTintValuesForDeviceWhiteBalanceGains:newGains];
            AVCaptureWhiteBalanceMode whiteBalanceMode = self.videoDevice.whiteBalanceMode;
            dispatch_async( dispatch_get_main_queue(), ^{
                if ( whiteBalanceMode != AVCaptureExposureModeLocked ) {
                    self.temperatureSlider.value = newTemperatureAndTint.temperature;
                    self.tintSlider.value = newTemperatureAndTint.tint;
                }
                
                //                self.temperatureValueLabel.text = [NSString stringWithFormat:@"%i", (int)newTemperatureAndTint.temperature];
                //                self.tintValueLabel.text = [NSString stringWithFormat:@"%i", (int)newTemperatureAndTint.tint];
            } );
        }
    }
    else if ( context == SessionRunningContext ) {
        BOOL isRunning = NO;
        if ( newValue && newValue != [NSNull null] ) {
            isRunning = [newValue boolValue];
        }
        dispatch_async( dispatch_get_main_queue(), ^{
            //			self.cameraButton.enabled = isRunning && ( self.videoDeviceDiscoverySession.devices.count > 1 );
            self.recordButton.enabled = isRunning;
        } );
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:self.videoDevice.focusMode exposeWithMode:self.videoDevice.exposureMode atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog( @"Capture session runtime error: %@", error );
    
    if ( error.code == AVErrorMediaServicesWereReset ) {
        dispatch_async( self.sessionQueue, ^{
            // If we aren't trying to resume the session, try to restart it, since it must have been stopped due to an error (see -[resumeInterruptedSession:])
            if ( self.isSessionRunning ) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
            else {
                dispatch_async( dispatch_get_main_queue(), ^{
                    self.resumeButton.hidden = NO;
                } );
            }
        } );
    }
    else {
        self.resumeButton.hidden = NO;
    }
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    NSLog( @"Capture session was interrupted with reason %ld", (long)reason );
    
    if ( reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
        reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient ) {
        // Simply fade-in a button to enable the user to try to resume the session running
        self.resumeButton.hidden = NO;
        self.resumeButton.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.resumeButton.alpha = 1.0;
        }];
    }
    else if ( reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps ) {
        // Simply fade-in a label to inform the user that the camera is unavailable
        self.cameraUnavailableImageView.hidden = NO;
        self.cameraUnavailableImageView.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.cameraUnavailableImageView.alpha = 1.0;
        }];
    }
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    NSLog( @"Capture session interruption ended" );
    
    if ( ! self.resumeButton.hidden ) {
        [UIView animateWithDuration:0.25 animations:^{
            self.resumeButton.alpha = 0.0;
        } completion:^( BOOL finished ) {
            self.resumeButton.hidden = YES;
        }];
    }
    if ( ! self.cameraUnavailableImageView.hidden ) {
        [UIView animateWithDuration:0.25 animations:^{
            self.cameraUnavailableImageView.alpha = 0.0;
        } completion:^( BOOL finished ) {
            self.cameraUnavailableImageView.hidden = YES;
        }];
    }
}

- (NSString *)stringFromFocusMode:(AVCaptureFocusMode)focusMode
{
    NSString *string = @"INVALID FOCUS MODE";
    
    if ( focusMode == AVCaptureFocusModeLocked ) {
        string = @"Locked";
    }
    else if ( focusMode == AVCaptureFocusModeAutoFocus ) {
        string = @"Auto";
    }
    else if ( focusMode == AVCaptureFocusModeContinuousAutoFocus ) {
        string = @"ContinuousAuto";
    }
    
    return string;
}

- (NSString *)stringFromExposureMode:(AVCaptureExposureMode)exposureMode
{
    NSString *string = @"INVALID EXPOSURE MODE";
    
    if ( exposureMode == AVCaptureExposureModeLocked ) {
        string = @"Locked";
    }
    else if ( exposureMode == AVCaptureExposureModeAutoExpose ) {
        string = @"Auto";
    }
    else if ( exposureMode == AVCaptureExposureModeContinuousAutoExposure ) {
        string = @"ContinuousAuto";
    }
    else if ( exposureMode == AVCaptureExposureModeCustom ) {
        string = @"Custom";
    }
    
    return string;
}

- (NSString *)stringFromWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    NSString *string = @"INVALID WHITE BALANCE MODE";
    
    if ( whiteBalanceMode == AVCaptureWhiteBalanceModeLocked ) {
        string = @"Locked";
    }
    else if ( whiteBalanceMode == AVCaptureWhiteBalanceModeAutoWhiteBalance ) {
        string = @"Auto";
    }
    else if ( whiteBalanceMode == AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance ) {
        string = @"ContinuousAuto";
    }
    
    return string;
}

@end
