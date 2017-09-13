//
//  Net.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 20.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

@interface Net : NSObject

/*!
 * Create an AFHTTPSessionManager with params host (mandatory) and apikey (can be nil)
 */
+ (nonnull AFHTTPSessionManager*) createSessionManagerWithHost: (nonnull NSString*) host apikey: (nullable NSString*) apikey;

/*!
 * Create an AFHTTPSessionManager. Host and apikey they will be loaded from NSUserDefaults
 */
+ (nonnull AFHTTPSessionManager*) createSessionManager;

@end
