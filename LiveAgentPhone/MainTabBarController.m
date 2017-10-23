//
//  MainTabBarController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 18.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "MainTabBarController.h"
#import "Constants.h"
#import "Api.h"

@interface MainTabBarController ()

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshStatus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationState:) name:localNotificationApplicationState object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onApplicationState:(NSNotification *) notification {
    NSNumber *applicationState = [notification object];
    if (applicationState == stateForeground) {
        [self refreshStatus];
    }
}

- (void)refreshStatus {
    NSLog(@"Refreshing status...");
    // make call for status
    [Api getDevice:^(BOOL isOnline) {
        NSString *barItemTitle;
        NSString *barItemImageName;
        if (isOnline) {
            barItemTitle = stringAvailable;
            barItemImageName = @"StatusAvailable";
        } else {
            barItemTitle = stringUnavailable;
            barItemImageName = @"StatusUnavailable";
        }
        [[[[self tabBar] items] objectAtIndex:2] setTitle:barItemTitle];
        [[[[self tabBar] items] objectAtIndex:2] setImage:[UIImage imageNamed:barItemImageName]];
    } failure:^(NSString *errorMessage) {
        [self showError:errorMessage];
    }];
}

- (void)showError:(NSString *) errorMessage {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
