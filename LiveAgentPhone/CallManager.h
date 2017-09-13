//
//  CallManager.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 20.2.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>

@interface CallManager : NSObject <CXProviderDelegate>

@property (nonatomic, strong, nullable) CXProvider *callKitProvider;
@property (nonatomic, strong, nullable) CXCallController *callKitCallController;

- (nonnull id)initCallManager;

- (void)makeCall:(nonnull NSString *)calleeNumber withPrefix:(nonnull NSString *)calleePrefix;

- (void)prepareToIncomingCall;

- (void)startRingingWithCallerName:(nonnull NSString *) callerName;

- (void)hangUpCurrentCall:(BOOL)isMissedCall callerName:(nullable NSString *)callerName;

- (void)setRemoteNumber:(nullable NSString *)remoteNumber;

- (nullable NSString*) getRemoteNumber;

/**
 Toggle mute on or off
 */
- (void)toggleMute;


/**
 Toggle speaker on or off
 */
- (void)toggleSpeaker;

/**
 Toggle hold on or off
 */
- (void)toggleHold;

/**
 Notify last call event and all data
 */
- (void)notifyAll;

- (void)sendDtmf:(nonnull NSString *) digits;

@end
