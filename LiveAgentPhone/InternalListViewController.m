//
//  InternalListViewController.m
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 15.5.18.
//  Copyright © 2018 Quality Unit. All rights reserved.
//

#define DEFAULT_FIRST_PAGE 1
#define DEFAULT_PER_PAGE 100
#define PARAM_KEY_FILTERS @"_filters"
#define PARAM_KEY_PAGE @"_page"
#define PARAM_KEY_PER_PAGE @"_perPage"

#import "InternalListViewController.h"
#import "AppDelegate.h"
#import "InternalTableViewCell.h"
#import "Utils.h"
#import "Constants.h"
#import "Net.h"
#import <HexColors/HexColors.h>

@interface InternalListViewController () {
    @private
    NSMutableArray *data;
    int currentPage;
    BOOL isLoading;
    BOOL isLastPage;
    NSString *searchTerm;
    NSURLSessionDataTask *lastTask;
    AppDelegate *appDelegate;
    UISearchController *searchController;
}
@property (weak, nonatomic) IBOutlet UINavigationItem *navigationBar;
@end

@implementation InternalListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    data = [[NSMutableArray alloc] init];
    isLoading = NO;
    isLastPage = NO;
    [self getExtensionsWithPage:DEFAULT_FIRST_PAGE searchTerm:nil];
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    [searchController.searchBar setDelegate:self];
    [searchController setHidesNavigationBarDuringPresentation:NO];
    [searchController setObscuresBackgroundDuringPresentation:NO];
    [searchController setSearchResultsUpdater:self];
    [searchController setDelegate:self];
    [searchController.searchBar sizeToFit];
    [searchController.searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [searchController.searchBar setReturnKeyType:UIReturnKeyDone];
    self.navigationBar.titleView = searchController.searchBar;
    self.definesPresentationContext = YES;
}


-(void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    [viewController viewWillAppear:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *internalTableViewCell = @"InternalTableViewCell";
    InternalTableViewCell *cell = (InternalTableViewCell *)[tableView dequeueReusableCellWithIdentifier:internalTableViewCell];
    NSDictionary *dataItem = [data objectAtIndex:indexPath.row];
    NSDictionary *agent = [dataItem objectForKey:@"agent"];
    NSDictionary *department = [dataItem objectForKey:@"department"];
    cell.statusView.backgroundColor = [self resolveStatusColor:[dataItem objectForKey:@"status"]];
    if (agent == nil || agent.count == 0) {
        // department
        cell.primaryLabelHeight.constant = 40;
        cell.secondaryLabel.hidden = YES;
        cell.avatarImageView.image = [UIImage imageNamed:@"DefaultDepartmentAvatar"];
        if (department != nil) {
            cell.primaryLabel.text = [department objectForKey:@"name"];
        }
    } else {
        // agent
        cell.primaryLabelHeight.constant = 25;
        cell.secondaryLabel.hidden = NO;
        cell.avatarImageView.image = [UIImage imageNamed:@"DefaultAvatar"];
        cell.primaryLabel.text = [agent objectForKey:@"name"];
        if (department != nil) {
            cell.secondaryLabel.text = [department objectForKey:@"name"];
        }
        NSString *avatarUrl = [agent objectForKey:@"avatar_url"];
        if ([avatarUrl containsString:@"www.gravatar.com"]) {
            // gravatar
            if ([avatarUrl hasPrefix:@"//"]) {
                avatarUrl = [@"https:" stringByAppendingString:avatarUrl];
            }
            NSURL *gravatarUrl = [NSURL URLWithString:avatarUrl];
            [self avatarAsyncTaskWithUrl:gravatarUrl forTableView:tableView withIndexPath:indexPath onFailure:nil];
        } else {
            // server avatar resource
            [self loadServerAvatarWithAvatarUrl:avatarUrl forTableView:tableView withIndexPath:indexPath];
        }
    }
    cell.avatarImageView.layer.cornerRadius = 20;
    cell.avatarImageView.layer.masksToBounds = YES;
    cell.statusBackgroundView.layer.cornerRadius = 10;
    cell.statusBackgroundView.layer.masksToBounds = YES;
    cell.statusView.layer.cornerRadius = 7.5;
    cell.statusView.layer.masksToBounds = YES;
    return cell;
}

- (HXColor *)resolveStatusColor:(NSString *)status {
    const NSString *STATUS_ACTIVE = @"A";
    const NSString *STATUS_ENABLED = @"E";
    const NSString *STATUS_DISABLED = @"D";
    if ([STATUS_ACTIVE isEqualToString:status]) {
        return [UIColor hx_colorWithHexRGBAString:statusActive];
    } else if ([STATUS_ENABLED isEqualToString:status]) {
        return [UIColor hx_colorWithHexRGBAString:statusEnabled];
    } else if ([STATUS_DISABLED isEqualToString:status]) {
        return [UIColor hx_colorWithHexRGBAString:statusDisabled];
    }
    return [UIColor whiteColor];
}

- (void)showMessage:(NSString *)message {
    if (message == nil || [message length] == 0) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.tableView.backgroundView = nil;
    } else {
        UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, self.tableView.bounds.size.height)];
        messageLabel.text = message;
        messageLabel.textColor = [UIColor grayColor];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        self.tableView.backgroundView = messageLabel;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
}

- (void)loadServerAvatarWithAvatarUrl:(NSString *)avatarUrl forTableView:(UITableView *)tableView withIndexPath:(NSIndexPath *)indexPath {
    if (avatarUrl == nil || [avatarUrl length] == 0) {
        return;
    }
    NSString *basePath = [[NSUserDefaults standardUserDefaults] objectForKey:memoryKeyUrl];
    avatarUrl = [avatarUrl stringByReplacingOccurrencesOfString:@"__BASE_URL__" withString:@"/"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", basePath, avatarUrl]];
    [self avatarAsyncTaskWithUrl:url forTableView:tableView withIndexPath:indexPath onFailure:nil];
}

- (void)avatarAsyncTaskWithUrl:(NSURL *)url forTableView:(UITableView *)tableView withIndexPath:(NSIndexPath *)indexPath onFailure:(void (^)(void))onFailure{
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable avatarData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (avatarData) {
            UIImage *image = [UIImage imageWithData:avatarData];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    InternalTableViewCell *updateCell = (id)[tableView cellForRowAtIndexPath:indexPath];
                    if (updateCell)
                        updateCell.avatarImageView.image = image;
                });
            } else {
                if (onFailure != nil) {
                    onFailure();
                }
            }
        }
    }];
    [task resume];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [data count];
}

- (IBAction)onRefresh:(id)sender {
    [lastTask cancel]; // cancel last call if is still loading
    [self getExtensionsWithPage:DEFAULT_FIRST_PAGE searchTerm:searchTerm];
}

-(void)didDismissSearchController:(UISearchController *)searchController {
    [self clearDataAndTable];
    [self getExtensionsWithPage:DEFAULT_FIRST_PAGE searchTerm:nil];
    searchTerm = nil;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *newSearchTerm = searchController.searchBar.text;
    if (newSearchTerm == nil || [newSearchTerm length] < 1) {
        // first time showing the search bar
        [lastTask cancel]; // cancel last call if is still loading
        [self showMessage:nil];
        return;
    }
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    searchTerm = searchBar.text;
    [lastTask cancel]; // cancel last call if is still loading
    [self clearDataAndTable];
    [self getExtensionsWithPage:DEFAULT_FIRST_PAGE searchTerm:searchTerm];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    float offset = (scrollView.contentOffset.y - (scrollView.contentSize.height - scrollView.frame.size.height));
    if (offset >= 0 && offset <= 25 && !isLoading && !isLastPage){
        [self getExtensionsWithPage:currentPage + 1 searchTerm:searchTerm];
    }
}

- (void)getExtensionsWithPage:(int)page searchTerm:(nullable NSString *)term {
    isLoading = YES;
    [lastTask cancel]; // cancel last call if is still loading
    [self showMessage:nil];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    spinner.frame = CGRectMake(0, 0, 320, 50);
    self.tableView.tableFooterView = spinner;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableDictionary *filters = [[NSMutableDictionary alloc] init];
        // put filters here
        [filters setObject:@"A,E" forKey:@"computed_status"];
        if (term != nil && [term length] > 0) {
            [filters setObject:term forKey:@"q"];
        }
        NSError *jsonError;
        NSData *jsonFilters = [NSJSONSerialization dataWithJSONObject:filters options:0 error:&jsonError];
        if (jsonFilters) {
            AFHTTPSessionManager *manager = [Net createSessionManager];
            NSString *paramJsonStringFilters = [[NSString alloc] initWithData:jsonFilters encoding:NSUTF8StringEncoding];
            NSString *pageString = [NSString stringWithFormat:@"%d", page];
            NSString *perPageString = [NSString stringWithFormat:@"%d", DEFAULT_PER_PAGE];
            NSMutableDictionary *requestParameters = [[NSMutableDictionary alloc] init];
            [requestParameters setObject:paramJsonStringFilters forKey:PARAM_KEY_FILTERS];
            [requestParameters setObject:pageString forKey:PARAM_KEY_PAGE];
            [requestParameters setObject:perPageString forKey:PARAM_KEY_PER_PAGE];
            NSString *requestDescription = [NSString stringWithFormat:@"GET /extensions?%@=%@&%@=%@&%@=%@", PARAM_KEY_FILTERS, paramJsonStringFilters, PARAM_KEY_PAGE, pageString, PARAM_KEY_PER_PAGE, perPageString];
            NSLog(@"%@", requestDescription);
            lastTask = [manager GET:[NSString stringWithFormat:@"extensions"] parameters:requestParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
                [[self refreshControl] endRefreshing];
                NSLog(@"SUCCESS '%@'", requestDescription);
                if (page == DEFAULT_FIRST_PAGE) {
                    isLastPage = NO;
                    [self clearDataAndTable];
                }
                self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
                NSMutableArray *indexPaths = [NSMutableArray array];
                NSInteger currentCount = data.count;
                for (int i = 0; i < [responseObject count]; i++) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:currentCount + i inSection:0]];
                }
                [data addObjectsFromArray:responseObject];
                [self.tableView beginUpdates];
                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                [self.tableView endUpdates];
                self.tableView.tableFooterView = nil;
                currentPage = page;
                if ([responseObject count] < DEFAULT_PER_PAGE) {
                    isLastPage = YES;
                }
                isLoading = NO;
                if ([data count] == 0) {
                    NSString *emptyText;
                    if (term != nil && [term length] > 0) {
                        emptyText = stringNoResults;
                        emptyText = [emptyText stringByReplacingOccurrencesOfString:@"%s" withString:term];
                    } else {
                        emptyText = stringEmpty;
                    }
                    [self showMessage:emptyText];
                }
            } failure:^(NSURLSessionTask *operation, NSError *error) {
                [[self refreshControl] endRefreshing];
                if ([error code] == NSURLErrorCancelled) {
                    return; // and keep UI in refreshing state because cancelled request are only in case when another request cancels previous
                }
                self.tableView.tableFooterView = nil;
                isLoading = NO;
                NSString *errorMessage = [error localizedDescription];
                NSLog(@"FAILURE '%@' - %@", requestDescription, errorMessage);
                [self errorAlertWithMessage:errorMessage];
            }];
        }
        
    });
}

- (void)clearDataAndTable {
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (int i = 0; i < [data count]; i++) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
    [data removeAllObjects];
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationRight];
    [self.tableView endUpdates];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self showMessage:@""];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,10)]; // empty view to hide empty list
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSDictionary *itemData = [data objectAtIndex:indexPath.row];
        NSString *number = [itemData objectForKey:@"number"];
        if (number != nil && number.length > 0) {
            NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
            [payload setObject:number forKey:@"number"];
            [payload setObject:number forKey:@"dialString"];
            NSDictionary *agent = [itemData objectForKey:@"agent"];
            NSDictionary *department = [itemData objectForKey:@"department"];
            if (agent == nil || agent.count == 0) {
                [payload setObject:[department objectForKey:@"name"] forKey:@"contactName"];
            } else if (department != nil) {
                [payload setObject:[agent objectForKey:@"name"] forKey:@"contactName"];
            }
            [appDelegate openInitCall:payload];
        }
        [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)errorAlertWithMessage:(NSString *)errorMessage {
    NSString *title = stringErrorTitle;
    NSString *ok = stringOk;
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:title
                                 message:errorMessage
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* actionOk = [UIAlertAction
                               actionWithTitle:ok
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   [alert dismissViewControllerAnimated:YES completion:nil];
                               }];
    [alert addAction:actionOk];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
