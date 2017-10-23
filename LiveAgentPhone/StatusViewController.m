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
    MainTabBarController *tabBarController;
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationState:) name:localNotificationApplicationState object:nil];
    [self initAvailability];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onApplicationState:(NSNotification *) notification {
    NSNumber *applicationState = [notification object];
    if (applicationState == stateForeground) {
        [self initAvailability];
    }
}

- (void)initAvailability {
    [[self activeSwitch] setEnabled:NO];
    [Api getDevice:^(BOOL isOnline) {
        [self updateAvailabilitySuccess:isOnline];
        [self initList];
    } failure:^(NSString *errorMessage) {
        [self updateAvailabilityFailure:NO errorMessage:errorMessage];
    }];
}

- (void)updateAvailability:(BOOL) isAvailable {
    [[self activeSwitch] setEnabled:NO];
    [Api updateDevice:isAvailable success:^(BOOL isOnline) {
        [self updateAvailabilitySuccess:isOnline];
    } failure:^(NSString *errorMessage) {
        [self updateAvailabilityFailure:!isAvailable errorMessage:errorMessage];
    }];
}

-(void)updateAvailabilitySuccess:(BOOL)isOnline {
    [[self activeSwitch] setEnabled:YES];
    [tabBarController refreshTabItem:isOnline];
    [[self activeSwitch] setOn:isOnline];
}

-(void)updateAvailabilityFailure:(BOOL)restore errorMessage:(NSString *)errorMessage {
    [[self activeSwitch] setEnabled:YES];
    [self showError:errorMessage];
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
    cell.activeSwitch.tag = indexPath.row;
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

- (void)setMainTabBarController:(MainTabBarController *)mainTabBarController {
    tabBarController = mainTabBarController;
}
- (IBAction)activeSwitchChanged:(id)sender {
    UISwitch *s = sender;
    BOOL isActive = [s isOn];
    [self updateAvailability:isActive];
}
- (IBAction)listSwitchChanged:(id)sender {
    UISwitch *switchControl = sender;
    [switchControl setEnabled:NO];
    NSString *flag = @"F";
    if ([switchControl isOn]) {
        flag = @"N";
    }
    NSMutableDictionary *obj = [NSMutableDictionary dictionaryWithDictionary:[data objectAtIndex:[switchControl tag]]];
    [obj setObject:flag forKey:@"online_status"];
    [Api updateDepartment:obj success:^(BOOL isActive){
        [switchControl setEnabled:YES];
    } failure:^(NSString * errorMessage){
        [switchControl setEnabled:YES];
        [self showError:errorMessage];
    }];
}

@end
