//
//  ApiUrlCheck.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 30.1.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//
#define DELAY_SEC 2

#import "ApiUrlCheck.h"
#import "Constants.h"
#import "Net.h"
#import "Utils.h"

@interface ApiUrlCheck () {
    @private
    void (^currentCallback)(NSDictionary *);
    BOOL terminated;
}

@end

@implementation ApiUrlCheck

- (id)initWithCallbackBlock:(void (^)(NSDictionary *))callback {
    terminated = NO;
    currentCallback = callback;
    return self;
}

- (void)startWithUrl:(NSString *) typedUrl {
    if (typedUrl == nil || [typedUrl length] == 0) {
        // do nothing
        return;
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableString *urlString = [NSMutableString stringWithString:[typedUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        if ([urlString hasSuffix:@"/"]) {
            [urlString deleteCharactersInRange:NSMakeRange([urlString length] - 1, 1)];
        }
        if ([urlString hasSuffix:pathBase]) {
            [urlString appendString:pathBase];
        }
        if ([urlString hasPrefix:@"https://"]) {
            // do nothing with url
        } else if ([urlString hasPrefix:@"http://"]) {
            [urlString replaceOccurrencesOfString:@"http://" withString:@"https://" options:NSLiteralSearch range:NSMakeRange(0, [urlString length])];
        } else {
            [urlString insertString:@"https://" atIndex:0];
        }
        [self startChecking:urlString];
    });
}

- (void)startChecking:(NSString *) url {
    NSLog(@"Testing URL: '%@'", url);
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    if (![Utils isUrlValid:url]) {
        dispatch_async(globalQueue, ^{
            NSLog(@"Invalid URL");
            NSString *errorMessage = errorMsgUrlInvalid;
            [self sendResultWithCode:[NSNumber numberWithInteger:urlResultUrlInvalid] message:errorMessage apiUrl:url delaySeconds:DELAY_SEC];
        });
        return;
    }
    dispatch_async(globalQueue, ^{
        NSString *requestDescription = @"GET /ping";
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManagerWithHost:url apikey:nil];
        [manager GET:@"ping" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            NSLog(@"SUCCESS '%@'", requestDescription);
            [self sendResultWithCode:[NSNumber numberWithInteger:urlResultOk] message:nil apiUrl:url delaySeconds:0];
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            dispatch_async(globalQueue, ^{
                NSString *errorMessage = [error localizedDescription];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                [self sendResultWithCode:[NSNumber numberWithInteger:urlResultApiError] message:errorMessage apiUrl:url delaySeconds:DELAY_SEC];
            });
        }];
    });
}

- (void)sendResultWithCode:(nonnull NSNumber *) urlResultCode message:(nullable NSString *) message apiUrl:(nullable NSString *) apiUrl delaySeconds:(long) seconds {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (terminated) {
            // do not run callback
            return;
        }
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        [result setObject:urlResultCode forKey:@"code"];
        if (message != nil) {
            [result setObject:message forKey:@"message"];
        }
        if (apiUrl != nil) {
            [result setObject:apiUrl forKey:@"apiUrl"];
        }
        currentCallback(result);
    });
}

- (void)terminate {
    terminated = YES;
}

@end
