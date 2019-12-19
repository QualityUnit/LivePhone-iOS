//
//  Constants.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 16.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

// application
#define appName @"LiveAgentPhone"

// application state
#define stateForeground [NSNumber numberWithInt:1]

// network
#define timeoutSec 15.00
#define maxPushNotificationDelay 5
#define pathBase @"/api/v3"
#define urlResultOk 0
#define urlResultUrlEmpty 1
#define urlResultUrlInvalid 2
#define urlResultNoConnection 3
#define urlResultApiError 4

// memory keys
#define memoryKeyTypedUrl @"memoryKeyTypedUrl"
#define memoryKeyTypedEmail @"memoryKeyTypedEmail"
#define memoryKeyUrl @"memoryKeyUrl"
#define memoryKeyEmail @"memoryKeyEmail"
#define memoryKeyApikey @"memoryKeyApikey"
#define memoryKeyApikeyId @"memoryKeyApikeyId"
#define memoryKeySipId @"memoryKeySipId"
#define memoryKeySipNumber @"memoryKeySipNumber"
#define memoryKeySipHost @"memoryKeySipHost"
#define memoryKeySipUser @"memoryKeySipUser"
#define memoryKeySipPassword @"memoryKeySipPassword"
#define memoryKeyVoipPushToken @"memoryKeyVoipPushToken"
#define memoryKeyAgentId @"memoryKeyAgentId"
#define memoryKeyInstallId @"memoryKeyInstallId"
#define memoryKeyDeviceId @"memoryKeyDeviceId"

// local notification names
#define localNotificationIntoInit @"localNotificationIntoInit"
#define localNotificationCallEvent @"localNotificationCallEvent"
#define localNotificationCallData @"localNotificationCallData"
#define localNotificationApplicationState @"localNotificationApplicationState"

// local notification categories
#define CATEGORY_IDENTIFIER_MISSED_CALL @"com.qualityunit.ios.liveagentphone.localnotification.missedcall"
#define CATEGORY_IDENTIFIER_INIT_CALL @"com.qualityunit.ios.liveagentphone.localnotification.initcall"

// common localized strings
#define errorMsgEmptyField NSLocalizedStringWithDefaultValue(@"login.errMsgEmptyField", @"Localizable", [NSBundle mainBundle], @"Please fill required fields", @"Error message on login screen if some of fields are empty");
#define errorMsgCannotParseResponse NSLocalizedStringWithDefaultValue(@"common.errMsgCannotParseResponse",@"Localizable",[NSBundle mainBundle],@"Cannot parse response",@"Error message on login screen if we cannot parse response from server");
#define errorMsgUrlInvalid NSLocalizedStringWithDefaultValue(@"urlChecker.errMsgUrlInvalid",@"Localizable",[NSBundle mainBundle],@"Invalid URL",@"Error message on login screen if typed URL is not valid");
#define stringErrorTitle NSLocalizedStringWithDefaultValue(@"common.error",@"Localizable",[NSBundle mainBundle],@"Error",@"Simple error title");
#define stringOk NSLocalizedStringWithDefaultValue(@"common.ok",@"Localizable",[NSBundle mainBundle],@"Ok",@"Ok");
#define stringEmpty NSLocalizedStringWithDefaultValue(@"common.emptyList",@"Localizable",[NSBundle mainBundle],@"Empty list",@"Label showing while list is empty");
#define stringNoResults NSLocalizedStringWithDefaultValue(@"common.noResultsFor",@"Localizable",[NSBundle mainBundle],@"No results for '%s'",@"Label showing while list of search result is empty");
#define stringLogout NSLocalizedStringWithDefaultValue(@"contactMenu.logout",@"Localizable",[NSBundle mainBundle],@"Logout",@"Item in menu");
#define stringBack NSLocalizedStringWithDefaultValue(@"common.back",@"Localizable",[NSBundle mainBundle],@"Back",@"Label in navigation bar");
#define stringAbout NSLocalizedStringWithDefaultValue(@"contactMenu.about",@"Localizable",[NSBundle mainBundle],@"About",@"Item in menu");
#define stringUnknown NSLocalizedStringWithDefaultValue(@"calling.unknown",@"Localizable",[NSBundle mainBundle],@"Unknown",@"If it is not possible to get caller number, show this default value");
#define stringVisitor NSLocalizedStringWithDefaultValue(@"calling.visitor",@"Localizable",[NSBundle mainBundle],@"Website visitor",@"When website visitor is calling");
#define stringPermissionDenied NSLocalizedStringWithDefaultValue(@"calling.permissions",@"Localizable",[NSBundle mainBundle],@"Please enable all permissions for app in iOS settings",@"When user disallows some of required permissions");
#define stringMissedCalls NSLocalizedStringWithDefaultValue(@"calling.missedcall",@"Localizable",[NSBundle mainBundle],@"Missed call",@"Missed call");
#define stringAvailable NSLocalizedStringWithDefaultValue(@"status.available",@"Localizable",[NSBundle mainBundle],@"Available",@"Available on calls");
#define stringUnavailable NSLocalizedStringWithDefaultValue(@"status.unavailable",@"Localizable",[NSBundle mainBundle],@"Unavailable",@"Unavailable on calls");
#define stringStartOutgoing NSLocalizedStringWithDefaultValue(@"calling.startOutgoing",@"Localizable",[NSBundle mainBundle],@"Make call",@"Outgoing call starter from system notification");
#define stringTwoFactorTitle NSLocalizedStringWithDefaultValue(@"twofactor.title",@"Localizable",[NSBundle mainBundle],@"Verification Code",@"Verification code request title");
#define stringTwoFactorMessage NSLocalizedStringWithDefaultValue(@"twofactor.message",@"Localizable",[NSBundle mainBundle],@"Enter 6-digit number from Google Authenticator application.",@"Verification code request message");
#define stringInvalidCredentials NSLocalizedStringWithDefaultValue(@"login.invalidCredentials",@"Localizable",[NSBundle mainBundle],@"Invalid email or password",@"Invalid email or password");
#define stringInvalidVerificationCode NSLocalizedStringWithDefaultValue(@"login.invalidVerificationCode",@"Localizable",[NSBundle mainBundle],@"Invalid verification code",@"Invalid verification code of two-factor authentication");
#define stringTooManyLogins NSLocalizedStringWithDefaultValue(@"login.tooManyLogins",@"Localizable",[NSBundle mainBundle],@"Login declined. Wait few minutes before retrying.",@"Login declined because of too many attempts");
// colors
#define textGreenOk @"#64DD17"
#define textRedNok @"#F44336"
#define surfaceCallGreen @"#16C855"
#define statusEnabled @"#909091"
#define statusActive @"#75c220"
#define statusDisabled @"#A91900"

//macros
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define NAVIGATE(s) NSLog([NSString stringWithFormat:@"NAVIGATE: %@", s]); UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil]; UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:s]; UIWindow *window = (UIWindow *)[[UIApplication sharedApplication].windows firstObject]; [UIView transitionFromView:window.rootViewController.view toView:viewController.view duration:0.35f options:UIViewAnimationOptionTransitionCrossDissolve completion:^(BOOL finished){ window.rootViewController = viewController;}];
