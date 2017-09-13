//
//  CallingTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 13.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "CallingTableViewController.h"
#import "Constants.h"
#import "XCPjsua.h"
#import "Utils.h"
#import "AppDelegate.h"

@interface CallingTableViewController () {
    @private
    AppDelegate *appDelegate;
}
@property (weak, nonatomic) IBOutlet UILabel *callingWithLabel;
@property (weak, nonatomic) IBOutlet UIButton *buttonMicOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonSpeaker;
@property (weak, nonatomic) IBOutlet UIButton *buttonHold;
@property (weak, nonatomic) IBOutlet UILabel *labelState;

@end

@implementation CallingTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!isPjsuaRunning()) {
        [self finish];
    }
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callEvent:) name:localNotificationCallEvent object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callData:) name:localNotificationCallData object:nil];
    NSString *strBack = stringBack;
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:strBack style: UIBarButtonItemStylePlain target:self action:@selector(onTapBack)];
    self.navigationItem.leftBarButtonItem = backButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[appDelegate callManager] notifyAll];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)onClickHangup:(id)sender {
    [[appDelegate callManager] hangUpCurrentCall:NO callerName:nil];
}

- (void)callData:(NSNotification *)notification {
    NSDictionary *dict = [notification object];
    if (dict == nil) {
        [[self labelState] setText:@"Error in callData: notification object is NULL"];
        return;
    }
    NSString *dataType = [dict objectForKey:CALL_KEY_DATA];
    if ([dataType isEqualToString:CALL_DATA_MUTE]) {
        NSNumber *result = [dict objectForKey:@"result"];
        if ([result intValue] == -1) {
            [self showState:@"Cannot set or unset mute"];
        } else {
            [self setTintEnabled:[result intValue] onButton:[self buttonMicOff]];
        }
    } else if ([dataType isEqualToString:CALL_DATA_REMOTE]) {
        NSString *callingWith = [dict objectForKey:@"callingWith"];
        if (callingWith != nil && [callingWith length] > 0) {
            [[self callingWithLabel] setText:callingWith];
        }
    } else if ([dataType isEqualToString:CALL_DATA_SPEAKER]) {
        NSNumber *result = [dict objectForKey:@"result"];
        if ([result intValue] == -1) {
            [self showState:@"Cannot set or unset speaker"];
        } else {
            [self setTintEnabled:[result intValue] onButton:[self buttonSpeaker]];
        }
    } else if ([dataType isEqualToString:CALL_DATA_HOLD]) {
        NSNumber *result = [dict objectForKey:@"result"];
        if ([result intValue] == -1) {
            [self showState:@"Cannot set or unset hold"];
        } else {
            [self setTintEnabled:[result intValue] onButton:[self buttonHold]];
        }
    }
}

- (void)callEvent:(NSNotification *)notification {
    NSDictionary *dict = [notification object];
    if (dict == nil) {
        [[self labelState] setText:@"Error in callEvent: notification object is NULL"];
        return;
    }
    NSString *event = [dict objectForKey:CALL_KEY_EVENT];
    NSString *message = [dict objectForKey:CALL_KEY_MESSAGE];
    if ([event isEqualToString:CALL_EVENT_ERROR]) {
        [self showState:[NSString stringWithFormat:@"Error: %@", message]];
    } else {
        [self showState:event];
        if ([event isEqualToString:CALL_EVENT_CALL_ENDED]) {
            NSLog(@"#### CALLING EVENT: %@", event);
            [self finish];
        } else {
            NSLog(@"#### CALLING EVENT: %@", event);
        }
    }
}

- (void)showState:(NSString *) messageToShow {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self labelState] setText:messageToShow];
    });
}

- (void)finish {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (currentController.presentedViewController) {
            currentController = currentController.presentedViewController;
        }
        [currentController dismissViewControllerAnimated:YES completion:nil];
    });
}

- (IBAction)onClickMute:(id)sender {
    [[appDelegate callManager] toggleMute];
}

- (IBAction)onClickSpeaker:(id)sender {
    [[appDelegate callManager] toggleSpeaker];
}

- (IBAction)onClickHold:(id)sender {
    [[appDelegate callManager] toggleHold];
}

- (void)setTintEnabled:(int) enabled onButton:(id)button {
    [button setTintColor:(enabled ? [UIColor redColor] : [UIColor darkGrayColor])];
}

- (IBAction)onTapBack {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (currentController.presentedViewController) {
            currentController = currentController.presentedViewController;
        }
        [currentController dismissViewControllerAnimated:YES completion:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [appDelegate showCallFloatingButton];
        });

    });
}

@end
