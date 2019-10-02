//
//  Utils.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 16.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface Utils : NSObject

+ (BOOL)isConnected;
+ (BOOL)isUrlValid:(nonnull NSString *) url;
+ (NSString *)stringFromDeviceToken:(NSData *)deviceToken;
+ (BOOL)isAuthenticated;
+ (nonnull NSString *)createCalleeUriWithPhoneNumber:(nonnull NSString *)phoneNumber phonePrefix:(nullable NSString *)phonePrefix sipHost:(nonnull NSString *)sipHost;
+ (nonnull NSString *)createCalleeUriWithPhoneNumber:(nonnull NSString *)phoneNumber sipHost:(nonnull NSString *)sipHost;
+ (BOOL) isDebug;
+ (NSString *)createContactName:(NSDictionary *)dataItem;

@end
