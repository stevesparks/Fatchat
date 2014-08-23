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
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshData)];
    self.navigationItem.rightBarButtonItem = button;
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
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"New Message" message:@"Gimme some text!" delegate:self cancelButtonTitle:@"Nevermind" otherButtonTitles:@"Post", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }

    if(indexPath.row < self.messages.count) {
        BNRChatMessage *msg = self.messages[indexPath.row];
        cell.textLabel.text = msg.message;
        cell.detailTextLabel.text = msg.senderName;
    } else {
        cell.textLabel.text = self.otherCellText;
        cell.detailTextLabel.text = nil;
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row < self.messages.count)
        return NO;

    [self promptForNewMessage];

    return NO;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if(buttonIndex) {
        NSString *messageText = [alertView textFieldAtIndex:0].text;
        [[BNRCloudStore sharedStore] createNewMessageWithText:messageText assetFileUrl:nil assetType:BNRChatMessageAssetTypeNone channel:self.channel completion:^(BNRChatMessage *msg, NSError *err){
            self.messages = [self.messages arrayByAddingObject:msg];
            [self asyncReload];
        }];
    }
}

@end


