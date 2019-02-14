//
//  ViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#import "LoginViewController.h"
#import <AFNetworking/AFNetworking.h>
#import "Net.h"
#import "Constants.h"
#import "ApiUrlCheck.h"
#import "Utils.h"
#import <HexColors/HexColors.h>
#import "AppDelegate.h"
#import "InitViewController.h"
#import "Api.h"

@interface LoginViewController () {
    @private
    ApiUrlCheck *currentApiUrlCheck;
    NSString *apiUrl;
    NSTimer *urlCheckTimer;
    BOOL skipUrlTimerRound;
    UITextField *activeField;
}

@property (weak, nonatomic) IBOutlet UITextField *textFieldUrl;
@property (weak, nonatomic) IBOutlet UITextField *textFieldEmail;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogin;
@property (weak, nonatomic) IBOutlet UILabel *labelError;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@end

@implementation LoginViewController

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    [self scrollView].contentInset = contentInsets;
    [self scrollView].scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your application might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, activeField.frame.origin.y-kbSize.height);
        [[self scrollView] setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    [self scrollView].contentInset = contentInsets;
    [self scrollView].scrollIndicatorInsets = contentInsets;
}

- (IBAction)onTextFieldEditBegin:(id)sender {
    activeField = sender;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [self.textFieldUrl setText:[userDefaults objectForKey:memoryKeyTypedUrl]];
    [self.textFieldEmail setText:[userDefaults objectForKey:memoryKeyTypedEmail]];
    [self fireUrlCheck];
    [self registerForKeyboardNotifications];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!urlCheckTimer) {
        urlCheckTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(onUrlCheckTimer:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:urlCheckTimer forMode:NSDefaultRunLoopMode];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[self.textFieldUrl text] forKey:memoryKeyTypedUrl];
    [userDefaults setObject:[self.textFieldEmail text] forKey:memoryKeyTypedEmail];
    [userDefaults synchronize];
    [urlCheckTimer invalidate];
    urlCheckTimer = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    if (urlCheckTimer) {
        [urlCheckTimer invalidate];
    }
}

- (IBAction)onUrlCheckTimer:(id)sender {
    if (skipUrlTimerRound) {
        skipUrlTimerRound = NO;
        return;
    }
    [self fireUrlCheck];
}

- (IBAction)onLoginButtonTap:(id)sender {
    NSString *email = [[self.textFieldEmail text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = [[self.textFieldPassword text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    // check if fields are not empty ('apiUrl' has to be initiated by URL checker)
    if ([apiUrl length] == 0 || [email length] == 0 || [password length] == 0) {
        NSString *errorMessage = errorMsgEmptyField;
        [[self labelError] setText:errorMessage];
        return;
    }
    [self loginWithUrl:apiUrl email:email password:password verificationCode:nil];
}

- (void)loginWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password verificationCode:(NSString *)verificationCode {
    [[self buttonLogin] setEnabled:NO];
    [Api loginWithUrl:apiUrl email:email password:password verificationCode:verificationCode success:^{
        [self goToInit];
    } failure:^(NSString * errorMessage){
        [[self labelError] setText:errorMessage];
        [[self buttonLogin] setEnabled:YES];
    } invalidPassword:^{
        NSString *errorMessage = stringInvalidCredentials;
        [[self labelError] setText:errorMessage];
        [[self buttonLogin] setEnabled:YES];
    } verificationCodeRequired:^{
        [self verificationCodeRequiredWithUrl:apiUrl email:email password:password];
        [[self buttonLogin] setEnabled:YES];
    } verificationCodeFailure:^{
        NSString *errorMessage = stringInvalidVerificationCode;
        [[self labelError] setText:errorMessage];
        [[self buttonLogin] setEnabled:YES];
    } tooManyLogins:^{
        NSString *errorMessage = stringTooManyLogins;
        [[self labelError] setText:errorMessage];
        [[self buttonLogin] setEnabled:YES];
    }];
}

- (void)verificationCodeRequiredWithUrl:(NSString *)apiUrl email:(NSString *)email password:(NSString *)password {
    NSString *alertTitle = stringTwoFactorTitle;
    NSString *alertMessage = stringTwoFactorMessage;
    NSString *alertOk = stringOk;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        // optionally configure the text field
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:alertOk style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = [alert.textFields firstObject];
        NSString *code = [textField text];
        [self loginWithUrl:apiUrl email:email password:password verificationCode:code];
    }];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)urlDidEndOnExit:(id)sender {
    [self.textFieldEmail becomeFirstResponder];
}

- (IBAction)emailDidEndOnExit:(id)sender {
    [self.textFieldPassword becomeFirstResponder];
}

- (IBAction)textFieldEmailOrPasswordChanged:(id)sender {
    [[self labelError] setText:@""];
}

- (IBAction)textFieldUrlChanged:(id)sender {
    [[self buttonLogin] setEnabled:NO];
    apiUrl = nil;
    [[self labelError] setText:@""];
    [[self textFieldUrl] setTextColor:[UIColor blackColor]];
    skipUrlTimerRound = YES;
    [self fireUrlCheck];
}

- (void)fireUrlCheck {
    if (currentApiUrlCheck != nil) {
        [currentApiUrlCheck terminate];
    }
    currentApiUrlCheck = [[ApiUrlCheck alloc] initWithCallbackBlock:^(NSDictionary *result){
        // URL check callback
        NSNumber *code = [result objectForKey:@"code"];
        NSString *message = [result objectForKey:@"message"];
        if (code != nil) {
            if ([code isEqualToNumber:[NSNumber numberWithInteger:urlResultOk]]) {
                apiUrl = [result objectForKey:@"apiUrl"];
                [[self buttonLogin] setEnabled:YES];
                [[self labelError] setText:@""];
                [[self textFieldUrl] setTextColor:[UIColor hx_colorWithHexRGBAString:textGreenOk]];
            } else {
                [[self textFieldUrl] setTextColor:[UIColor hx_colorWithHexRGBAString:textRedNok]];
                if (message != nil && [message length] > 0) {
                    [[self labelError] setText:message];
                }
            }
        } else {
            NSLog(@"Error: URL result code is null");
        }
    }];
    [currentApiUrlCheck startWithUrl:[[self textFieldUrl] text]];
}

- (void)goToInit {
    [self performSegueWithIdentifier:@"goToInitFromLogin" sender:nil];
}

@end
