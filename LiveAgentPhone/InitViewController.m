//
//  InitViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 16.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import "InitViewController.h"
#import "Constants.h"
#import <AFNetworking/AFNetworking.h>
#import <NotificationCenter/NotificationCenter.h>
#import <AVFoundation/AVFoundation.h>
#import "Net.h"
#import "AppDelegate.h"
#import "LoginViewController.h"
#import <UserNotifications/UserNotifications.h>
#import "Api.h"

@interface InitViewController () {
    @private
    NSString *localDeviceId;
    NSString *remoteDeviceId;
    NSString *phoneId;
    NSString *remotePushToken;
    NSString *generatedPushToken;
    AppDelegate *appDelegate;
}
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *labelError;
@property (weak, nonatomic) IBOutlet UIButton *buttonGoToLogin;
@property (weak, nonatomic) IBOutlet UIButton *buttonRetry;

@end

@implementation InitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    [[self labelError] setHidden:NO];
    localDeviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLocalNotification:) name:localNotificationIntoInit object:nil];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startInit];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)existUrlEmailToken {
    NSUserDefaults *memory = [NSUserDefaults standardUserDefaults];
    if ([memory objectForKey:memoryKeyUrl] == nil ||
        [memory objectForKey:memoryKeyEmail] == nil ||
        [memory objectForKey:memoryKeyApikey] == nil) {
        return NO;
    }
    return YES;
}

- (void) startInit {
    NSLog(@"Starting init...");
    [self showInitialState]; // hide error message and show activity indicator
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                      if (error) {
                                          NSLog(@"Error: Request authorization failed!");
                                          return;
                                      }
                                      if (granted) {
                                          // all permissions granted
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              [self permissionsGranted];
                                          });
                                      }
                                  }];
        } else {
            [self showPermissionsError];
        }
    }];
}

- (void)permissionsGranted {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [userDefaults objectForKey:memoryKeyApikey];
    if (apiKey == nil) {
        [self goToLogin];
    } else {
        [self getPhone];
    }
}

- (void)showPermissionsError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *errMsg = stringPermissionDenied;
        [self showError:errMsg];
    });
}

- (void)getPhone {
    if (phoneId != nil && [phoneId length] != 0) {
        // if phone has been already loaded, just skip calling '/phone' and check 'params' we've got from that
        [self putPhoneParams];
        return;
    }
    [Api getPhone:^(NSDictionary* responseObject) {
        NSDictionary *response = responseObject;
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *requiredKey;
        NSString *requiredValue;
        // SIP id
        requiredKey = @"id";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            phoneId = requiredValue;
            [userDefaults setObject:requiredValue forKey:memoryKeySipId];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing PHONE value: '%@'", requiredKey]];
            return;
        }
        // SIP number
        requiredKey = @"number";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            [userDefaults setObject:requiredValue forKey:memoryKeySipNumber];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing SIP value: '%@'", requiredKey]];
            return;
        }
        // SIP host
        requiredKey = @"connection_host";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            [userDefaults setObject:requiredValue forKey:memoryKeySipHost];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing SIP value: '%@'", requiredKey]];
            return;
        }
        // SIP user
        requiredKey = @"connection_user";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            [userDefaults setObject:requiredValue forKey:memoryKeySipUser];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing SIP value: '%@'", requiredKey]];
            return;
        }
        // SIP password
        requiredKey = @"connection_pass";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            [userDefaults setObject:requiredValue forKey:memoryKeySipPassword];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing SIP value: '%@'", requiredKey]];
            return;
        }
        [userDefaults synchronize];
        // parse 'params' object from response
        NSString *paramsString = [response objectForKey:@"params"];
        if (paramsString != nil && [paramsString length] > 0) {
            NSData *objectData = [paramsString dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *params = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:nil];
            if (params != nil && [params count] > 0) {
                remoteDeviceId = [params objectForKey:@"deviceId"];
                remotePushToken = [params objectForKey:@"pushToken"];
            }
        }
        // to check if remote pushtoken exists and is equal to pushtoken of this device then we must invoke voip push registration
        [self putPhoneParams];
    } failure:^(NSString *errorMessage, BOOL unauthorized) {
        if (unauthorized) {
            [self goToLogin];
        } else {
            [self showError:errorMessage];
        }
    }];
}

- (void)putPhoneParams {
    NSLog(@"Registering voip push token in init...");
    [appDelegate registerVoipNotifications];
    // appdelegate will bring push token via 'afterPushRegistration' callback
}

- (void)onLocalNotification:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *dict = [notification object];
        if (dict == nil) {
            [self showError:@"Error: notification object is NULL"];
            return;
        }
        NSString *error = [dict objectForKey:@"error"];
        if (error != nil) {
            [self showError:[NSString stringWithFormat:@"Error: %@", error]];
            return;
        }
        generatedPushToken = [dict objectForKey:@"pushToken"];
        //    NSLog(@"Push token is: '%@'", pushToken);
        if (remotePushToken != nil && [remotePushToken isEqualToString:generatedPushToken]) {
            NSLog(@"Push token of this device has been already registered!");
            [self goToHome];
            return;
        }
        [Api updatePhoneParams:phoneId pushToken:generatedPushToken deviceId:localDeviceId success:^() {
            [self goToHome];
        } failure:^(NSString *errorMessage) {
            [self showError:errorMessage];
        }];
    });
}

- (void)goToHome {
    [self showInitialState];
    [self performSegueWithIdentifier:@"goToHome" sender:nil];
}

- (void)goToLogin {
    phoneId = nil;
    localDeviceId = nil;
    remoteDeviceId = nil;
    remotePushToken = nil;
    generatedPushToken = nil;
    [self showInitialState];
    [self performSegueWithIdentifier:@"goToLogin" sender:nil];
}

- (void)showInitialState {
    [[self labelError] setHidden:YES];
    [[self buttonGoToLogin] setHidden:YES];
    [[self buttonRetry] setHidden:YES];
    [[self labelError] setText:@""];
    [[self activityIndicator] setHidden:NO];
}

- (void)showError:(NSString *) errorMessage {
    [[self activityIndicator] setHidden:YES];
    [[self buttonGoToLogin] setHidden:NO];
    [[self buttonRetry] setHidden:NO];
    [[self labelError] setHidden:NO];
    [[self labelError] setText:errorMessage];
    [[self labelError] sizeToFit];
}

- (IBAction)onClickGoToLogin:(id)sender {
    [self goToLogin];
}

- (IBAction)onClickRetry:(id)sender {
    [self startInit];
}

- (IBAction)unwindToInit:(UIStoryboardSegue *)unwindSegue {
    
}

@end
