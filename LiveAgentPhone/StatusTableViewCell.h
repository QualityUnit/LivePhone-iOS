//
//  StatusTableViewCell.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 22.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StatusTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *departmentName;
@property (weak, nonatomic) IBOutlet UISwitch *activeSwitch;

@end
