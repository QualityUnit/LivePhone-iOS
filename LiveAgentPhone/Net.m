//
//  Net.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 20.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import "Net.h"
#import "Constants.h"

@implementation Net

+ (AFHTTPSessionManager*) createSessionManagerWithHost: (NSString*) host apikey: (NSString*) apikey {
    NSURL *baseUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", host, pathBase]];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseUrl];
    [[manager requestSerializer] setTimeoutInterval:timeoutSec];
    if (apikey != nil && apikey.length != 0) {
        [[manager requestSerializer] setValue:apikey forHTTPHeaderField:@"apikey"];
    }
    return manager;
}

+ (AFHTTPSessionManager*) createSessionManager {
    // getting host and apiKey from user preferences
    NSString *host = [[NSUserDefaults standardUserDefaults] stringForKey:memoryKeyUrl];
    NSString *apikey = [[NSUserDefaults standardUserDefaults] stringForKey:memoryKeyApikey];
    return [self createSessionManagerWithHost:host apikey:apikey];
}

@end
