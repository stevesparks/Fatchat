//
//  BNRChannelListViewController.m
//  Fatchat
//
//  Created by Steve Sparks on 8/22/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import "BNRChannelListViewController.h"
#import "BNRChatChannel.h"
#import "BNRCloudStore.h"
#import "BNRChannelChatViewController.h"

typedef NS_ENUM(NSUInteger, BNRChannelListTableSection) {
    BNRChannelListTableSectionChannels,
    BNRChannelListTableSectionNew
};

NSString * const CellIdentifier = @"CellIdentifier";

@interface BNRChannelListViewController()<UIAlertViewDelegate>
@property (strong, nonatomic) NSArray *channels;
@property (strong, nonatomic) NSString *otherCellLabel;
@end

@implementation BNRChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshData)];
    self.navigationItem.rightBarButtonItem = button;

    self.otherCellLabel = @"Loading...";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"Appear");

    [self refreshData];
}


- (void)refreshData {
    self.otherCellLabel = @"Loading...";
    [[BNRCloudStore sharedStore] fetchChannelsWithCompletion:^(NSArray *channels, NSError *error){
        NSLog(@"Data");
        self.channels = channels;
        self.otherCellLabel = @"Add a new channel";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}


- (void) promptForNewChannel {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"New Channel" message:@"Please name your new channel." delegate:self cancelButtonTitle:@"Nevermind" otherButtonTitles:@"Create", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}


#pragma mark UITableView datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch(section) {
        case BNRChannelListTableSectionChannels:
            return self.channels.count;
        case BNRChannelListTableSectionNew:
            return 1;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch(section) {
        case BNRChannelListTableSectionChannels:
            return @"Channels";
        default:
            return @"More";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    switch(indexPath.section) {
        case BNRChannelListTableSectionChannels: {
            BNRChatChannel *channel = self.channels[indexPath.row];
            cell.textLabel.text = channel.name;
            cell.accessoryView = nil;
        }
            break;
        case BNRChannelListTableSectionNew: {
            cell.textLabel.text = self.otherCellLabel;
            UIButton *button = [UIButton buttonWithType:UIButtonTypeContactAdd];
            [button addTarget:self action:@selector(promptForNewChannel) forControlEvents:UIControlEventTouchUpInside];
            cell.accessoryView = button;
        }
            break;
    }
    return cell;
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch(indexPath.section) {
        case BNRChannelListTableSectionNew: {
            [self promptForNewChannel];
        }
            break;
        case BNRChannelListTableSectionChannels: {
            BNRChatChannel *channel = self.channels[indexPath.row];
            BNRChannelChatViewController *channelViewController = [[BNRChannelChatViewController alloc] initWithChannel:channel];
            [self.navigationController pushViewController:channelViewController animated:YES];
        }
            break;
        default:
            break;
    }
}

#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(buttonIndex) {
        NSString *channelName = [alertView textFieldAtIndex:0].text;
        if(channelName.length) {
            [[BNRCloudStore sharedStore] createNewChannel:channelName completion:^(BNRChatChannel *channel, NSError *error){
                self.channels = [self.channels arrayByAddingObject:channel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }];
        }

    }
}


@end
