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

+ (void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password verificationCode:(NSString * _Nullable)verificationCode  success:(void (^)(void))success failure:(void (^)(NSString *errorMessage))failure invalidPassword:(void (^)(void))invalidPassword verificationCodeRequired:(void (^)(void))verificationCodeRequired verificationCodeFailure:(void (^)(void))verificationCodeFailure tooManyLogins:(void (^)(void))tooManyLogins {
    // make a call GET /token in background
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        // build body
        NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
        [body setObject:email forKey:@"login"];
        [body setObject:password forKey:@"password"];
        [body setObject:@"P" forKey:@"type"];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *validToDate = [cal dateByAddingUnit:NSCalendarUnitMonth value:3 toDate:[NSDate date] options:0];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [dateFormatter setTimeZone:timeZone];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.sssZZZZZ"];
        NSString *validToDateString = [dateFormatter stringFromDate:validToDate];
        [body setObject:validToDateString forKey:@"valid_to_date"];
        [body setObject:[[UIDevice currentDevice] name] forKey:@"name"];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *installId = [userDefaults objectForKey:memoryKeyInstallId];
        if (installId == nil) {
            NSUUID *uuid = [NSUUID UUID];
            installId = [uuid UUIDString];
            [userDefaults setObject:installId forKey:memoryKeyInstallId];
            [userDefaults synchronize];
        }
        [body setObject:installId forKey:@"installid"];
        if (verificationCode != nil && verificationCode.length > 0) {
            [body setObject:verificationCode forKey:@"two_factor_token"];
        }
        // build request
        AFHTTPSessionManager *manager = [Net createSessionManagerWithHost:apiUrl apikey:nil];
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/apikeys/_login", [manager baseURL]]] cachePolicy:NSURLRequestReloadIgnoringCacheData  timeoutInterval:timeoutSec];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        NSString *requestDescription = @"POST /apikeys/_login";
        NSLog(@"%@", requestDescription);
        [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    NSHTTPURLResponse *resp = (NSHTTPURLResponse *) response;
                    NSInteger code = [resp statusCode];
                    switch (code) {
                        case 401:
                        case 403:
                            invalidPassword();
                            return;
                        case 424:
                            verificationCodeRequired();
                            return;
                        case 425:
                            verificationCodeFailure();
                            return;
                        case 429:
                            tooManyLogins();
                            return;
                        default:
                            failure(error.localizedDescription);
                            return;
                    }
                }
                if (responseObject == nil || ![responseObject isKindOfClass:[NSDictionary class]]) {
                    NSString *errorMessage = errorMsgCannotParseResponse;
                    NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                    failure(errorMessage);
                    return;
                }
                NSLog(@"SUCCESS '%@'", requestDescription);
                NSDictionary *body = responseObject;
                // Bad server implementation - temporary FIX
                NSString *message = [body objectForKey:@"message"];
                if (message != nil && message.length > 0) {
                    if ([message isEqualToString:@"Two-factor authentication required."]) {
                        verificationCodeRequired();
                    } else if ([message isEqualToString:@"Invalid two-factor verification code."]) {
                        verificationCodeFailure();
                    } else {
                        failure(message);
                    }
                    return;
                }
                // success
                NSString *apikey = [body objectForKey:@"key"];
                if (apikey == nil || apikey.length < 1) {
                    failure(@"Error: API token not found in login response");
                    return;
                }
                // response is ok because we've got a token, let's save URL, email and token
                [userDefaults setObject:apiUrl forKey:memoryKeyUrl];
                [userDefaults setObject:email forKey:memoryKeyEmail];
                [userDefaults setObject:apikey forKey:memoryKeyApikey];
                [userDefaults synchronize];
                success();
            });
        }] resume];
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
        [body setObject:@"N" forKey:@"preset_status"];
        [body setObject:@"N" forKey:@"online_status"];
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
        [manager GET:[NSString stringWithFormat:@"devices/%@/departments?_page=0&_perPage=999", deviceId] parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
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
