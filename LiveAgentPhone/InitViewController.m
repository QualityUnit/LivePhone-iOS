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
    NSString *phoneId;
    NSString *remotePushToken;
    NSString *remoteApnsToken;
    NSString *generatedPushToken;
    NSString *generatedApnsToken;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLocalNotification:) name:localNotificationIntoInit object:nil];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startInit];
//    NSUserDefaults *memory = [NSUserDefaults standardUserDefaults];
//    [memory removeObjectForKey:memoryKeyApikey];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) startInit {
    [self showInitialState]; // hide error message and show activity indicator
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [userDefaults objectForKey:memoryKeyApikey];
    NSString *apiKeyId = [userDefaults objectForKey:memoryKeyApikeyId];
    if (apiKey == nil || apiKeyId == nil) {
        [self goToLogin];
    } else {
        [self getPhone];
    }
}

- (void)getPhone {
    if (phoneId != nil && [phoneId length] != 0) {
        // if phone has been already loaded, just skip calling GET '/phone' and check 'params' we've got from that
        [appDelegate registerPushNotifications];
        return;
    }
    [Api getPhone:^(NSDictionary* responseObject) {
        NSDictionary *response = responseObject;
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *requiredKey;
        NSString *requiredValue;
        // phone ID
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
        // agent ID
        requiredKey = @"agent_id";
        requiredValue = [response objectForKey:requiredKey];
        if (requiredValue != nil && [requiredValue length] > 0) {
            [userDefaults setObject:requiredValue forKey:memoryKeyAgentId];
        } else {
            [self showError:[NSString stringWithFormat:@"Missing agent ID: '%@'", requiredKey]];
            return;
        }
        [userDefaults synchronize];
        // parse 'params' object from response
        NSString *paramsString = [response objectForKey:@"params"];
        if (paramsString != nil && [paramsString length] > 0) {
            NSData *objectData = [paramsString dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *params = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:nil];
            if (params != nil && [params count] > 0) {
                remotePushToken = [params objectForKey:@"pushToken"];
                remoteApnsToken = [params objectForKey:@"apnsToken"];
            }
        }
        // to check if remote pushtoken exists and is equal to pushtoken of this device then we must invoke voip push registration
        [appDelegate registerPushNotifications];
    } failure:^(NSString *errorMessage, BOOL unauthorized) {
        if (unauthorized) {
            [self goToLogin];
        } else {
            [self showError:errorMessage];
        }
    }];
}

- (void)onLocalNotification:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *dict = [notification object];
        if (dict == nil) {
            [self showError:@"Error: in-app NSNotification object is NULL"];
            return;
        }
        NSString *error = [dict objectForKey:@"error"];
        if (error != nil) {
            [self showError:[NSString stringWithFormat:@"Error: %@", error]];
            return;
        }
        generatedPushToken = [dict objectForKey:@"pushToken"];
        generatedApnsToken = [dict objectForKey:@"apnsToken"];
//        if (remotePushToken != nil && [remotePushToken isEqualToString:generatedPushToken]) {
//            NSLog(@"Push token and Apns token of this device has been already registered!");
//            [self goToHome];
//            return;
//        }
        NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        [Api updatePhoneParams:phoneId pushToken:generatedPushToken apnsToken:generatedApnsToken deviceId:deviceId success:^() {
            [self goToHome];
        } failure:^(NSString *errorMessage) {
            [self showError:errorMessage];
        }];
    });
}

- (void)goToHome {
    [self showInitialState];
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                [self performSegueWithIdentifier:@"goToHome" sender:nil];
            } else {
                NSString *errMsg = stringPermissionDenied;
                [self showError:errMsg];
            }
        });
    }];
    
}

- (void)goToLogin {
    phoneId = nil;
    remotePushToken = nil;
    generatedPushToken = nil;
    generatedApnsToken = nil;
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
