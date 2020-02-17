//
//  XCPjsua.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.2.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//
#import "CallManager.h"

// call event keys
#define CALL_KEY_EVENT @"CALL_KEY_EVENT"
#define CALL_KEY_MESSAGE @"CALL_KEY_MESSAGE"
// call event values
#define CALL_EVENT_INITIALIZING @"INITIALIZING"
#define CALL_EVENT_REGISTERING_SIP_USER @"REGISTERING_SIP_USER"
#define CALL_EVENT_STARTING_CALL @"STARTING_CALL"
#define CALL_EVENT_CONNECTING @"CONNECTING"
#define CALL_EVENT_CALLING @"CALLING"
#define CALL_EVENT_HANGING_UP_CALL @"HANGING_UP_CALL"
#define CALL_EVENT_CALL_ENDED @"CALL_ENDED"
#define CALL_EVENT_CALL_ESTABLISHED @"CALL_ESTABLISHED"
#define CALL_EVENT_WAITING_TO_CALL @"WAITING_TO_CALL"
#define CALL_EVENT_ERROR @"ERROR"
#define CALL_EVENT_UPDATE_DURATION @"UPDATE_DURATION" //unused
#define CALL_EVENT_UPDATE_HOLD @"UPDATE_HOLD" // unused
// call data keys
#define CALL_KEY_DATA @"CALL_KEY_DATA"
// call data values
#define CALL_DATA_MUTE @"CALL_DATA_MUTE"
#define CALL_DATA_REMOTE @"CALL_DATA_REMOTE"
#define CALL_DATA_HOLD @"CALL_DATA_HOLD"

/**
 Make sip call (init pjsua, register user, make call)

 @param sipHost host name of asterisk
 @param sipUser username
 @param sipPassword password
 @param sipCalleeUri full callee uri with all prefixes and sip scheme
 */
void makeCall(NSString* sipHost, NSString* sipUser, NSString* sipPassword, NSString* sipCalleeUri, CallManager *callManager, CXStartCallAction *startCallAction);

/**
 Make sip lib ready for incomming call (init pjsua, register user)

 @param sipHost host name of asterisk
 @param sipUser username
 @param sipPassword password
 */
void incomingCall(char* sipHost, char* sipUser, char* sipPassword, CallManager *callManager);

/**
 Set audio device properly
 */
int setAudioDevice(void);


/**
 Answer ringing call

 @return 0 if OK otherwise 1
 */
int answerCall(void);

/**
 * End ongoing VoIP calls
 */
void endCall(void);


/**
 Check if pjsua library is active

 @return YES if is active otherwise NO
 */
BOOL isPjsuaRunning(void);

/**
 * Check if any ongoing call is happening right now
 */
BOOL isOngoingCall(void);

/**
 Mute or unmute microphone

 @param isMute if true then mute otherwise unmute
 @return 0 if operation has succeded otherwise 1
 */
int muteMicrophone(BOOL isMute);


/**
 Send DTMF digits

 @param digitsCharArray digits array
 @return if success return 0 otherwise 1
 */
int sendDtmfDigits(char* digitsCharArray);

/**
 Set hold
 
 @param isHold is hold?
 @return if success return 0 otherwise 1
 */
int setHold(BOOL isHold);
