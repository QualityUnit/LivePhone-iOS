//
//  ContactDetailTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 13.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "ContactDetailTableViewController.h"
#import "CallingTableViewController.h"
#import "DialpadTableViewController.h"
#import "Constants.h"
#import "Utils.h"

@interface ContactDetailTableViewController () {
    @private
    NSDictionary *contactDetail;
    NSArray *tableData;
    NSString *contactName;
}

@end

@implementation ContactDetailTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    tableData = [contactDetail objectForKey:@"phones"];
    NSString *strBack = stringBack;
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:strBack style: UIBarButtonItemStylePlain target:self action:@selector(onTapBack)];
    self.navigationItem.leftBarButtonItem = backButton;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)setContactDetail:(NSDictionary *)contactDetailToSee{
    contactDetail = contactDetailToSee;
    contactName = [Utils createContactName: contactDetail];;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    [[cell textLabel] setText:[tableData objectAtIndex:indexPath.row]];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [tableData count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [self goToDialpad:[tableData objectAtIndex:indexPath.row]];
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)goToDialpad:(NSString *)calleeNumber {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSegueWithIdentifier:@"goToDialpad" sender:calleeNumber];
    });
}

- (IBAction)onTapBack {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (currentController.presentedViewController) {
            currentController = currentController.presentedViewController;
        }
        [currentController dismissViewControllerAnimated:YES completion:nil];
    });
}

// segue stuff

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"goToDialpad"]) {
        DialpadTableViewController *dialpadTVC = [segue destinationViewController];
        [dialpadTVC setCalleeNumber:sender calleeName:contactName fromOutside:NO];
    }
}


@end
