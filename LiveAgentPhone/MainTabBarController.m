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
#import "StatusViewController.h"

@interface MainTabBarController () {
    @private
    UITabBarItem *statusBarItem;
    StatusViewController *statusViewController;
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refreshTabItem:(BOOL)isAvailable {
    NSString *barItemTitle;
    NSString *barItemImageName;
    if (isAvailable) {
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
