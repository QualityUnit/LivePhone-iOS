//
//  ApiUrlCheck.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 30.1.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ApiUrlCheck : NSObject

-(id)initWithCallbackBlock:(void (^)(NSDictionary *))callback;

-(void)startWithUrl:(NSString *) typedUrl;

-(void)terminate;

@end
