//
//  XCPjsua.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.2.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <pjsua-lib/pjsua.h>
#import <UserNotifications/UserNotifications.h>
#import "Constants.h"
#import "XCPjsua.h"
#import "Utils.h"
#import <AVKit/AVKit.h>

#define CALL_DIRECTION_OUTGOING 1
#define CALL_DIRECTION_INCOMING 2
#define WAITING_TO_CALL_SEC 5


static pjsua_acc_id acc_id;

static pjsua_call_id current_call_id;
static NSLock *current_call_id_lock;
static void set_current_call_id(pjsua_call_id new_current_call_id){
    [current_call_id_lock lock];
    current_call_id = new_current_call_id;
    [current_call_id_lock unlock];
}
static NSString *sipRemoteNumber;
static NSLock *sipRemoteNumber_lock;
static void set_sipRemoteNumber(NSString* new_sipRemoteNumber){
    [sipRemoteNumber_lock lock];
    sipRemoteNumber = new_sipRemoteNumber;
    [sipRemoteNumber_lock unlock];
}
static int call_direction;
static NSLock *call_direction_lock;
static void set_call_direction(int new_call_direction){
    [call_direction_lock lock];
    call_direction = new_call_direction;
    [call_direction_lock unlock];
}
static BOOL waiting_to_call;
static NSLock *waiting_to_call_lock;
static void set_waiting_to_call(BOOL new_waiting_to_call){
    [waiting_to_call_lock lock];
    waiting_to_call = new_waiting_to_call;
    [waiting_to_call_lock unlock];
}
static BOOL hanging_up_call;
static NSLock *hanging_up_call_lock;
static void set_hanging_up_call(BOOL new_hanging_up_call){
    [hanging_up_call_lock lock];
    hanging_up_call = new_hanging_up_call;
    [hanging_up_call_lock unlock];
}
static BOOL isMissedCall;
static NSLock *isMissedCall_lock;
static void set_isMissedCall(BOOL new_isMissedCall){
    [isMissedCall_lock lock];
    isMissedCall = new_isMissedCall;
    [isMissedCall_lock unlock];
}
static CallManager *callManager;
static NSLock *callManager_lock;
static void set_callManager(CallManager* new_callManager){
    [callManager_lock lock];
    callManager = new_callManager;
    [callManager_lock unlock];
}
static CXStartCallAction *startCallAction;
static NSLock *startCallAction_lock;
static void set_startCallAction(CXStartCallAction* new_startCallAction){
    [startCallAction_lock lock];
    startCallAction = new_startCallAction;
    [startCallAction_lock unlock];
}

const size_t MAX_SIP_ID_LENGTH = 100;
const size_t MAX_SIP_REG_URI_LENGTH = 100;

// methods
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata);
static void on_call_state(pjsua_call_id call_id, pjsip_event *e);
static void on_call_media_state(pjsua_call_id call_id);
static void on_reg_state(pjsua_acc_id acc_id, pjsua_reg_info *reg_info);
void postLocalNotification(NSString *eventName ,NSString *errorMessage);
int registerSipUser(char *sipDomain, char *sipUser, char *sipPassword);
void incomingCall(char* sipHost, char* sipUser, char* sipPassword, CallManager *callManager);
int startCalling(char* destUri);
int waitForIncomingCall(void);
void destroySip(void);
NSString* retrieveRemoteNumber(char *remoteUriCharArray);
NSString* retrieveRemoteName(char *remoteUriCharArray);
pjsua_call_setting createCallSettings(void);

void checkCurrentThreadIsRegisteredWithPJSUA(void) {
    static pj_thread_desc a_thread_desc;
    static pj_thread_t *a_thread;
    if (!pj_thread_is_registered()) {
        pj_thread_register("LPPJSIP", a_thread_desc, &a_thread);
    }
}

int initAndRegister(char* sipHost, char* sipUser, char* sipPassword) {
    if (!isPjsuaRunning()) {
        postLocalNotification(CALL_EVENT_INITIALIZING, nil);
        pj_status_t status;
        status = pjsua_create();
        if (status != PJ_SUCCESS) {
            postLocalNotification(CALL_EVENT_ERROR, @"Error: 'pjsua_create()'");
            return 1;
        }
        // Configure and init pjsua
        {
            // general config
            pjsua_config cfg;
            pjsua_config_default (&cfg);
            cfg.user_agent = pj_str("Pjsua2 iOS");
            cfg.stun_host = pj_str("stun.pjsip.org");
//            cfg.thread_cnt = 1;
            // media config
            pjsua_media_config media_cfg;
            pjsua_media_config_default(&media_cfg);
            // ... set media params here
            // Callbacks
            cfg.cb.on_incoming_call = &on_incoming_call;
            cfg.cb.on_call_media_state = &on_call_media_state;
            cfg.cb.on_call_state = &on_call_state;
            cfg.cb.on_reg_state2 = &on_reg_state;
            // Logging
            pjsua_logging_config log_cfg;
            pjsua_logging_config_default(&log_cfg);
            log_cfg.console_level = 4;
            // Init pjsua
            status = pjsua_init(&cfg, &log_cfg, &media_cfg);
            if (status != PJ_SUCCESS) {
                postLocalNotification(CALL_EVENT_ERROR, @"Error: 'pjsua_init()'");
                return 1;
            }
            
        }
        // Add TCP transport.
        {
            pjsua_transport_config cfg;
            pjsua_transport_config_default(&cfg);
            cfg.port = 5080;
            status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &cfg, NULL);
            if (status != PJ_SUCCESS) {
                postLocalNotification(CALL_EVENT_ERROR, @"Error creating TCP transport");
                return 1;
            }
        }
        // Initialization is done, now start pjsua
        status = pjsua_start();
        if (status != PJ_SUCCESS) {
            postLocalNotification(CALL_EVENT_ERROR, @"Error: 'pjsua_start()'");
            return 1;
        }
        
        // deinitialization of unused codecs
        pjmedia_codec_speex_deinit();
        pjmedia_codec_ilbc_deinit();
        pjmedia_codec_gsm_deinit();
        pjmedia_codec_g722_deinit();
        
        pjsua_set_no_snd_dev(); // setting no sound devices because we do not want to block it while not calling
    }
    
    return registerSipUser(sipHost, sipUser, sipPassword);
}

int registerSipUser(char *sipDomain, char *sipUser, char *sipPassword) {
    if (hanging_up_call) {
        return 1;
    }
    postLocalNotification(CALL_EVENT_REGISTERING_SIP_USER, nil);
    pjsua_acc_config cfg;
    pjsua_acc_config_default(&cfg);
    cfg.reg_retry_interval = 0;
    char regUri[MAX_SIP_REG_URI_LENGTH];
    sprintf(regUri, "sip:%s;transport=tcp", sipDomain);
    cfg.reg_uri = pj_str(regUri);
    char sipId[MAX_SIP_ID_LENGTH];
    sprintf(sipId, "sip:%s@%s;transport=tcp", sipUser, sipDomain);
    cfg.id = pj_str(sipId);
    cfg.cred_count = 1;
    cfg.cred_info->realm = pj_str("*");
    cfg.cred_info->scheme = pj_str("digest");
    cfg.cred_info->username = pj_str(sipUser);
    cfg.cred_info->data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    cfg.cred_info->data = pj_str(sipPassword);
    pj_status_t status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
    if (status != PJ_SUCCESS) {
        postLocalNotification(CALL_EVENT_ERROR, @"Error adding sip account");
        return 1;
    }
    return 0;
}

int startCalling(char* destUri) {
    checkCurrentThreadIsRegisteredWithPJSUA();
    char destUriPostfix[] = ";transport=tcp";
    strcat(destUri, destUriPostfix);
    postLocalNotification(CALL_EVENT_STARTING_CALL, nil);
    pj_str_t uri = pj_str(destUri);
    pjsua_call_setting call_settings = createCallSettings();
    pj_status_t status;
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
//    });
    
    status = pjsua_call_make_call(acc_id, &uri, &call_settings, NULL, NULL, &current_call_id);
    if (status == PJ_SUCCESS) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [startCallAction fulfill];
        });
        
    } else {
        postLocalNotification(CALL_EVENT_ERROR, @"Error making call");
        return 1;
    }
    return 0;
}

int waitForIncomingCall(void) {
    postLocalNotification(CALL_EVENT_WAITING_TO_CALL, nil);
    set_waiting_to_call(YES);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, WAITING_TO_CALL_SEC * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (waiting_to_call) {
            NSLog(@"#### Destroying SIP because no any call has been come");
            set_waiting_to_call(NO);
            destroySip();
        } else {
            NSLog(@"#### Call has been successfuly come");
        }
    });
    return 0;
}

/* Callback called by the library when registering response come back */
static void on_reg_state(pjsua_acc_id acc_id, pjsua_reg_info *reg_info) {
    if (isOngoingCall()) {
        // skip rest of func while re-registering
        return;
    }
    if (reg_info->renew == PJ_TRUE) {
        // registration
        if (reg_info->cbparam->code / 100 == 2) {
            // success
            if (call_direction == CALL_DIRECTION_OUTGOING) {
                char *calleeSipUri = (char *)[sipRemoteNumber cStringUsingEncoding:[NSString defaultCStringEncoding]];
                startCalling(calleeSipUri);
            } else if (call_direction == CALL_DIRECTION_INCOMING) {
                waitForIncomingCall();
            } else {
                postLocalNotification(CALL_EVENT_ERROR, [NSString stringWithFormat:@"Unknown call direction %i", call_direction]);
            }
        } else {
            // failure
            postLocalNotification(CALL_EVENT_ERROR, [NSString stringWithFormat:@"failure (code=%i)", reg_info->cbparam->code]);
        }
    } else {
        // unregistration
        if (reg_info->cbparam->code / 100 == 2) {
            // success
        } else {
            // failure
            postLocalNotification(CALL_EVENT_ERROR, [NSString stringWithFormat:@"failure (code=%i)", reg_info->cbparam->code]);
        }
    }
}

/* Callback called by the library upon receiving incoming call */
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    pjsua_call_info ci;
    pjsua_call_get_info(call_id, &ci);
    if (waiting_to_call) {
        set_waiting_to_call(NO);
        char* sip_remote_uri = ci.remote_info.ptr;
        NSString *remoteNumber = retrieveRemoteNumber(sip_remote_uri);
        NSString *remoteName = retrieveRemoteName(sip_remote_uri);
        dispatch_async(dispatch_get_main_queue(), ^{
            [callManager setRemoteNumber:remoteNumber];
            [callManager setRemoteName:remoteName];
        });
        pjsua_call_answer(call_id, PJSIP_SC_RINGING, NULL, NULL);
        set_current_call_id(call_id);
        dispatch_async(dispatch_get_main_queue(), ^{
            [callManager onSipStartRinging];
        });
    } else {
        pjsua_call_answer(call_id, PJSIP_SC_BUSY_HERE, NULL, NULL);
    }
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    checkCurrentThreadIsRegisteredWithPJSUA();
    if (current_call_id != call_id) {
        // get rid of states from another calls
        NSLog(@"#### Call IDs not matching!");
        return;
    }
    PJ_UNUSED_ARG(e);
    pjsua_call_info ci;
    pjsua_call_get_info(call_id, &ci);
    pjsip_inv_state state = ci.state;
    if (state == PJSIP_INV_STATE_NULL) {
        return;
    }
//    NSLog(@"##### CALL STATE: %@", [NSString stringWithCString:ci.state_text.ptr encoding:[NSString defaultCStringEncoding]]);
    if (state == PJSIP_INV_STATE_EARLY) {
        set_isMissedCall(YES);
    } else if (state == PJSIP_INV_STATE_CALLING) {
        postLocalNotification(CALL_EVENT_CALLING, nil);
    } else if (state == PJSIP_INV_STATE_CONNECTING) {
        postLocalNotification(CALL_EVENT_CONNECTING, nil);
    } else if (state == PJSIP_INV_STATE_CONFIRMED) {
        // TODO start measure time here
        set_isMissedCall(NO);
        postLocalNotification(CALL_EVENT_CALL_ESTABLISHED, nil);
    } else if (state == PJSIP_INV_STATE_DISCONNECTED) {
        postLocalNotification(CALL_EVENT_CALL_ENDED, nil);
        [callManager hangUpCurrentCall:isMissedCall];
        
    }
    
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id) {
    checkCurrentThreadIsRegisteredWithPJSUA();
    pjsua_call_info ci;
    pjsua_call_get_info(call_id, &ci);
    NSLog(@"##### MEDIA STATE: %@", [NSString stringWithCString:ci.state_text.ptr encoding:[NSString defaultCStringEncoding]]);
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

/* retrieve number from sip URI using regex */
NSString* retrieveRemoteNumber(char *remoteUriCharArray) {
    NSString *remoteNumber = stringUnknown;
    if (remoteUriCharArray == NULL) {
        return remoteNumber;
    }
    NSString *remoteUri = [NSString stringWithCString:remoteUriCharArray encoding:NSASCIIStringEncoding];
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\<sip\\:(.+)\\@.+\\>" options:0 error:&error];
    NSArray *matches = [regex matchesInString:remoteUri options:0 range:NSMakeRange(0, [remoteUri length])];
    if (error == nil && [matches count] > 0) {
        remoteNumber = [remoteUri substringWithRange:[matches[0] rangeAtIndex:1]];
    }
    return remoteNumber;
}

/* retrieve name from sip URI using regex */
NSString* retrieveRemoteName(char *remoteUriCharArray) {
    if (remoteUriCharArray == NULL) {
        return nil;
    }
    NSString *remoteUri = [NSString stringWithCString:remoteUriCharArray encoding:NSASCIIStringEncoding];
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\"?([^\"]*)\"?\\s" options:0 error:&error];
    NSArray *matches = [regex matchesInString:remoteUri options:0 range:NSMakeRange(0, [remoteUri length])];
    if (error == nil && [matches count] > 0) {
        return [remoteUri substringWithRange:[matches[0] rangeAtIndex:1]];
    }
    return nil;
}

/* Send local notification about event */
void postLocalNotification(NSString *eventName ,NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *obj = [NSMutableDictionary dictionary];
        [obj setObject:eventName forKey:CALL_KEY_EVENT];
        if (message != nil) {
            [obj setObject:message forKey:CALL_KEY_MESSAGE];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:localNotificationCallEvent object:obj];
    });
}

/* create default call settings */
pjsua_call_setting createCallSettings(void) {
    pjsua_call_setting call_settings;
    pjsua_call_setting_default(&call_settings);
    call_settings.aud_cnt = 1;
    call_settings.vid_cnt = 0;
    call_settings.flag = 0;
    return call_settings;
}

void reInitVariables(void) {
    set_hanging_up_call(NO);
    set_waiting_to_call(NO);
    set_call_direction(0);
    set_callManager(nil);
    set_startCallAction(nil);
    set_sipRemoteNumber(nil);
    set_isMissedCall(NO);
}

void makeCall(NSString *sipHost, NSString *sipUser, NSString *sipPassword, NSString *sipCalleeUri, CallManager *cm, CXStartCallAction *sca) {
        checkCurrentThreadIsRegisteredWithPJSUA();
        reInitVariables();
        set_call_direction(CALL_DIRECTION_OUTGOING);
        set_callManager(cm);
        set_startCallAction(sca);
        set_sipRemoteNumber(sipCalleeUri);
        // make char arrays...
        char *sipHostCharArray = (char *)[sipHost cStringUsingEncoding:[NSString defaultCStringEncoding]];
        char *sipUserCharArray = (char *)[sipUser cStringUsingEncoding:[NSString defaultCStringEncoding]];
        char *sipPasswordCharArray = (char *)[sipPassword cStringUsingEncoding:[NSString defaultCStringEncoding]];
        initAndRegister(sipHostCharArray, sipUserCharArray, sipPasswordCharArray);
}

void incomingCall(char* sipHost, char* sipUser, char* sipPassword, CallManager *cm) {
    reInitVariables();
    set_call_direction(CALL_DIRECTION_INCOMING);
    set_callManager(cm);
    initAndRegister(sipHost, sipUser, sipPassword);
}

int muteMicrophone(BOOL isMute) {
    @try {
        if (isOngoingCall()) {
            pjsua_call_info ci;
            pjsua_call_get_info(current_call_id, &ci);
            if (isMute) {
                pjsua_conf_disconnect(0, ci.conf_slot);
            } else {
                pjsua_conf_connect(0, ci.conf_slot);
            }
            return 0;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Unable to mute or unmute microphone: %@", exception);
    }
    return 1;
}

BOOL isPjsuaRunning(void) {
    if (pjsua_get_state() != PJSUA_STATE_NULL) {
        return YES;
    } else {
        return NO;
    }
}

BOOL isOngoingCall(void) {
    if (isPjsuaRunning()) {
        pjsua_call_info ci;
        pjsua_call_get_info(current_call_id, &ci);
        if (ci.state != PJSIP_INV_STATE_NULL) {
            return YES;
        }
    }
    return NO;
}

int answerCall(void) {
    // this should be called only from CallKit
    if (isPjsuaRunning()) {
        pjsua_call_info ci;
        pjsua_call_get_info(current_call_id, &ci);
        if (ci.last_status == PJSIP_SC_RINGING) {
            pjsua_call_setting call_settings = createCallSettings();
            pj_status_t status = pjsua_call_answer2(current_call_id, &call_settings, PJSIP_SC_OK, NULL, NULL);
            if (status == PJ_SUCCESS) {
                return 0;
            } else {
                postLocalNotification(CALL_EVENT_ERROR, @"Cannot answer call");
            }
        }
    }
    return 1;
}

void setAudioDevice(void) {
    checkCurrentThreadIsRegisteredWithPJSUA();
    NSLog(@"#### Setting audio dev");
    pj_status_t status = pjsua_set_snd_dev(PJMEDIA_AUD_DEFAULT_CAPTURE_DEV, PJMEDIA_AUD_DEFAULT_PLAYBACK_DEV);
    if (status != PJ_SUCCESS) {
        NSLog(@"Error while setting sound devices");
    }
    NSLog(@"#### Audio dev set");
}

int sendDtmfDigits(char* digitsCharArray) {
    if (!isOngoingCall()) {
        NSLog(@"There is no any ongoing call right now");
        return 1;
    }
    pj_str_t digits = pj_str(digitsCharArray);
    pj_status_t status = pjsua_call_dial_dtmf(current_call_id, &digits);
    if (status != PJ_SUCCESS) {
        postLocalNotification(CALL_EVENT_ERROR, @"Error: 'sendDtmfDigits(char* digitsCharArray)'");
        return 1;
    }
    return 0;
}

int setHold(BOOL isHold) {
    if (isHold) {
        pj_status_t status = pjsua_call_set_hold(current_call_id, NULL);
        if (status != PJ_SUCCESS) {
            postLocalNotification(CALL_EVENT_ERROR, @"Error: 'pjsua_call_set_hold2'");
            return 1;
        }
        pjsua_set_no_snd_dev();
    } else {
        pj_status_t status = pjsua_call_reinvite(current_call_id, PJSUA_CALL_UNHOLD, NULL);
        if (status != PJ_SUCCESS) {
            postLocalNotification(CALL_EVENT_ERROR, @"Error: 'pjsua_call_reinvite2'");
            return 1;
        }
    }
    return 0;
}

void endCall(void) {
    @try {
        if (hanging_up_call) {
            NSLog(@"Call is already hanging up");
            return;
        }
        NSLog(@"##### hanging_up_call");
        if (!isPjsuaRunning()) {
            NSLog(@"Sip library is not running now");
            return;
        }
        NSLog(@"##### isPjsuaRunning");
        if (!isOngoingCall()) {
            NSLog(@"There is no any ongoing call right now");
            destroySip();
            return;
        }
        NSLog(@"##### isOngoingCall");
        set_hanging_up_call(YES);
        postLocalNotification(CALL_EVENT_HANGING_UP_CALL, nil);
        checkCurrentThreadIsRegisteredWithPJSUA();
        NSLog(@"##### checkCurrentThreadIsRegisteredWithPJSUA");
        pjsua_call_hangup_all();
        NSLog(@"##### pjsua_call_hangup_all");
        destroySip();
        NSLog(@"##### destroySip");
    }
    @catch (NSException *exception) {
        NSLog(@"Unable end call: %@", exception);
    }
}

void destroySip(void) {
    @try {
        dispatch_async(dispatch_get_main_queue(), ^{
            reInitVariables(); // we need to reinit variables beacause they are static
        });
        pjsua_destroy();
        NSLog(@"##### pjsua_destroy");
    }
    @catch (NSException *exception) {
        NSLog(@"Unable end call: %@", exception);
    }
}
