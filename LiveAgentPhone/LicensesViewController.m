//
//  LicensesViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 14.9.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "LicensesViewController.h"
#import <WebKit/WebKit.h>

@interface LicensesViewController ()
@property (weak, nonatomic) IBOutlet WKWebView *webView;

@end

@implementation LicensesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"licenses" ofType:@"html"];
    NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
    [[self webView] loadHTMLString:htmlString baseURL: [[NSBundle mainBundle] bundleURL]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
