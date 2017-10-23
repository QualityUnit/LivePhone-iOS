//
//  StatusViewController.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 21.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainTabBarController.h"

@interface StatusViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

- (void)setMainTabBarController:(MainTabBarController *)mainTabBarController;

@end
