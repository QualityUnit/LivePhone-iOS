//
//  InitCallViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 21.3.18.
//  Copyright © 2018 Quality Unit. All rights reserved.
//

#import "InitCallViewController.h"
#import "Constants.h"
#import "AppDelegate.h"

@interface InitCallViewController () {
    @private
    NSString *contactName;
    NSString *numberToShow;
    NSString *dialString;
    AppDelegate *appDelegate;
}

@property (weak, nonatomic) IBOutlet UIButton *startCallButton;
@property (weak, nonatomic) IBOutlet UILabel *contactNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *numberLabel;

@end

@implementation InitCallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *callStartButtonTitle = stringStartOutgoing;
    [[self startCallButton] setTitle:callStartButtonTitle forState:UIControlStateNormal];
    NSString *strBack = stringBack;
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:strBack style: UIBarButtonItemStylePlain target:self action:@selector(onTapBack)];
    self.navigationItem.leftBarButtonItem = backButton;
    [[self numberLabel] setText:numberToShow];
    [[self contactNameLabel] setText:contactName];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onClickStartCall:(id)sender {
    NSString *remoteName = contactName;
    if (remoteName == nil || [remoteName length] == 0) {
        remoteName = numberToShow;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:NO completion:^{
            [[appDelegate callManager] makeCall:dialString withPrefix:@"" remoteName:remoteName];
        }];
    });
}

- (void)setData:(NSDictionary *) payloadDictionary {
    dialString = [payloadDictionary objectForKey:@"dialString"];
    contactName = [payloadDictionary objectForKey:@"contactName"];
    numberToShow = [payloadDictionary objectForKey:@"number"];
    if (contactName == nil || [contactName length] == 0) {
        contactName = @"";
    }
}

- (IBAction)onTapBack {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (currentController.presentedViewController) {
            currentController = currentController.presentedViewController;
        }
        [currentController dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
