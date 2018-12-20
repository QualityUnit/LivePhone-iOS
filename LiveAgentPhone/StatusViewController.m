//
//  StatusViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 22.5.18.
//  Copyright © 2018 Quality Unit. All rights reserved.
//

#import "StatusViewController.h"
#import "StatusViewCell.h"
#import "Constants.h"
#import "Api.h"

@interface StatusViewController () {
    @private
    NSArray *data;
    NSString *generalAvailability;
    MainTabBarController *mainTabBarController;
    NSMutableDictionary *devices;
    NSLayoutConstraint *browserMessageHeight;
}
@end

@implementation StatusViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    devices = [[NSMutableDictionary alloc] init];
    [self refreshAvailability];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated {
    [self refreshAvailability];
}

- (void)notifyCallbacks {
    BOOL browserPhoneAvailable = NO;
    NSDictionary *browserDevice = [devices objectForKey:@"W"];
    if (browserDevice != nil) {
        NSString *status = [browserDevice objectForKey:@"online_status"];
        if (status != nil && [status length] > 0) {
            browserPhoneAvailable = [status isEqualToString:@"N"];
            if (browserPhoneAvailable) {
                if (![[[self stackView] arrangedSubviews] containsObject:[self messageView]]) {
                    [[self stackView] insertArrangedSubview:[self messageView] atIndex:1];
                    [[self messageView] setHidden:NO];
                }
            } else {
                [[self stackView] removeArrangedSubview:[self messageView]];
                [[self messageView] setHidden:YES];
            }
        }
    } else {
        [[self stackView] removeArrangedSubview:[self messageView]];
        [[self messageView] setHidden:YES];
    }
    BOOL mobilePhoneAvailable = NO;
    NSString *deviceId;
    NSDictionary *mobileDevice = [devices objectForKey:@"A"];
    if (mobileDevice != nil) {
        deviceId = [mobileDevice objectForKey:@"id"];
        NSString *status = [mobileDevice objectForKey:@"preset_status"];
        if (status != nil && [status length] > 0) {
            mobilePhoneAvailable = [status isEqualToString:@"N"];
            [[self mainSwitch] setOn:mobilePhoneAvailable];
        }
    }
    generalAvailability = browserPhoneAvailable || mobilePhoneAvailable ? @"N" : @"F";
    [mainTabBarController refreshTabItem:generalAvailability];
    if (mobilePhoneAvailable) {
        [self initDepartments:deviceId]; // need to be called here because 'GET /device' returns also required 'deviceId'
    } else {
        [self reloadTable:nil];
    }
}

- (void)refreshAvailability {
    if (generalAvailability == nil && data == nil) {
        [self showLoading:YES];
    }
    [Api getDevices:^(NSArray *devicesResponse) {
        [devices removeAllObjects];
        for (NSDictionary *dict in devicesResponse) {
            [devices setObject:dict forKey:[dict objectForKey:@"type"]];
        }
        [self notifyCallbacks];
    } failure:^(NSString *errorMessage) {
        [self updateAvailabilityFailure:NO errorMessage:errorMessage];
    }];
}

- (void)updateAvailability:(BOOL) isOnline {
    NSMutableDictionary *mobileDevice = [[devices objectForKey:@"A"] mutableCopy];
    [mobileDevice setObject:isOnline ? @"N" : @"F" forKey:@"preset_status"];
    [mobileDevice setObject:isOnline ? @"N" : @"F" forKey:@"online_status"];
    if (!isOnline) {
        // clear list after main switch is turned off
        [self reloadTable:nil];
    }
    [Api updateDevice:mobileDevice success:^(NSDictionary *deviceResponse) {
        [devices setObject:deviceResponse forKey:[deviceResponse objectForKey:@"type"]];
        [self notifyCallbacks];
    } failure:^(NSString *errorMessage) {
        [self updateAvailabilityFailure:!isOnline errorMessage:errorMessage];
    }];
}

- (void)reloadTable:(NSArray *)dataArray {
    data = dataArray;
    [self showLoading:NO];
    [self showMessage:nil];
    if (data == nil) {
        [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    } else if ([data count] == 0) {
        NSString *empty = stringEmpty;
        [self showMessage:empty];
    } else {
        [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    }
    [[self tableView] reloadData];
}

- (void)updateDepartment:(BOOL)isOnline index:(NSInteger)index {
    NSString *flag = isOnline ? @"N" : @"F";
    NSMutableDictionary *obj = [NSMutableDictionary dictionaryWithDictionary:[data objectAtIndex:index]];
    [obj setObject:flag forKey:@"online_status"];
    [Api updateDepartment:obj success:^(NSDictionary *response) {
        // do nothing
    } failure:^(NSString * errorMessage){
        [self showMessage:errorMessage];
    }];
}

-(void)updateAvailabilityFailure:(BOOL)restore errorMessage:(NSString *)errorMessage {
    [self showLoading:NO];
    [self showMessage:errorMessage];
}

- (void)initDepartments:(NSString*)deviceId {
    [self showLoading:YES];
    [Api getDepartmentStatusList:deviceId success:^(NSArray *responseObject){
        [self reloadTable:responseObject];
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
        [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    } else {
        [[self tableView] setBackgroundView:nil];
        [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    }
}

-(void)showMessage:(NSString *)message {
    UILabel *messageView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, self.tableView.bounds.size.height)];
    [messageView setText:message];
    [messageView setTextAlignment:NSTextAlignmentCenter];
    [messageView setNumberOfLines:3];
    [messageView setTextColor:[UIColor grayColor]];
    [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [[self tableView] setBackgroundView:messageView];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [data count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StatusViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StatusViewCell" forIndexPath:indexPath];
    NSDictionary *dataItem = [data objectAtIndex:indexPath.row];
    [[cell label] setText:[dataItem objectForKey:@"department_name"]];
    [[cell switchControl] setTag:indexPath.row];
    [[cell switchControl] setOn:[[dataItem objectForKey:@"online_status"] isEqualToString:@"N"]];
    [[cell switchControl] addTarget:self action:@selector(onDeptSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
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
