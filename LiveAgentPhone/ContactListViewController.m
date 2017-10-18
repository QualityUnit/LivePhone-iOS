//
//  ContactListViewController
//  LiveAgentPhone
//
//  Created by Rastislav Kostrab on 20.12.16.
//  Copyright © 2016 Quality Unit. All rights reserved.
//

#define DEFAULT_FIRST_PAGE 1
#define DEFAULT_PER_PAGE 50
#define DEFAULT_SORT_DIR @"ASC"
#define DEFAULT_SORT_FIELD @"lastname"
#define PARAM_KEY_FILTERS @"_filters"
#define PARAM_KEY_PAGE @"_page"
#define PARAM_KEY_PER_PAGE @"_perPage"
#define PARAM_KEY_SORT_DIR @"_sortDir"
#define PARAM_KEY_SORT_FIELD @"_sortField"

#import "ContactListViewController.h"
#import "Constants.h"
#import <AFNetworking/AFNetworking.h>
#import "Net.h"
#import "NSString+MD5.h"
#import "ContactsTableViewCell.h"
#import "AppDelegate.h"
#import "CallingTableViewController.h"
#import "ContactsViewController.h"
#import "ContactDetailTableViewController.h"
#import "DialpadTableViewController.h"
#import "Utils.h"

@interface ContactListViewController () {
    @private
    NSMutableArray *data;
    int currentPage;
    BOOL isLoading;
    BOOL isLastPage;
    NSString *searchTerm;
    NSURLSessionDataTask *lastTask;
    AppDelegate *appDelegate;
    ContactsViewController *contactsViewController;
    UIStoryboard *storyboard;
}
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topConstraint;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end

@implementation ContactListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    contactsViewController = [storyboard instantiateViewControllerWithIdentifier:@"ContactsViewController"];
    data = [[NSMutableArray alloc] init];
    isLoading = NO;
    isLastPage = NO;
    NSString *numberToShowInDialpad = [appDelegate getPendingPhoneNumber];
    if (numberToShowInDialpad != nil) {
        [appDelegate openDialpad:numberToShowInDialpad remoteName:nil];
    }
    if (SYSTEM_VERSION_LESS_THAN(@"11.0")) {
        [[self topConstraint] setConstant:44]; // HACK (because it is under the navigationbar)
    }
    [self clearDataAndTable];
}

-(void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    [viewController viewWillAppear:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *contactsTableViewCell = @"ContactsTableViewCell";
    ContactsTableViewCell *cell = (ContactsTableViewCell *)[tableView dequeueReusableCellWithIdentifier:contactsTableViewCell];
    NSDictionary *dataItem = [data objectAtIndex:indexPath.row];
    NSString *contactName = [Utils createContactName: dataItem];
    NSArray *emails = [dataItem objectForKey:@"emails"];
    NSString *avatarUrl = [dataItem objectForKey:@"avatar_url"];
    cell.avatarImageView.image = [UIImage imageNamed:@"DefaultAvatar"];
    if (emails != nil && [emails count] > 0) {
        NSString *firstEmail = emails[0];
        NSString *emailMd5Hash = [firstEmail MD5String];
        NSURL *gravatarUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@?d=404", emailMd5Hash]];
        [self avatarAsyncTaskWithUrl:gravatarUrl forTableView:tableView withIndexPath:indexPath onFailure:^{
            [self loadServerAvatarWithAvatarUrl:avatarUrl forTableView:tableView withIndexPath:indexPath];
        }];
    } else if (avatarUrl != nil && [avatarUrl length] > 0) {
        [self loadServerAvatarWithAvatarUrl:avatarUrl forTableView:tableView withIndexPath:indexPath];
    }
    cell.avatarImageView.frame = CGRectMake( 5, 5, 40, 40 );
    cell.avatarImageView.layer.cornerRadius = 20;
    cell.avatarImageView.layer.masksToBounds = YES;
    cell.nameLabel.text = contactName;
    return cell;
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
    if (avatarUrl != nil && [avatarUrl length] > 0) {
        NSURL *url;
        if ([avatarUrl containsString:@"__BASE_URL__"]) {
            avatarUrl = [avatarUrl stringByReplacingOccurrencesOfString:@"__BASE_URL__" withString:@"/"];
            NSString *basePath = [[NSUserDefaults standardUserDefaults] objectForKey:memoryKeyUrl];
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", basePath, avatarUrl]];
        } else {
            url = [NSURL URLWithString:avatarUrl];
        }
        [self avatarAsyncTaskWithUrl:url forTableView:tableView withIndexPath:indexPath onFailure:nil];
    }
}

- (void)avatarAsyncTaskWithUrl:(NSURL *)url forTableView:(UITableView *)tableView withIndexPath:(NSIndexPath *)indexPath onFailure:(void (^)())onFailure{
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable avatarData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (avatarData) {
            UIImage *image = [UIImage imageWithData:avatarData];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ContactsTableViewCell *updateCell = (id)[tableView cellForRowAtIndexPath:indexPath];
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
    if ([data count] == 0) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    [self getContactsWithPage:DEFAULT_FIRST_PAGE searchTerm:searchTerm];
}

-(void)didDismissSearchController:(UISearchController *)searchController {
    [self clearDataAndTable];
    searchTerm = nil;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *newSearchTerm = searchController.searchBar.text;
    if (newSearchTerm == nil || [newSearchTerm length] < 1) {
        // first time showing the search bar
        [lastTask cancel]; // cancel last call if is still loading
        [self clearDataAndTable];
        [self showMessage:nil];
        return;
    }
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    searchTerm = searchBar.text;
    [lastTask cancel]; // cancel last call if is still loading
    [self clearDataAndTable];
    [self getContactsWithPage:DEFAULT_FIRST_PAGE searchTerm:searchTerm];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    float offset = (scrollView.contentOffset.y - (scrollView.contentSize.height - scrollView.frame.size.height));
    if (offset >= 0 && offset <= 25 && !isLoading && !isLastPage){
        [self getContactsWithPage:currentPage + 1 searchTerm:searchTerm];
    }
}

- (void)getContactsWithPage:(int)page searchTerm:(nullable NSString *)term {
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
        [filters setObject:@"V" forKey:@"type"]; // this flag means 'V'isitors
        [filters setObject:@"Y" forKey:@"hasPhone"]; // this flag means that contact contains at least one phone number
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
            [requestParameters setObject:DEFAULT_SORT_DIR forKey:PARAM_KEY_SORT_DIR];
            [requestParameters setObject:DEFAULT_SORT_FIELD forKey:PARAM_KEY_SORT_FIELD];
            NSString *requestDescription = [NSString stringWithFormat:@"GET /contacts?%@=%@&%@=%@&%@=%@&%@=%@&%@=%@", PARAM_KEY_FILTERS, paramJsonStringFilters, PARAM_KEY_PAGE, pageString, PARAM_KEY_PER_PAGE, perPageString, PARAM_KEY_SORT_DIR, DEFAULT_SORT_DIR, PARAM_KEY_SORT_FIELD, DEFAULT_SORT_FIELD];
            NSLog(@"%@", requestDescription);
            lastTask = [manager GET:[NSString stringWithFormat:@"contacts"] parameters:requestParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
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
        NSArray *phones = [itemData objectForKey:@"phones"];
        if ([phones count] == 1) {
            [self goToDialpad:[phones objectAtIndex:0] calleeName:[Utils createContactName:itemData]];
        } else if ([phones count] > 1) {
            [self goToContactDetail:itemData];
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

- (void)goToContactDetail:(NSDictionary *)contactDetail {
    dispatch_async(dispatch_get_main_queue(), ^{
        [appDelegate openContactDetail:contactDetail];
    });
}

- (void)goToDialpad:(NSString *)calleeNumber calleeName:(NSString *)calleeName{
    dispatch_async(dispatch_get_main_queue(), ^{
        [appDelegate openDialpad:calleeNumber remoteName:calleeName];
    });
}

@end
