//
//  InternalTableViewCell.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 15.5.18.
//  Copyright © 2018 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InternalTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIView *statusView;
@property (weak, nonatomic) IBOutlet UIView *statusBackgroundView;
@property (weak, nonatomic) IBOutlet UILabel *primaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondaryLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *primaryLabelHeight;

@end
