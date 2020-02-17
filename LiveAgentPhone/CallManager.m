//
//  CallManager.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 20.2.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "CallManager.h"
#import "Constants.h"
#import "CallingTableViewController.h"
#import "AppDelegate.h"
#import "XCPjsua.h"
#import "Utils.h"
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AVKit/AVKit.h>

@interface CallManager () {
    @private
    AppDelegate *appDelegate;
    NSUUID *uuid;
    BOOL isMute;
    BOOL isSpeaker;
    BOOL isHold;
    NSString *lastRemoteNumber;
    NSString *lastRemoteName;
    NSString *lastEvent;
    NSString *lastMessage;
    NSString *calleePrefix;
    CXAnswerCallAction *answerCallAction;
    BOOL isSipRinging;
}

@end

@implementation CallManager

- (void)providerDidReset:(CXProvider *)provider {
    endCall();
    uuid = nil;
}

- (nonnull id)initCallManager {
    CXProviderConfiguration * configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:appName];
    configuration.maximumCallGroups = 1;
    configuration.maximumCallsPerCallGroup = 1;
    configuration.supportedHandleTypes = [NSSet setWithObjects:[NSNumber numberWithInteger:CXHandleTypeGeneric],[NSNumber numberWithInteger:CXHandleTypePhoneNumber], nil];
    self.callKitProvider = [[CXProvider alloc] initWithConfiguration: configuration];
    [self.callKitProvider setDelegate:self queue:nil];
    self.callKitCallController = [[CXCallController alloc] init];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return self;
}

- (void)makeCall:(nonnull NSString *)remoteNumber withPrefix:(nonnull NSString *)prefix remoteName:(NSString *)remoteName {
    if (isOngoingCall()) {
        return;
    }
    isSpeaker = NO;
    isMute = NO;
    uuid = [NSUUID UUID];
    calleePrefix = prefix;
    lastRemoteNumber = remoteNumber;
    lastRemoteName = remoteName;
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:lastRemoteNumber];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:callHandle];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@", [error localizedDescription]);
            [startCallAction fail];
        } else {
            NSLog(@"StartCallAction transaction request successful");
            CXCallUpdate *callUpdate = [self createDefaultCallupdate];
            [callUpdate setRemoteHandle:callHandle];
            [callUpdate setLocalizedCallerName:lastRemoteName];
            [self.callKitProvider reportCallWithUUID:uuid updated:callUpdate];
        }
    }];
}

- (void)prepareToIncomingCall {
    if (!isOngoingCall()) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        char *sipHostCharArray = (char *)[[defaults objectForKey:memoryKeySipHost] cStringUsingEncoding:[NSString defaultCStringEncoding]];
        char *sipUserCharArray = (char *)[[defaults objectForKey:memoryKeySipUser] cStringUsingEncoding:[NSString defaultCStringEncoding]];
        char *sipPasswordCharArray = (char *)[[defaults objectForKey:memoryKeySipPassword] cStringUsingEncoding:[NSString defaultCStringEncoding]];
        incomingCall(sipHostCharArray, sipUserCharArray, sipPasswordCharArray, self);
        [self initiateRinging];
    } else {
        NSLog(@"There is ongoing call right now");
    }
}

// when VoIP notification come then this is called to create "fake ringing" (ios 13)
- (void)initiateRinging {
    isSpeaker = NO;
    isMute = NO;
    lastRemoteNumber = stringUnknown;
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:lastRemoteNumber];
    CXCallUpdate *callUpdate = [self createDefaultCallupdate];
    [callUpdate setLocalizedCallerName:[self pickRemoteString]];
    [callUpdate setRemoteHandle:callHandle];
    uuid = [NSUUID UUID];
    [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError * _Nullable error) {
        if (error) {
            if ([error code] == CXErrorCodeCallDirectoryManagerErrorEntriesOutOfOrder) {
                // e.g. DND mode is activated
            } else {
                NSLog(@"Error: %@", error);
            }
        }
    }];
}

// when there is a real ringing call from SIP
- (void)onSipStartRinging {
    isSipRinging = YES;
    if (answerCallAction != nil) {
        // if the user is particularly fast at tapping the accept call button then fulfill pending answerCallAction
        [self answerCall];
    }
}

- (void)hangUpCurrentCall:(BOOL)isMissedCall  {
    if (uuid == nil) {
        NSLog(@"Nothing to hang up");
        return;
    }
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@", [error localizedDescription]);
            [endCallAction fail];
        }
        if (isMissedCall) {
//            [self showMissedCall];
        }
    }];
}

- (void)showMissedCall {
    NSString *title = [self pickRemoteString];
    UNMutableNotificationContent *localNotification = [[UNMutableNotificationContent alloc] init];
    [localNotification setTitle:title];
    NSString *strMissedCall = stringMissedCalls;
    [localNotification setBody:strMissedCall];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (lastRemoteName != nil) {
        [dict setObject:lastRemoteName forKey:@"remoteName"];
    }
    [dict setObject:lastRemoteNumber forKey:@"remoteNumber"];
    [localNotification setUserInfo:dict];
    [localNotification setCategoryIdentifier:CATEGORY_IDENTIFIER_MISSED_CALL];
    UNNotificationRequest *localNotificationRequest = [UNNotificationRequest requestWithIdentifier:title
                                                                                           content:localNotification
                                                                                           trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO]];
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter addNotificationRequest:localNotificationRequest withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: Add notificationRequest failed");
        }
    }];
}

- (NSString *)pickRemoteString {
    NSString *title = stringUnknown;
    if (lastRemoteName != nil && lastRemoteName.length > 0) {
        title = lastRemoteName;
    } else if (lastRemoteNumber != nil && lastRemoteNumber.length > 0) {
        title = lastRemoteNumber;
    }
    return title;
}

- (CXCallUpdate *)createDefaultCallupdate {
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = YES;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.hasVideo = NO;
    return callUpdate;
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    [self configureAudioSession];
    answerCallAction = action;
    // TODO wait until SIP registration is done and SIP call come...
    if (isSipRinging) {
        [self answerCall];
    }
}

-(void)answerCall {
    if (answerCall() == 0) {
        [answerCallAction fulfillWithDateConnected:[NSDate date]];
        answerCallAction = nil;
        [self goToCalling];
    } else {
        [answerCallAction fail];
    }
    isSipRinging = NO;
}

-(void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    endCall();
    [action fulfillWithDateEnded:[NSDate date]];
    uuid = nil;
    [appDelegate hideCallFloatingButton];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    [self configureAudioSession];
    lastRemoteNumber = [[action handle] value];
    NSString *calleeNumberWithPrefix = [NSString stringWithFormat:@"%@%@", calleePrefix, lastRemoteNumber];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *sipHost = [userDefaults objectForKey:memoryKeySipHost];
    NSString *sipUser = [userDefaults objectForKey:memoryKeySipUser];
    NSString *sipPassword = [userDefaults objectForKey:memoryKeySipPassword];
    NSString *calleeSipUri = [Utils createCalleeUriWithPhoneNumber:calleeNumberWithPrefix sipHost:sipHost];
    makeCall(sipHost, sipUser, sipPassword, calleeSipUri, self, action);
    [self goToCalling];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    if (muteMicrophone([action isMuted]) == 0) {
        isMute = [action isMuted];
        [self notifyMute];
        [action fulfill];
    } else {
        [self postCallEventNotificationWithKey:CALL_EVENT_ERROR message:@"Cannot set mute"];
        [action fail];
    }
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {
    char *dtmfDigitsToSend = (char *)[[action digits] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    int result = sendDtmfDigits(dtmfDigitsToSend);
    result == 0 ? [action fulfill] : [action fail];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    if (setHold([action isOnHold]) == 0) {
        isHold = [action isOnHold];
        [self notifyHold];
        NSLog(@"#### Hold has benn successfuly set to %s", isHold ? "TRUE" : "FALSE");
        [action fulfill];
    } else {
        [self postCallEventNotificationWithKey:CALL_EVENT_ERROR message:@"Cannot set mute"];
        [action fail];
    }
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    setAudioDevice();
//    AVAudioSession *avAudioSession = [AVAudioSession sharedInstance];
//    NSError* error;
//    NSArray *availableInputs = [avAudioSession availableInputs];
//
//    for (AVAudioSessionPortDescription *input in availableInputs) {
//        if ([input.portType isEqualToString:AVAudioSessionPortBluetoothHFP]) {
//            NSLog(@"Yess!");
//        }
//    }
//    if(![avAudioSession
//         setCategory:AVAudioSessionCategoryPlayAndRecord
//         mode:AVAudioSessionModeVoiceChat
//         options:AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP
//         error:&error]) {
//        NSLog(@"AVAudioSession error AVAudioSessionCategoryPlayAndRecord:%@", error);
//    }
//    if (![avAudioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
//        NSLog(@"AVAudioSession error overrideOutputAudioPort to Reciever:%@", error);
//    }
//    if (![avAudioSession setActive:YES error:&error]) {
//        NSLog(@"AVAudioSession error activating: %@", error);
//    }
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    AVAudioSession *avAudioSession = [AVAudioSession sharedInstance];
    NSError* error;
    if (![avAudioSession setActive:NO error:&error]) {
        NSLog(@"AVAudioSession error activating: %@", error);
    }
}

- (void)goToCalling {
    [appDelegate openCalling];
}

- (void)toggleMute {
    if (uuid == nil) {
        NSLog(@"There is no any ongoing call");
        return;
    }
    CXSetMutedCallAction *muteCallAction = [[CXSetMutedCallAction alloc] initWithCallUUID:uuid muted:!isMute];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:muteCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"MutedCallAction transaction request failed: %@", [error localizedDescription]);
            [muteCallAction fail];
        }
    }];
}

- (void)configureAudioSession {
    NSError *audioSessionCategoryError;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionCategoryError];
    NSLog(@"Setting AVAudioSessionCategory to \"Play and Record\"");
    if (audioSessionCategoryError) {
        NSLog(@"Error setting the correct AVAudioSession category");
    }
    // set the mode to voice chat
    NSError *audioSessionModeError;
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:&audioSessionModeError];
    NSLog(@"Setting AVAudioSessionCategory to \"Mode Voice Chat\"");
    if (audioSessionModeError) {
        NSLog(@"Error setting the correct AVAudioSession mode");
    }
}

- (void)sendDtmf:(nonnull NSString *) digitsString {
    CXPlayDTMFCallAction *dtmfCallAction = [[CXPlayDTMFCallAction alloc] initWithCallUUID:uuid digits:digitsString type:CXPlayDTMFCallActionTypeSingleTone];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:dtmfCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {}];
}

- (void)toggleHold {
    if (uuid == nil) {
        NSLog(@"There is no any ongoing call");
        return;
    }
    CXSetHeldCallAction *heldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:uuid onHold:!isHold];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:heldCallAction];
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"HeldCallAction transaction request failed: %@", [error localizedDescription]);
            [heldCallAction fail];
        }
    }];

}

- (void)notifyMute {
    NSMutableDictionary *obj = [NSMutableDictionary dictionary];
    [obj setObject:CALL_DATA_MUTE forKey:CALL_KEY_DATA];
    [obj setObject:(isMute ? [NSNumber numberWithInt:1] : [NSNumber numberWithInt:0]) forKey:@"result"];
    [self postCallDataNotificationWithData:obj];
}

- (void)notifyHold {
    NSMutableDictionary *obj = [NSMutableDictionary dictionary];
    [obj setObject:CALL_DATA_HOLD forKey:CALL_KEY_DATA];
    [obj setObject:(isHold ? [NSNumber numberWithInt:1] : [NSNumber numberWithInt:0]) forKey:@"result"];
    [self postCallDataNotificationWithData:obj];
}

- (void)notifyRemoteData {
    if (lastRemoteNumber == nil) {
        return;
    }
    NSMutableDictionary *obj = [NSMutableDictionary dictionary];
    [obj setObject:CALL_DATA_REMOTE forKey:CALL_KEY_DATA];
    [obj setObject:lastRemoteNumber forKey:@"remoteNumber"];
    if (lastRemoteName != nil) {
        [obj setObject:lastRemoteName forKey:@"remoteName"];
    }
    [self postCallDataNotificationWithData:obj];
}

- (void)notifyAll {
    [self notifyMute];
    [self notifyRemoteData];
    [self notifyHold];
    [self postCallEventNotificationWithKey:lastEvent message:lastMessage];
}

/* Send local notification about call data */
- (void)postCallDataNotificationWithData:(NSMutableDictionary *) data {
    if (data == nil) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:localNotificationCallData object:data];
}

/* Send local notification about call event */
- (void)postCallEventNotificationWithKey:(NSString *) eventName message:(NSString *) message {
    if (eventName == nil) {
        return;
    }
    lastEvent = eventName;
    lastMessage = message;
    NSMutableDictionary *obj = [NSMutableDictionary dictionary];
    [obj setObject:eventName forKey:CALL_KEY_EVENT];
    if (message != nil) {
        [obj setObject:message forKey:CALL_KEY_MESSAGE];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:localNotificationCallEvent object:obj];
}

- (void)setRemoteName:(nullable NSString *)remoteName {
    lastRemoteName = remoteName;
    if ([lastRemoteName isEqualToString:@"V_system00"]) {
        lastRemoteName = stringVisitor;
    }
    [self notifyRemoteData];
}

- (nullable NSString*) getRemoteName {
    return lastRemoteName;
}

- (void)setRemoteNumber:(nullable NSString *)remoteNumber {
    lastRemoteNumber = remoteNumber;
    [self notifyRemoteData];
}

- (nullable NSString*) getRemoteNumber {
    return lastRemoteNumber;
}

@end
