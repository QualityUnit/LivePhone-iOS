//
//  SettingsTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#define SECTION_LOGOUTSECTION 1
#define BUTTON_LOGOUTSECTION_LOGOUT 0

#import "SettingsTableViewController.h"
#import "Constants.h"
#import "AppDelegate.h"
#import "InitViewController.h"
#import "Api.h"

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == SECTION_LOGOUTSECTION) {
        if (indexPath.row == BUTTON_LOGOUTSECTION_LOGOUT) {
            [self onClickLogout];
        }
    }
}

-(void)onClickLogout {
    [Api updateDevice:NO success:^(BOOL isOnline){
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
