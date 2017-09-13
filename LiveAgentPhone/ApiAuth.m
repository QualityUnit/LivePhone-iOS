//
//  ApiAuth.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 17.4.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "ApiAuth.h"
#import <AFNetworking/AFNetworking.h>
#import "Net.h"
#import "Constants.h"

@implementation ApiAuth

+ (void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password success:(void (^)())success failure:(void (^)(NSString *errorMessage))failure {
    // make a call GET /token in background
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:email forKey:@"username"];
        [params setObject:password forKey:@"password"];
        NSString *requestDescription = @"GET /token";
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManagerWithHost:apiUrl apikey:nil];
        [manager GET:@"token" parameters:params progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) {
                NSLog(@"SUCCESS '%@'", requestDescription);
                NSDictionary *response = responseObject;
                NSString *apikey = [response objectForKey:@"key"];
                if (apikey != nil && apikey.length > 0) {
                    // response is ok because we've got a token, let's save URL, email and token
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    [userDefaults setObject:apiUrl forKey:memoryKeyUrl];
                    [userDefaults setObject:email forKey:memoryKeyEmail];
                    [userDefaults setObject:apikey forKey:memoryKeyApikey];
                    [userDefaults synchronize];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success();
                    });
                }
            } else {
                NSString *errorMessage = errorMsgCannotParseResponse;
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
            }
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSString *errorMessage = [error localizedDescription];
            NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage);
            });
        }];
    });
}

@end
