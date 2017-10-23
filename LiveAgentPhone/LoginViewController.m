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
}

@property (weak, nonatomic) IBOutlet UITextField *textFieldUrl;
@property (weak, nonatomic) IBOutlet UITextField *textFieldEmail;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPassword;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogin;
@property (weak, nonatomic) IBOutlet UILabel *labelError;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    NSLog(@"Filling text fields...");
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [self.textFieldUrl setText:[userDefaults objectForKey:memoryKeyTypedUrl]];
    [self.textFieldEmail setText:[userDefaults objectForKey:memoryKeyTypedEmail]];
    [self fireUrlCheck];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSLog(@"Saving text fields...");
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[self.textFieldUrl text] forKey:memoryKeyTypedUrl];
    [userDefaults setObject:[self.textFieldEmail text] forKey:memoryKeyTypedEmail];
    [userDefaults synchronize];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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
    [Api loginWithUrl:apiUrl email:email password:password success:^{
        [self goToInit];
    } failure:^(NSString * errorMessage){
        [[self labelError] setText:errorMessage];
    }];
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
    [self fireUrlCheck];
}

- (void)fireUrlCheck {
    [[self buttonLogin] setEnabled:NO];
    apiUrl = nil;
    [[self labelError] setText:@""];
    [[self textFieldUrl] setTextColor:[UIColor blackColor]];
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
