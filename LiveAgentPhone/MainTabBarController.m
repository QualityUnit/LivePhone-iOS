//
//  MainTabBarController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 18.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#define STATUS_TAB_INDEX 2

#import "MainTabBarController.h"
#import "Constants.h"
#import "Api.h"
#import "StatusTableViewController.h"

@interface MainTabBarController () {
    @private
    UITabBarItem *statusBarItem;
    StatusTableViewController *statusViewController;
}

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    statusBarItem = [[[self tabBar] items] objectAtIndex:STATUS_TAB_INDEX];
    // preload all tabs
    NSArray *vcArray = [self viewControllers];
    UINavigationController *navViewController = [vcArray objectAtIndex:STATUS_TAB_INDEX];
    statusViewController = [[navViewController viewControllers] firstObject];
    [statusViewController setMainTabBarController:self];
    [statusViewController view];
}

- (void)viewDidAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationState:) name:localNotificationApplicationState object:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onApplicationState:(NSNotification *) notification {
    NSNumber *applicationState = [notification object];
    if (applicationState == stateForeground && statusViewController != nil) {
        [statusViewController refreshAvailability];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)refreshTabItem:(NSString *)generalAvailability {
    NSString *barItemTitle;
    NSString *barItemImageName;
    if (generalAvailability == nil) {
        barItemTitle = @"";
        barItemImageName = nil;
    } else if ([generalAvailability isEqualToString:@"N"]) {
        barItemTitle = stringAvailable;
        barItemImageName = @"StatusAvailable";
    } else {
        barItemTitle = stringUnavailable;
        barItemImageName = @"StatusUnavailable";
    }
    [statusBarItem setTitle:barItemTitle];
    UIImage *image = [UIImage imageNamed:barItemImageName];
    [statusBarItem setImage:image];
    [statusBarItem setSelectedImage:image];
}

@end
