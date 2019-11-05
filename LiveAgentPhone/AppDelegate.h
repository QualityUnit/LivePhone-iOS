//
//  AppDelegate.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PushKit/PushKit.h>
#import "CallManager.h"
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, PKPushRegistryDelegate, UNUserNotificationCenterDelegate, UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) PKPushRegistry *voipRegistry;
@property (nonatomic, strong) CallManager *callManager;

- (void)registerPushNotifications;

- (nullable NSString *) getPendingPhoneNumber;

- (void)openCalling;

- (void)openDialpad:(NSString *)remoteNumber remoteName:(NSString *)remoteName;

- (void)openContactDetail:(NSDictionary *)contactDetail;

- (void)openInitCall:(NSDictionary *) payloadDictionary;

- (void)showCallFloatingButton;

- (void)hideCallFloatingButton;

@end

