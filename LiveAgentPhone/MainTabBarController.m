//
//  MainTabBarController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 18.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#define CONTACTS_TAB_INDEX 0
#define STATUS_TAB_INDEX 3

#import "MainTabBarController.h"
#import "Constants.h"
#import "Api.h"
#import "ContactsViewController.h"
#import "StatusViewController.h"

@interface MainTabBarController () {
    @private
    UITabBarItem *statusBarItem;
    StatusViewController *statusViewController;
    ContactsViewController *contactViewController;
}

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    statusBarItem = [[[self tabBar] items] objectAtIndex:STATUS_TAB_INDEX];
    // preload all tabs
    NSArray *vcArray = [self viewControllers];
    
    UINavigationController *navViewControllerContacts = [vcArray objectAtIndex:CONTACTS_TAB_INDEX];
    contactViewController = [[navViewControllerContacts viewControllers] firstObject];
    
    UINavigationController *navViewControllerStatus = [vcArray objectAtIndex:STATUS_TAB_INDEX];
    statusViewController = [[navViewControllerStatus viewControllers] firstObject];
    [statusViewController view];
    [statusViewController setMainTabBarController:self];
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
    NSString *watermarkImageName;
    if (generalAvailability == nil) {
        barItemTitle = @"";
        barItemImageName = nil;
        watermarkImageName = nil;
    } else if ([generalAvailability isEqualToString:@"N"]) {
        barItemTitle = stringAvailable;
        barItemImageName = @"StatusAvailable";
        watermarkImageName = @"StatusAvailableWatermark";
    } else {
        barItemTitle = stringUnavailable;
        barItemImageName = @"StatusUnavailable";
        watermarkImageName = @"StatusUnavailableWatermark";
    }
    [statusBarItem setTitle:barItemTitle];
    UIImage *barImage = [UIImage imageNamed:barItemImageName];
    [statusBarItem setImage:barImage];
    [statusBarItem setSelectedImage:barImage];
    UIImage *watermarkImage = [UIImage imageNamed:watermarkImageName];
    [[contactViewController availabilityImage] setImage:watermarkImage];
}

@end
