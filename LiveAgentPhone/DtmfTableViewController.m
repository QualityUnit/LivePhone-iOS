//
//  DtmfTableViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 6.5.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "DtmfTableViewController.h"
#import "AppDelegate.h"

@interface DtmfTableViewController () {
    @private
    NSUInteger lastLength;
}
@property (weak, nonatomic) IBOutlet UITextField *textFieldDtmf;

@end

@implementation DtmfTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void) viewDidAppear:(BOOL)animated {
    [self.textFieldDtmf becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)onDtmfTextChanged:(id)sender {
    NSString *text = [[self textFieldDtmf] text];
    NSUInteger currentLength = [text length];
    if (currentLength > lastLength) {
        [self sendDtmfWithString:[text substringFromIndex:lastLength]];
    }
    lastLength = currentLength;
}

- (void)sendDtmfWithString:(NSString *) digitsString {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[appDelegate callManager] sendDtmf:digitsString];
}


@end
