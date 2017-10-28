//
//  Api.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 17.4.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "Api.h"
#import <AFNetworking/AFNetworking.h>
#import "Net.h"
#import "Constants.h"

@implementation Api

+ (void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password success:(void (^)(void))success failure:(void (^)(NSString *errorMessage))failure {
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

+ (void)getDevice:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *requestParameters = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *filters = [[NSMutableDictionary alloc] init];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *phoneId = [userDefaults objectForKey:memoryKeySipId];
        if (phoneId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'phoneId' not found on this device");
            });
            return;
        }
        [filters setObject:phoneId forKey:@"phoneId"];
        [filters setObject:@"P" forKey:@"service_type"];
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:filters options:0 error:&jsonError];
        if (!jsonData) {
            NSString *errorMessage = [NSString stringWithFormat:@"Error: %@", [jsonError localizedDescription]];
            NSLog(@"%@", errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage);
            });
            return;
        }
        NSString *filtersJsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [requestParameters setObject:filtersJsonString forKey:@"_filters"];
        NSString *requestDescription = @"GET /devices";
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManager];
        [manager GET:@"devices" parameters:requestParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            if (responseObject != nil && [responseObject isKindOfClass:[NSArray class]]) {
                NSArray *response = responseObject;
                if ([response count] == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(@"Call service on your LiveAgent not found.");
                    });
                    return;
                }
                NSDictionary *device = [response firstObject];
                [self deviceSuccess:requestDescription resp:device success:success failure:failure];
            } else {
                NSString *errorMessage = errorMsgCannotParseResponse;
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
            }
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSHTTPURLResponse *resp = (NSHTTPURLResponse *) [operation response];
            [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
        }];
    });
}

+(void)updateDevice:(BOOL)isAvailable success:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSString *flag = @"F";
        if (isAvailable) {
            flag = @"N";
        }
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *deviceId = [userDefaults objectForKey:memoryKeyDeviceId];
        if (deviceId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'deviceId' not found on this device");
            });
            return;
        }
        NSString *agentId = [userDefaults objectForKey:memoryKeyAgentId];
        if (agentId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'agentId' not found on this device");
            });
            return;
        }
        AFHTTPSessionManager *manager = [Net createSessionManager];
        NSDictionary *body = @{@"agent_id":agentId, @"service_type":@"P", @"status":flag};
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *req = [[AFJSONRequestSerializer serializer ] requestWithMethod:@"PUT" URLString:[NSString stringWithFormat:@"%@/devices/%@", [manager baseURL], deviceId] parameters:nil error:nil];
        req.timeoutInterval = timeoutSec;
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[Net getApikey] forHTTPHeaderField:@"apikey"];
        [req setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *requestDescription = [NSString stringWithFormat:@"PUT /devices/%@", deviceId];;
        NSLog(@"%@", requestDescription);
        [[manager dataTaskWithRequest:req completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            if (!error) {
                [self deviceSuccess:requestDescription resp:responseObject success:success failure:failure];
            } else {
                NSHTTPURLResponse *resp = (NSHTTPURLResponse *) response;
                [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
            }
        }] resume];
    });
}

+(void)deviceSuccess:(NSString *)requestDescription resp:(id)responseObject success:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure{
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        NSLog(@"SUCCESS '%@'", requestDescription);
        NSString *deviceId = [responseObject objectForKey:@"id"];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:deviceId forKey:memoryKeyDeviceId];
        [userDefaults setObject:[responseObject objectForKey:@"agent_id"] forKey:memoryKeyAgentId];
        [userDefaults synchronize];
        dispatch_async(dispatch_get_main_queue(), ^{
            success([[responseObject objectForKey:@"status"] isEqualToString:@"N"]);
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            failure(@"Response object is not a JSON");
        });
    }
}

+(void)deviceFailure:(NSString *)requestDescription error:(NSError *)error httpCode:(NSInteger)httpCode failure:(void (^)(NSString *errorMessage))failure{
    NSString *errorMessage = [error localizedDescription];
    if (httpCode == 404) {
        errorMessage = [NSString stringWithFormat:@"Your server API does not support 'status' or given 'phoneId' does not exist."];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        failure(errorMessage);
    });
    NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
}

+(void)getDepartmentStatusList:(void (^)(NSArray *deparmentList))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *deviceId = [userDefaults objectForKey:memoryKeyDeviceId];
        if (deviceId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'deviceId' not found on this device");
            });
            return;
        }
        NSString *requestDescription = [NSString stringWithFormat:@"GET /devices/%@/departments", deviceId];;
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManager];
        [manager GET:[NSString stringWithFormat:@"devices/%@/departments", deviceId] parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            NSLog(@"SUCCESS '%@'", requestDescription);
            if (responseObject != nil && [responseObject isKindOfClass:[NSArray class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(responseObject);
                });
            } else {
                NSString *errorMessage = errorMsgCannotParseResponse;
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
            }
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSString *errorMessage = [error localizedDescription];
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage);
            });
            NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
        }];
    });
}

+(void)updateDepartment:(NSDictionary *)body success:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        if (body == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Object is null");
            });
            return;
        }
        AFHTTPSessionManager *manager = [Net createSessionManager];
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSString *deviceId = [body objectForKey:@"device_id"];
        NSString *departmentId = [body objectForKey:@"department_id"];
        NSMutableURLRequest *req = [[AFJSONRequestSerializer serializer ] requestWithMethod:@"PUT" URLString:[NSString stringWithFormat:@"%@/devices/%@/departments/%@", [manager baseURL], deviceId, departmentId] parameters:nil error:nil];
        req.timeoutInterval = timeoutSec;
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[Net getApikey] forHTTPHeaderField:@"apikey"];
        [req setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *requestDescription = [NSString stringWithFormat:@"PUT /devices/%@/departments/%@", deviceId, departmentId];;
        NSLog(@"%@", requestDescription);
        [[manager dataTaskWithRequest:req completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            if (!error) {
                if ([responseObject isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"SUCCESS '%@'", requestDescription);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success([[responseObject objectForKey:@"online_status"] isEqualToString:@"N"]);
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(@"Response object is not a JSON");
                    });
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure([error localizedDescription]);
                });
            }
        }] resume];
    });
}

@end
