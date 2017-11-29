//
//  StatusTableViewController.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 26.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainTabBarController.h"

@interface StatusTableViewController : UITableViewController

- (void)setMainTabBarController:(MainTabBarController *)mainTabBarController;
- (void)refreshAvailability;

@end
