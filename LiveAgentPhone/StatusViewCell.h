//
//  StatusViewCell.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 26.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StatusViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UISwitch *switchControl;

@end
