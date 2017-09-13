//
//  DialpadTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 7.3.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#define SECTION_CALL_BUTTON 2
#define PARAM_KEY_FILTERS @"_filters"

#import "DialpadTableViewController.h"
#import "Net.h"
#import "Constants.h"
#import "Utils.h"
#import "CallingTableViewController.h"
#import "AppDelegate.h"
#import "Utils.h"

@interface DialpadTableViewController () {
    @private
    NSMutableArray *numberPickerData;
    NSArray *phoneNumbersResponse;
    NSString *calleeNumberFromContacts;
    BOOL isFromOutside;
}
@property (weak, nonatomic) IBOutlet UITextField *numberTextField;
@property (weak, nonatomic) IBOutlet UIPickerView *numberPicker;
@property (weak, nonatomic) IBOutlet UIView *errorView;
@property (weak, nonatomic) IBOutlet UILabel *errorMessage;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *noNumbersLabel;
@property (weak, nonatomic) IBOutlet UIButton *makeCallButton;
@property (weak, nonatomic) IBOutlet UILabel *errorPhoneNumberEmpty;

@end

@implementation DialpadTableViewController {
    @private
    AppDelegate *appDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.numberPicker.delegate = self;
    self.numberPicker.dataSource = self;
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    numberPickerData = [[NSMutableArray alloc] init];
    if (calleeNumberFromContacts != nil && [calleeNumberFromContacts length] > 0) {
        [[self numberTextField] setText:calleeNumberFromContacts];
    }
    [self getPhoneNumbers];
    if (isFromOutside) {
        NSString *strBack = stringBack;
        UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:strBack style: UIBarButtonItemStylePlain target:self action:@selector(onTapBack)];
        self.navigationItem.leftBarButtonItem = backButton;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)onCalleeNumberValueChanged:(id)sender {
    [self.makeCallButton setHidden:NO];
    [self.errorPhoneNumberEmpty setHidden:YES];
}

- (IBAction)onClickMakeCall:(id)sender {
    [self.view endEditing:YES];
    NSString *calleeNumber = [[self numberTextField] text];
    if ([calleeNumber length] == 0) {
        [self.makeCallButton setHidden:YES];
        [self.errorPhoneNumberEmpty setHidden:NO];
        return;
    }
    if (phoneNumbersResponse == nil || [phoneNumbersResponse count] == 0) {
        // error message for user has been already showed in time response come
        return;
    }
    NSDictionary *selectedItemFromNumberPicker = phoneNumbersResponse[[self.numberPicker selectedRowInComponent:0]];
    int prefixInt = [[selectedItemFromNumberPicker valueForKey:@"dial_out_prefix"] intValue];
    NSString *calleePrefix = [Utils prefixToTwoDigitsWIthPrefixInt:prefixInt];
    [[appDelegate callManager] makeCall:calleeNumber withPrefix:calleePrefix];
}

- (IBAction)onClickRetry:(id)sender {
    [self getPhoneNumbers];
}

- (void)getPhoneNumbers {
    [self.numberPicker setHidden:YES];
    [self.activityIndicator setHidden:NO];
    [self.noNumbersLabel setHidden:YES];
    [self.errorView setHidden:YES];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *filters = [[NSMutableDictionary alloc] init];
        // put filters here
        [filters setObject:@"S" forKey:@"type"]; // this flag means 'V'isitors
        NSError *jsonError;
        NSData *jsonFilters = [NSJSONSerialization dataWithJSONObject:filters options:0 error:&jsonError];
        if (jsonFilters == nil) {
            NSLog(@"Error: json serialization in getPhoneNumbers");
            return;
        }
        NSString *paramJsonStringFilters = [[NSString alloc] initWithData:jsonFilters encoding:NSUTF8StringEncoding];
        NSMutableDictionary *requestParameters = [[NSMutableDictionary alloc] init];
        [requestParameters setObject:paramJsonStringFilters forKey:PARAM_KEY_FILTERS];
        NSString *requestDescription = [NSString stringWithFormat:@"GET /phone_numbers?%@=%@", PARAM_KEY_FILTERS, paramJsonStringFilters];
        NSLog(@"%@", requestDescription);
        AFHTTPSessionManager *manager = [Net createSessionManager];
        [manager GET:@"phone_numbers" parameters:requestParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            NSLog(@"SUCCESS '%@'", requestDescription);
            if (responseObject != nil && [responseObject isKindOfClass:[NSArray class]]) {
                phoneNumbersResponse = responseObject;
                [self.activityIndicator setHidden:YES];
                if ([phoneNumbersResponse count] == 0) {
                    [self.noNumbersLabel setHidden:NO];
                } else {
                    for (id item in phoneNumbersResponse) {
                        NSString *number = [item objectForKey:@"number"];
                        NSString *name = [item objectForKey:@"name"];
                        if (number != nil && [number length] > 0) {
                            if (name != nil && ![name isEqualToString:number]) {
                                [numberPickerData addObject:[NSString stringWithFormat:@"%@ | %@", name, number]];
                            } else {
                                [numberPickerData addObject:number];
                            }
                        }
                    }
                    [self.numberPicker reloadAllComponents];
                    [self.numberPicker setHidden:NO];
                }
            } else {
                NSString *errorMessage = errorMsgCannotParseResponse;
                [self showError:errorMessage];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
            }
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSString *errorMessage = [error localizedDescription];
            [self showError:errorMessage];
            NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
        }];
    });
}

- (void)showError:(NSString *)errorMessage {
    NSLog(@"%@", errorMessage);
    [self.activityIndicator setHidden:YES];
    [self.noNumbersLabel setHidden:YES];
    [self.errorMessage setText:errorMessage];
    [self.errorView setHidden:NO];
}

- (void)setCalleeNumber:(NSString *)remoteNumber fromOutside:(BOOL)fromOutside {
    calleeNumberFromContacts = remoteNumber;
    isFromOutside = fromOutside;
}

// picker view stuff

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [numberPickerData count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return numberPickerData[row];
}

// setting headers and footers heights

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section{
    if (section == SECTION_CALL_BUTTON) {
        // less height for this section
        return 15.0;
    }
    return 30.0;
}

- (CGFloat)tableView:(UITableView*)tableView heightForFooterInSection:(NSInteger)section{
    return 1.0;
}

- (UIView*)tableView:(UITableView*)tableView viewForFooterInSection:(NSInteger)section{
    return [[UIView alloc] initWithFrame:CGRectZero];
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

@end
