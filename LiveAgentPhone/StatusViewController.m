//
//  StatusViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 21.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "StatusViewController.h"
#import "StatusTableViewCell.h"
#import "Api.h"
#import "Constants.h"

@interface StatusViewController () {
    @private
    NSArray *data;
}
@property (weak, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UISwitch *activeSwitch;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *messageView;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation StatusViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initList];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initList {
    [self showLoading];
    [Api getDepartmentStatusList:^(NSArray *responseObject){
        data = responseObject;
        if ([responseObject count] == 0) {
            [[self tableView] setHidden:YES];
            return;
        }
        [[self tableView] setHidden:NO];
        [self showMain];
        [[self tableView] reloadData];
        dispatch_async(dispatch_get_main_queue(), ^{
            //This code will run in the main thread:
            CGRect frame = self.tableView.frame;
            frame.size.height = self.tableView.contentSize.height;
            self.tableView.frame = frame;
        });
    } failure:^(NSString *errorMessage){
        [self showError:errorMessage];
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *statusTableViewCell = @"StatusTableViewCell";
    StatusTableViewCell *cell = (StatusTableViewCell *)[tableView dequeueReusableCellWithIdentifier:statusTableViewCell];
    NSDictionary *dataItem = [data objectAtIndex:indexPath.row];
    NSString *departmentName = [dataItem objectForKey:@"department_name"];
    cell.departmentName.text = departmentName;
    BOOL isActive = [[dataItem objectForKey:@"online_status"] isEqualToString:@"N"];
    [cell.activeSwitch setOn:isActive];
    return cell;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [data count];
}

- (void)showError:(NSString *)errorMessage {
    [[self messageLabel] setText:errorMessage];
    [[self messageLabel] setHidden:NO];
    [[self activityIndicator] setHidden:YES];
    [[self mainView] setHidden:YES];
    [[self messageView] setHidden:NO];
}

- (void)showLoading {
    [[self messageLabel] setHidden:YES];
    [[self activityIndicator] setHidden:NO];
    [[self mainView] setHidden:YES];
    [[self messageView] setHidden:NO];
}

- (void)showMain {
    [[self messageLabel] setHidden:YES];
    [[self messageLabel] setText:@""];
    [[self activityIndicator] setHidden:NO];
    [[self messageView] setHidden:YES];
    [[self mainView] setHidden:NO];
}


@end
