//
//  Constants.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 16.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

// application
#define appName @"LiveAgentPhone"

// network
#define timeoutSec 15.00
#define maxIncomingCallPushDelay 5
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
#define memoryKeySipId @"memoryKeySipId"
#define memoryKeySipNumber @"memoryKeySipNumber"
#define memoryKeySipHost @"memoryKeySipHost"
#define memoryKeySipUser @"memoryKeySipUser"
#define memoryKeySipPassword @"memoryKeySipPassword"
#define memoryKeyPushToken @"memoryKeyPushToken"

// local notification names
#define localNotificationIntoInit @"localNotificationIntoInit"
#define localNotificationCallEvent @"localNotificationCallEvent"
#define localNotificationCallData @"localNotificationCallData"

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
#define stringUnknown NSLocalizedStringWithDefaultValue(@"calling.unknown",@"Localizable",[NSBundle mainBundle],@"Unknown",@"It it is not possible to get caller number, show this default value");
#define stringPermissionDenied NSLocalizedStringWithDefaultValue(@"calling.permissions",@"Localizable",[NSBundle mainBundle],@"Please enable all permissions for app in iOS settings",@"When user disallows some of required permissions");
#define stringMissedCalls NSLocalizedStringWithDefaultValue(@"calling.missedcall",@"Localizable",[NSBundle mainBundle],@"Missed call",@"Missed call");
// colors
#define textGreenOk @"#64DD17"
#define textRedNok @"F44336"
#define surfaceCallGreen @"16C855"
