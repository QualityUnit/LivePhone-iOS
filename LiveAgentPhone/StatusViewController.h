//
//  StatusViewController.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 22.5.18.
//  Copyright © 2018 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainTabBarController.h"

@interface StatusViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UIView *messageView;
@property (weak, nonatomic) IBOutlet UISwitch *mainSwitch;

- (void)setMainTabBarController:(MainTabBarController *)mainTabBarController;
- (void)refreshAvailability;

@end
