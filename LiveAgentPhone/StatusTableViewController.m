//
//  StatusTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 26.10.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "StatusTableViewController.h"
#import "StatusViewCell.h"
#import "Constants.h"
#import "Api.h"

#define SECTION_MAIN 0
#define SECTION_DEPT 1

@interface StatusTableViewController () {
    @private
    NSArray *data;
    NSString *generalAvailability;
    MainTabBarController *mainTabBarController;
}

@end

@implementation StatusTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshAvailability];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)refreshAvailability {
    if (generalAvailability == nil && data == nil) {
        [self showLoading:YES];
    }
    [Api getDevice:^(BOOL isOnline) {
        generalAvailability = isOnline ? @"N" : @"F";
        [mainTabBarController refreshTabItem:generalAvailability];
        [self initDepartments]; // need to be called here because 'GET /device' returns also required 'deviceId'
    } failure:^(NSString *errorMessage) {
        [self showLoading:NO];
        [self updateAvailabilityFailure:NO errorMessage:errorMessage];
    }];
}

- (void)updateAvailability:(BOOL) isOnline {
    generalAvailability = isOnline ? @"N" : @"F";
    [mainTabBarController refreshTabItem:generalAvailability];
    [Api updateDevice:isOnline success:^(BOOL isAvailable) {
        // do nothing
    } failure:^(NSString *errorMessage) {
        [self updateAvailabilityFailure:!isOnline errorMessage:errorMessage];
    }];
}

- (void)updateDepartment:(BOOL)isOnline index:(NSInteger)index {
    NSString *flag = isOnline ? @"N" : @"F";
    NSMutableDictionary *obj = [NSMutableDictionary dictionaryWithDictionary:[data objectAtIndex:index]];
    [obj setObject:flag forKey:@"online_status"];
    [Api updateDepartment:obj success:^(BOOL isAvailable) {
        // do nothing
    } failure:^(NSString * errorMessage){
        [self showMessage:errorMessage];
    }];
}

-(void)updateAvailabilityFailure:(BOOL)restore errorMessage:(NSString *)errorMessage {
    [self showMessage:errorMessage];
}

- (void)initDepartments {
    [Api getDepartmentStatusList:^(NSArray *responseObject){
        data = responseObject;
        if ([responseObject count] == 0) {
            NSIndexSet *section = [NSIndexSet indexSetWithIndex:SECTION_DEPT];
            [[self tableView] deleteSections:section withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
        [self showLoading:NO];
        [[self tableView] reloadData];
    } failure:^(NSString *errorMessage){
        [self showLoading:NO];
        [self showMessage:errorMessage];
    }];
}

- (void)setMainTabBarController:(MainTabBarController *)mtbc {
    mainTabBarController = mtbc;
}

-(void)showLoading:(BOOL)isLoading {
    if (isLoading) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityIndicator startAnimating];
        [[self tableView] setBackgroundView:activityIndicator];
    } else {
        [[self tableView] setBackgroundView:nil];
    }
}

-(void)showMessage:(NSString *)message {
    generalAvailability = nil;
    data = nil;
    [[self tableView] reloadData];
    UILabel *messageView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, self.tableView.bounds.size.height)];
    [messageView setText:message];
    [messageView setTextAlignment:NSTextAlignmentCenter];
    [messageView setNumberOfLines:3];
    [[self tableView] setBackgroundView:messageView];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == SECTION_MAIN) {
        return generalAvailability == nil ? 0 : 1;
    } else if (section == SECTION_DEPT) {
        return [data count];
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *statusViewCell = @"StatusViewCell";
    StatusViewCell *cell = [tableView dequeueReusableCellWithIdentifier:statusViewCell forIndexPath:indexPath];
    if ([indexPath section] == SECTION_MAIN) {
        NSString *labelText = stringAvailable;
        [[cell label] setText:labelText];
        [[cell switchControl] setOn:[generalAvailability isEqualToString:@"N"]];
        [[cell switchControl] addTarget:self action:@selector(onMainSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
    } else if ([indexPath section] == SECTION_DEPT) {
        NSDictionary *dataItem = [data objectAtIndex:indexPath.row];
        [[cell label] setText:[dataItem objectForKey:@"department_name"]];
        [[cell switchControl] setTag:indexPath.row];
        [[cell switchControl] setOn:[[dataItem objectForKey:@"online_status"] isEqualToString:@"N"]];
        [[cell switchControl] addTarget:self action:@selector(onDeptSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return cell;
}

- (IBAction)onMainSwitchValueChanged:(id)sender {
    UISwitch *s = sender;
    [self updateAvailability:[s isOn]];
}

- (IBAction)onDeptSwitchValueChanged:(id)sender {
    UISwitch *s = sender;
    [self updateDepartment:[s isOn] index:[s tag]];
}

@end
