#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static BOOL BHTIsTwitterBundle(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    if (bundleID == nil) {
        return NO;
    }

    return [bundleID hasPrefix:@"com.atebits.Tweetie2"];
}

static void BHTRequestCameraPermissionIfNeeded(void) {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    if (status == AVAuthorizationStatusNotDetermined) {
        NSLog(@"[BHTwitter] Requesting camera permission");

        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            NSLog(@"[BHTwitter] Camera permission granted: %@", granted ? @"YES" : @"NO");
        }];
    } else {
        NSLog(@"[BHTwitter] Camera permission already determined: %ld", (long)status);
    }
}

static void BHTRequestMicrophonePermissionIfNeeded(void) {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];

    if (status == AVAuthorizationStatusNotDetermined) {
        NSLog(@"[BHTwitter] Requesting microphone permission");

        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            NSLog(@"[BHTwitter] Microphone permission granted: %@", granted ? @"YES" : @"NO");
        }];
    } else {
        NSLog(@"[BHTwitter] Microphone permission already determined: %ld", (long)status);
    }
}

static void BHTRequestMediaPermissionsIfNeeded(void) {
    if (!BHTIsTwitterBundle()) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BHTRequestCameraPermissionIfNeeded();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BHTRequestMicrophonePermissionIfNeeded();
            });
        });
    });
}

static void BHTApplicationDidBecomeActive(NSNotification *notification) {
    BHTRequestMediaPermissionsIfNeeded();
}

%ctor {
    @autoreleasepool {
        if (!BHTIsTwitterBundle()) {
            return;
        }

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            BHTApplicationDidBecomeActive(notification);
        }];

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            BHTRequestMediaPermissionsIfNeeded();
        }
    }
}
