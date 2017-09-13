//
//  ApiAuth.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 17.4.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ApiAuth : NSObject

+ (void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password success:(void (^)())success failure:(void (^)(NSString *errorMessage))failure;

@end
