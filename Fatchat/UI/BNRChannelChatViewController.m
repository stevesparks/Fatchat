//
//  BNRChannelChatViewController.m
//  Fatchat
//
//  Created by Steve Sparks on 8/22/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import "BNRChannelChatViewController.h"
#import "BNRCloudStore.h"
#import "BNRChatChannel.h"
#import "BNRChatMessage.h"
#import "BNRChatMessageCell.h"
#import "UITableViewCell+BNRAdditions.h"

@interface BNRChannelChatViewController()<UIAlertViewDelegate>
@property (strong, nonatomic) NSArray *messages;
@property (strong, nonatomic) NSString *otherCellText;
@end

@implementation BNRChannelChatViewController

- (instancetype)initWithChannel:(BNRChatChannel *)channel {
    self = [super init];
    if(self) {
        self.channel = channel;
        self.otherCellText = @"New message";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.channel.name;
    if(self.channel.subscribed) {
        self.navigationItem.prompt = @"Subscribed";
    }
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshData)];
    UIBarButtonItem *handleButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(promptForNewHandle)];
    UIBarButtonItem *subButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(toggleSubscription)];

    self.navigationItem.rightBarButtonItems = @[ refreshButton, handleButton, subButton ];
    [self refreshData];
}
- (void)asyncReload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });

}

- (void)refreshData {
    BNRCloudStore *store = [BNRCloudStore sharedStore];

    self.otherCellText = @"Loading...";
    [self asyncReload];

    [store fetchMessagesForChannel:self.channel completion:^(NSArray *messages, NSError *error){
        self.messages = messages;
        self.otherCellText = @"New message";
        [self asyncReload];
    }];
}


- (void) promptForNewMessage {
    NSString *message = [NSString stringWithFormat:@"%@ says...", [BNRCloudStore sharedStore].handle];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"New Message" message:message delegate:self cancelButtonTitle:@"Nevermind" otherButtonTitles:@"Say it!", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

- (void) promptForNewHandle {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"New Handle" message:@"Who will you be?" delegate:self cancelButtonTitle:@"Nevermind" otherButtonTitles:@"Rename Me", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alertView textFieldAtIndex:0].text = [BNRCloudStore sharedStore].handle;
    });
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;

    if(indexPath.row < self.messages.count) {
        BNRChatMessageCell *mCell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"];
        if(!mCell) {
            mCell = [BNRChatMessageCell bnr_instantiateCellFromNib];
        }
        BNRChatMessage *msg = self.messages[indexPath.row];
        mCell.message = msg;
        cell = mCell;
//        cell.textLabel.text = msg.message;
//        cell.detailTextLabel.text = msg.senderName;
//        cell.accessoryView = nil;
//        if(msg.fromThisDevice) {
//            cell.accessoryType = UITableViewCellAccessoryCheckmark;
//        } else {
//        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
        if(!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
        }
        cell.textLabel.text = self.otherCellText;
        cell.detailTextLabel.text = nil;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeContactAdd];
        [button addTarget:self action:@selector(promptForNewMessage) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = button;
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row < self.messages.count)
        return NO;

    [self promptForNewMessage];

    return NO;
}

- (void)toggleSubscription {
    if(self.channel.subscribed) {
        [[BNRCloudStore sharedStore] unsubscribeFromChannel:self.channel completion:^(BNRChatChannel *channel, NSError *error){
            if(error) {
                NSLog(@"Error %@", error.localizedDescription);
            }
            [self refreshData];
        }];
    } else {
        [[BNRCloudStore sharedStore] subscribeToChannel:self.channel completion:^(BNRChatChannel *channel, NSError *error){
            if(error) {
                NSLog(@"Error %@", error.localizedDescription);
            }
            [self refreshData];
        }];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(buttonIndex) {
        NSString *text = [alertView textFieldAtIndex:0].text;
        if([alertView.title isEqualToString:@"New Message"]) {
            [[BNRCloudStore sharedStore] createNewMessageWithText:text assetFileUrl:nil assetType:BNRChatMessageAssetTypeNone channel:self.channel completion:^(BNRChatMessage *msg, NSError *err){
                self.messages = [self.messages arrayByAddingObject:msg];
                [self asyncReload];
            }];
        } else {
            [[BNRCloudStore sharedStore] setHandle:text];
        }
    }
}

@end


