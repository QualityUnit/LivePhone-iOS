//
//  AppDelegate.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"
#import "Utils.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "DialpadTableViewController.h"
#import <Intents/Intents.h>
#import "CallingTableViewController.h"
#import "ContactDetailTableViewController.h"
#import <HexColors/HexColors.h>
#import "UIView+draggable.h"
#import "InitCallViewController.h"

@interface AppDelegate () {
    @private
    NSString *pendingPhoneNumber;
    UIView *callFloatingButton;
}

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES]; // show activity indicator in status bar automatically
    [self setCallManager:[[CallManager alloc] initCallManager]];
    application.applicationIconBadgeNumber = 0;
    return YES;
}

- (void)w:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    [[NSNotificationCenter defaultCenter] postNotificationName:localNotificationApplicationState object:stateForeground];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    NSString *categoryIdentifier = [[[[response notification] request] content] categoryIdentifier];
    if (categoryIdentifier == nil || [categoryIdentifier length] == 0) {
        NSLog(@"missing category identifier");
        completionHandler();
        return;
    }
    if ([categoryIdentifier isEqualToString:CATEGORY_IDENTIFIER_MISSED_CALL]) {
        pendingPhoneNumber = [[[[[response notification] request] content] userInfo] objectForKey:@"remoteNumber"];
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive && [Utils isAuthenticated]) {
            [self openDialpad:[self getPendingPhoneNumber] remoteName:nil];
        }
        
    } else if ([categoryIdentifier isEqualToString:CATEGORY_IDENTIFIER_INIT_CALL]) {
        NSDictionary *userInfo = [[[[response notification] request] content] userInfo];
        [self openInitCall:userInfo];
    }
    completionHandler();
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    NSString *activityType = [userActivity activityType];
    if ([activityType isEqualToString:@"INStartAudioCallIntent"]) {
        INInteraction *interaction = userActivity.interaction;
        INStartAudioCallIntent *startAudioCallIntent = (INStartAudioCallIntent *) interaction.intent;
        INPerson *contact = startAudioCallIntent.contacts[0];
        INPersonHandle *personHandle = contact.personHandle;
        pendingPhoneNumber = personHandle.value;
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive && [Utils isAuthenticated]) {
            [self openDialpad:[self getPendingPhoneNumber] remoteName:nil];
        }
    } else {
        NSLog(@"Unknown intent");
    }
    return YES;
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        NSDictionary *payloadDictionary = payload.dictionaryPayload;
        [self processPushNotificationPayload:payloadDictionary];
    } else {
        NSLog(@"Error: Unknown PKPushType");
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if ([type isEqualToString:PKPushTypeVoIP]) {
        NSString * pushToken = [Utils stringFromDeviceToken:[credentials token]];
//        NSLog(@"VoIP pushToken = %@", pushToken);
        if (pushToken == nil || [pushToken length] == 0) {
            [dict setObject:@"Cannot get push token." forKey:@"error"];
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
            return;
        }
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:pushToken forKey:memoryKeyVoipPushToken];
        [userDefaults synchronize];
        [dict setObject:pushToken forKey:@"pushToken"];
        // register APNs notifications
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(!error) {
//                    NSLog(@"APNs granted: %@", granted ? @"Yes" : @"No");
                    if (granted) {
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                    } else {
                        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
                    }
                } else {
                    NSLog(@"APNs failed");
                    [dict setObject:[NSString stringWithFormat:@"ERROR: %@ - %@", error.localizedFailureReason, error.localizedDescription] forKey:@"error"];
                    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
                }
            });
         }];
        return;
    }
    [dict setObject:@"Unknow PKPushType." forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
}

- (void)processPushNotificationPayload:(NSDictionary *) payloadDictionary {
    NSString *type = [payloadDictionary objectForKey:@"type"];
    // check if type is set
    if (type == nil || [type length] == 0) {
        NSLog(@"Error in push notification: type not set");
        return;
    }
    // check if notification is not older than 'maxPushNotificationDelay' seconds
    NSString *dateString = [payloadDictionary objectForKey:@"time"];
    if (![dateString isKindOfClass:[NSString class]]) {
        NSLog(@"ERROR: Incompatible 'time' type. It should be string.");
        return;
    }
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    NSDate *datePush = [formatter dateFromString:dateString];
    if (datePush == nil) {
        NSLog(@"ERROR: Unknown format of 'time' value: '%@'", dateString);
        return;
    }
    NSLog(@"Date raw: %@", dateString);
    NSDate *dateSystem = [NSDate date];
    NSTimeInterval dateDelta = [dateSystem timeIntervalSinceDate:datePush];
    NSLog(@"Date push: %@", datePush);
    NSLog(@"Date system: %@", dateSystem);
    NSLog(@"Delta dates: %f", dateDelta);
    if (dateDelta > maxPushNotificationDelay) { // get rid of all old push notifications
        return;
    }
    // switch it
    if ([type isEqualToString:@"I"]) {
        [self processIncomingCall:payloadDictionary];
    } else if ([type isEqualToString:@"O"]) {
        [self processInitCall:payloadDictionary];
    } else if ([type isEqualToString:@"OC"]) {
        [self processCancelInitCall:payloadDictionary];
    } else {
        NSLog(@"Error: Unknown 'type' %@", type);
    }
}

- (void)registerPushNotifications {
    // register VoIP notificaions
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    // SCREENSHOOT MODE START (simulator)
//    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
//    NSString * pushToken = @"XXXXXXXXXXXXXXXXXXXXXXXXXXX";
//    [userDefaults setObject:pushToken forKey:memoryKeyVoipPushToken];
//    [userDefaults synchronize];
//    [dict setObject:pushToken forKey:@"pushToken"];
//    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
    // SCREENSHOOT MODE END
    [userDefaults removeObjectForKey:memoryKeyVoipPushToken];
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    [self.voipRegistry setDelegate:self];
    [self.voipRegistry setDesiredPushTypes:[NSSet setWithObject:PKPushTypeVoIP]];
    [self performSelector:@selector(checkVoipPushToken) withObject:self afterDelay:3.0];
    NSLog( @"VoIP push registration sent..." );
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *apnsPushToken = [Utils stringFromDeviceToken:deviceToken];
//    NSLog(@"APNs pushToken = %@", apnsPushToken);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *pushToken = [userDefaults objectForKey:memoryKeyVoipPushToken];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:pushToken forKey:@"pushToken"];
    [dict setObject:apnsPushToken forKey:@"apnsToken"];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
}
 
- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:@"Remote notification support is unavailable due to error: %@" forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [self processPushNotificationPayload:userInfo];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)checkVoipPushToken {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:memoryKeyVoipPushToken] == nil) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:@"Your device does not support VoIP push notifications." forKey:@"error"];
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:localNotificationIntoInit object:dict]];
    }
}

- (NSString *)getPendingPhoneNumber {
    NSString *number = pendingPhoneNumber;
    pendingPhoneNumber = nil;
    return number;
}

- (void)showCallFloatingButton {
    if (callFloatingButton == nil) {
        callFloatingButton = [[UIView alloc] initWithFrame: CGRectMake (([self window].frame.size.width -60), 70, 50, 50)];
        callFloatingButton.layer.masksToBounds = NO;
        callFloatingButton.layer.shadowOffset = CGSizeMake(-3, 5);
        callFloatingButton.layer.shadowRadius = 5;
        callFloatingButton.layer.shadowOpacity = 0.5;
        callFloatingButton.backgroundColor = [UIColor hx_colorWithHexRGBAString:surfaceCallGreen];
        [callFloatingButton enableDragging];
        [[callFloatingButton layer] setCornerRadius:5];
        UIImageView * imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"phoneWhite"]];
        imageView.center = CGPointMake(callFloatingButton.frame.size.width  / 2,
                                       callFloatingButton.frame.size.height / 2);
        [callFloatingButton addSubview:imageView];
        UITapGestureRecognizer *gesRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(onCallFloatingButtonTap:)];
        gesRecognizer.delegate = self;
        [callFloatingButton addGestureRecognizer:gesRecognizer];
    }
    [self.window addSubview:callFloatingButton];
}

- (void)hideCallFloatingButton {
    if (callFloatingButton != nil) {
        [callFloatingButton removeFromSuperview];
    }
}

- (void) onCallFloatingButtonTap:(UITapGestureRecognizer *)gestureRecognizer {
    [self openCalling];
}

- (void)openCalling {
    [self hideCallFloatingButton];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    CallingTableViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"CallingTableViewController"];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
    [[self getCurrentViewController] presentViewController:navigationController animated:YES completion:nil];
}

- (void)openDialpad:(NSString *)remoteNumber remoteName:(NSString *)remoteName {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    DialpadTableViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"DialpadTableViewController"];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [viewController setCalleeNumber:remoteNumber calleeName:remoteName fromOutside:YES];
    [[self getCurrentViewController] presentViewController:navigationController animated:YES completion:nil];
}

- (void)openContactDetail:(NSDictionary *)contactDetail {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    ContactDetailTableViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"ContactDetailTableViewController"];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [viewController setContactDetail:contactDetail];
    [[self getCurrentViewController] presentViewController:navigationController animated:YES completion:nil];
}

- (void)openInitCall:(NSDictionary *) payloadDictionary {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    InitCallViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"InitCallViewController"];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [viewController setData:payloadDictionary];
    [[self getCurrentViewController] presentViewController:navigationController animated:YES completion:nil];
}

- (UIViewController*)getCurrentViewController {
    UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (currentController.presentedViewController) {
        currentController = currentController.presentedViewController;
    }
    return currentController;
}

- (void)processIncomingCall:(NSDictionary *) payloadDictionary {
    [self.callManager prepareToIncomingCall];
}

- (void)processInitCall:(NSDictionary *) payloadDictionary {
    NSString *title = stringStartOutgoing;
    NSString *number = [payloadDictionary objectForKey:@"number"]; // readable number
    NSString *callId = [payloadDictionary objectForKey:@"callId"]; // identification of push notification
    if (number == nil || [number length] == 0) {
        number = @"(No number)";
    }
    if (callId == nil || [callId length] == 0) {
        NSLog(@"Error: Missing 'callId' value");
        return;
    }
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        // APP IN FOREGROUND: show screen to make an outgoing call
        [self openInitCall:payloadDictionary];
        return;
    }
    // APP IN BACKGROUND: show local notification which triggers making call
    UNMutableNotificationContent *localNotification = [[UNMutableNotificationContent alloc] init];
    [localNotification setTitle:title];
    [localNotification setBody:number];
    [localNotification setUserInfo:payloadDictionary];
    [localNotification setCategoryIdentifier:CATEGORY_IDENTIFIER_INIT_CALL];
    UNNotificationRequest *localNotificationRequest = [UNNotificationRequest requestWithIdentifier:callId
                                                                                           content:localNotification
                                                                                           trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO]];
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter addNotificationRequest:localNotificationRequest withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: Add notificationRequest failed");
        }
    }];
}

- (void)processCancelInitCall:(NSDictionary *) payloadDictionary {
    NSString *callId = [payloadDictionary objectForKey:@"callId"]; // identification of push notification
    if (callId == nil || [callId length] == 0) {
        NSLog(@"Error: Missing 'callId' value");
        return;
    }
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSArray *array = [NSArray arrayWithObjects:callId, nil];
    [center removeDeliveredNotificationsWithIdentifiers:array];
}

@end
