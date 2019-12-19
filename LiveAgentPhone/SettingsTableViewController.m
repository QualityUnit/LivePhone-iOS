//
//  SettingsTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "Api.h"
#import "Constants.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)logout:(id)sender {
     [Api logout:^(void){
         NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
         [defs removeObjectForKey:memoryKeyApikey];
         [defs synchronize];
         [self performSegueWithIdentifier:@"goToInitFromHome" sender:nil];
    } failure:^(NSString * errorMessage){
        NSString *strError = stringErrorTitle;
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:strError
                                     message:errorMessage
                                     preferredStyle:UIAlertControllerStyleAlert];
        NSString *strOk = stringOk;
        UIAlertAction* okButton = [UIAlertAction
                                    actionWithTitle:strOk
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
                                        // just hide dialog
                                    }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    }];
 }


@end
