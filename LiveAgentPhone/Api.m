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
#import "Utils.h"

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

+ (void)getDevices:(void (^)(NSArray *devices))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *requestParameters = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *filters = [[NSMutableDictionary alloc] init];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *phoneId = [userDefaults objectForKey:memoryKeySipId];
        NSString *agentId = [userDefaults objectForKey:memoryKeyAgentId];
        if (phoneId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'phoneId' not found on this device");
            });
            return;
        }
        [filters setObject:phoneId forKey:@"phone_id"];
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
                NSLog(@"SUCCESS '%@'", requestDescription);
                // check if mobile device exists (if no then create it)
                BOOL isMobileDevice = NO;
                if (response != nil && [response count] > 0) {
                    for (NSDictionary* device in response) {
                        if ([[device objectForKey:@"type"] isEqualToString:@"A"]) {
                            isMobileDevice = YES;
                            break;
                        }
                    }
                }
                if (!isMobileDevice) {
                    [self createDeviceWithPhoneId:phoneId agentId:agentId success:^(NSDictionary *mobileDevice) {
                        // mobile device successfuly created here and add it to the devices array
                        NSMutableArray* mutableDevices = [NSMutableArray arrayWithArray:response];
                        [mutableDevices addObject:mobileDevice];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            success(mutableDevices);
                        });
                    } failure:failure];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success(responseObject);
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
            NSHTTPURLResponse *resp = (NSHTTPURLResponse *) [operation response];
            [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
        }];
    });
}

+(void)createDeviceWithPhoneId:(NSString*)phoneId agentId:(NSString*)agentId success:(void (^)(NSDictionary *mobileDevice))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        // build body
        NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
        [body setObject:phoneId forKey:@"phone_id"];
        [body setObject:agentId forKey:@"agent_id"];
        [body setObject:@"A" forKey:@"type"];
        [body setObject:@"P" forKey:@"service_type"];
        [body setObject:@"N" forKey:@"status"];
        // build request
        AFHTTPSessionManager *manager = [Net createSessionManager];
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/devices", [manager baseURL]]] cachePolicy:NSURLRequestReloadIgnoringCacheData  timeoutInterval:timeoutSec];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[Net getApikey] forHTTPHeaderField:@"apikey"];
        [request setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *requestDescription = @"POST /devices";
        NSLog(@"%@", requestDescription);
        [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            if (!error) {
                if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"SUCCESS '%@'", requestDescription);
                    success(responseObject); // dispatch on the same thread
                } else {
                    NSString *errorMessage = errorMsgCannotParseResponse;
                    NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                    failure(errorMessage); // dispatch on the same thread
                }
            } else {
                //                NSHTTPURLResponse *resp = (NSHTTPURLResponse *) response;
                //                [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
                NSString *errorMessage = [error localizedDescription];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
            }
        }] resume];
    });
}

+(void)updateDevice:(NSDictionary*)body success:(void (^)(NSDictionary *device))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSString *deviceId = [body objectForKey:@"id"];
        AFHTTPSessionManager *manager = [Net createSessionManager];
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
                if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"SUCCESS '%@'", requestDescription);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success(responseObject);
                    });
                } else {
                    NSHTTPURLResponse *resp = (NSHTTPURLResponse *) response;
                    [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
                }
            } else {
                NSHTTPURLResponse *resp = (NSHTTPURLResponse *) response;
                [self deviceFailure:requestDescription error:error httpCode:[resp statusCode] failure:failure];
            }
        }] resume];
    });
}

+(void)deviceFailure:(NSString *)requestDescription error:(NSError *)error httpCode:(NSInteger)httpCode failure:(void (^)(NSString *errorMessage))failure{
    NSString *errorMessage = [error localizedDescription];
    if (httpCode == 404) {
        errorMessage = [NSString stringWithFormat:@"Your server API does not support 'status' or given 'phoneId' does not exist."];
    }
    NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
    dispatch_async(dispatch_get_main_queue(), ^{
        failure(errorMessage);
    });
}

+(void)getDepartmentStatusList:(NSString *)deviceId success:(void (^)(NSArray *deparmentList))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        if (deviceId == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"Variable 'deviceId' not defined");
            });
            return;
        }
        NSString *requestDescription = [NSString stringWithFormat:@"GET /devices/%@/departments", deviceId];;
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManager];
        [manager GET:[NSString stringWithFormat:@"devices/%@/departments?_page=0&_perPage=9999", deviceId] parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            NSLog(@"SUCCESS '%@'", requestDescription);
            if (responseObject != nil && [responseObject isKindOfClass:[NSArray class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(responseObject);
                });
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

+(void)updateDepartment:(NSDictionary *)body success:(void (^)(NSDictionary *deviceResponse))success failure:(void (^)(NSString *errorMessage))failure {
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
                if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"SUCCESS '%@'", requestDescription);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        success(responseObject);
                    });
                } else {
                    NSString *errorMessage = errorMsgCannotParseResponse;
                    NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(errorMessage);
                    });
                }
            } else {
                NSString *errorMessage = [error localizedDescription];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
            }
        }] resume];
    });
}

+(void)getPhone:(void (^)(NSDictionary* responseObject))success failure:(void (^)(NSString *errorMessage, BOOL unauthorized))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSString *requestDescription = @"GET /phones/_app_";
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManager];
        [manager GET:@"phones/_app_" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            if (responseObject != nil && [responseObject isKindOfClass:[NSDictionary class]]) {
                NSLog(@"SUCCESS '%@'", requestDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    success(responseObject);
                });
            } else {
                NSString *errorMessage = errorMsgCannotParseResponse;
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage, NO);
                });
            }
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *) [operation response];
            NSString *errorMessage = [error localizedDescription];
            NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage, [response statusCode] == 401);
            });
        }];
    });
}

+(void)updatePhoneParams:(NSString *)phoneId pushToken:(NSString *)pushToken deviceId:(NSString *)deviceId success:(void (^)(void))success failure:(void (^)(NSString *errorMessage))failure {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        if (deviceId == nil || [deviceId length] == 0) {
            NSString *errorMessage = @"Error: Cannot get local device ID";
            NSLog(@"%@", errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage);
            });
            return;
        }
        [params setObject:deviceId forKey:@"deviceId"];
        [params setObject:@"ios" forKey:@"platform"];
        [params setObject:pushToken forKey:@"pushToken"];
        [params setObject:[NSNumber numberWithBool:[Utils isDebug]] forKey:@"devMode"];
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&jsonError];
        if (!jsonData) {
            NSString *errorMessage = [NSString stringWithFormat:@"Error: %@", [jsonError localizedDescription]];
            NSLog(@"%@", errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(errorMessage);
            });
            return;
        } else {
            NSString *requestDescription = [NSString stringWithFormat:@"PUT /phones/%@/_updateParams", phoneId];
            NSLog(@"%@", requestDescription);
            AFHTTPSessionManager *manager = [Net createSessionManager];
            NSString *paramsJsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *encodedParams = [paramsJsonString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            [manager PUT:[NSString stringWithFormat:@"phones/%@/_updateParams?params=%@", phoneId, encodedParams] parameters:nil success:^(NSURLSessionTask *task, id responseObject) {
                NSLog(@"SUCCESS '%@'", requestDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    success();
                });
            } failure:^(NSURLSessionTask *operation, NSError *error) {
                NSString *errorMessage = [error localizedDescription];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(errorMessage);
                });
            }];
        }
        
    });
}

@end
