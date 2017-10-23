//
//  Api.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 17.4.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Api : NSObject

+(void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password success:(void (^)())success failure:(void (^)(NSString *errorMessage))failure;
+(void)getDevice:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure;
+(void)updateDevice:(BOOL)isAvailable success:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure;
+(void)getDepartmentStatusList:(void (^)(NSArray *deparmentList))success failure:(void (^)(NSString *errorMessage))failure;
+(void)updateDepartment:(NSDictionary *)obj success:(void (^)(BOOL isOnline))success failure:(void (^)(NSString *errorMessage))failure;

@end
