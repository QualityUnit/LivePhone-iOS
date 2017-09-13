//
//  DialpadTableViewController.h
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DialpadTableViewController : UITableViewController <UIPickerViewDelegate, UIPickerViewDataSource>

- (void)setCalleeNumber:(NSString *)remoteNumber fromOutside:(BOOL)fromOutside;

@end
