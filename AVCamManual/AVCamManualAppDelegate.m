/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Application delegate.
*/

#import "AVCamManualAppDelegate.h"

@implementation AVCamManualAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );

    
    return TRUE;
}

+ (AVCamManualAppDelegate *)sharedAppDelegate
{
    return (AVCamManualAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (id<MovieAppEventDelegate>)movieAppEventDelegate
{
    return self.movieAppEventDelegate;
}

- (void)setMovieAppEventDelegate:(id<MovieAppEventDelegate>)movieAppEventDelegate
{
    self.movieAppEventDelegate = movieAppEventDelegate;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    dispatch_async( self.sessionQueue, ^{
        [self.movieAppEventDelegate.movieFileOutput stopRecording];
    });
}

@end
