//
//  Utils.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 16.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import "Utils.h"
#import "Constants.h"
#import "KFKeychain.h"

@implementation Utils

+ (BOOL)isConnected {
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    return networkStatus != NotReachable;
}

+ (BOOL)isUrlValid:(nonnull NSString *) urlString {
    NSURL* url = [NSURL URLWithString:urlString];
    return url != nil;
}

+ (NSString *)stringFromDeviceToken:(NSData *)deviceToken {
    NSUInteger length = deviceToken.length;
    if (length == 0) {
        return nil;
    }
    const unsigned char *buffer = deviceToken.bytes;
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(length * 2)];
    for (int i = 0; i < length; ++i) {
        [hexString appendFormat:@"%02x", buffer[i]];
    }
    return [hexString copy];
}


+ (BOOL)isAuthenticated {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [userDefaults objectForKey:deprecatedMemoryKeyApikey];
    return apiKey != nil;
}

+ (nonnull NSString *)createCalleeUriWithPhoneNumber:(nonnull NSString *)phoneNumber phonePrefix:(nullable NSString *)phonePrefix sipHost:(nonnull NSString *)sipHost {
    NSString *finalUri;
    //replace '+' with '00'
    phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@"00"];
    // concat prefix if exists
    if (phonePrefix != nil) {
        finalUri = [NSString stringWithFormat:@"%@%@", phonePrefix, phoneNumber];
    } else {
        finalUri = phoneNumber;
    }
    //concat sip scheme and host postfix
    finalUri = [NSString stringWithFormat:@"sip:%@@%@", finalUri, sipHost];
    return finalUri;
}

+ (nonnull NSString *)createCalleeUriWithPhoneNumber:(nonnull NSString *)phoneNumber sipHost:(nonnull NSString *)sipHost {
    return [self createCalleeUriWithPhoneNumber:phoneNumber phonePrefix:nil sipHost:sipHost];
}

+ (BOOL) isDebug {
    #ifdef DEBUG
        return true;
    #else
        return false;
    #endif
}

+ (NSString *)createContactName:(NSDictionary *)dataItem {
    NSMutableString *stringToView = [[NSMutableString alloc] init];
    NSString *firstName = [dataItem objectForKey:@"firstname"];
    if (firstName != nil && [firstName length] > 0) {
        [stringToView appendFormat:@"%@ ", firstName];
    }
    NSString *lastName = [dataItem objectForKey:@"lastname"];
    if (lastName != nil && [lastName length] > 0) {
        [stringToView appendString:lastName];
    }
    if ([stringToView length] == 0) {
        NSString *systemName = [dataItem objectForKey:@"system_name"];
        if (systemName != nil && [systemName length] > 0) {
            [stringToView appendString:systemName];
        }
    }
    return stringToView;
}

+ (void)saveToKeychainForKey:(nonnull NSString *)key value:(nullable NSString *)value {
    [KFKeychain saveObject:value forKey:key];
}

+ (NSString *)loadFromKeychainForKey:(nonnull NSString *)key deprecatedMemoryKey:(nonnull NSString *)deprecatedMemoryKey {
    NSString *value = [KFKeychain loadObjectForKey:key];
    if (value == nil || [value length] == 0) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        value = [userDefaults objectForKey:deprecatedMemoryKey];
        if (value != nil && [value length] > 0) {
            [Utils saveToKeychainForKey:key value:value];
            [userDefaults removeObjectForKey:deprecatedMemoryKey];
            [userDefaults synchronize];
        }
    }
    return value;
}

+ (void)deleteFromKeychainForKey:(nonnull NSString *)key {
    [KFKeychain deleteObjectForKey:key];
}

@end
