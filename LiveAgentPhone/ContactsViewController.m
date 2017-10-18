//
//  ContactsViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 27.9.17.
//  Copyright © 2017 Quality Unit. All rights reserved.
//

#import "ContactsViewController.h"
#import "ContactListViewController.h"
#import "ContactDetailTableViewController.h"
#import "DialpadTableViewController.h"

@interface ContactsViewController () {
@private
    UISearchController *searchController;
    UIStoryboard *storyboard;
}
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationBar;

@end

@implementation ContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
    ContactListViewController *contactListViewController = [storyboard instantiateViewControllerWithIdentifier:@"ContactListViewController"];
    searchController = [[UISearchController alloc] initWithSearchResultsController:contactListViewController];
    [searchController setObscuresBackgroundDuringPresentation:YES];
    [searchController setHidesNavigationBarDuringPresentation:NO];
    [searchController setSearchResultsUpdater:contactListViewController];
    [searchController setDimsBackgroundDuringPresentation:YES];
    [searchController setDelegate:self];
    [searchController.searchBar sizeToFit];
    [searchController.searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [searchController.searchBar setReturnKeyType:UIReturnKeyDone];
    [searchController.searchBar setDelegate:contactListViewController];
    self.navigationBar.titleView = searchController.searchBar;
    self.definesPresentationContext = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [searchController.view removeFromSuperview];
}

@end
