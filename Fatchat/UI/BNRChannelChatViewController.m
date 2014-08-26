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

@interface BNRChannelChatViewController()<UIAlertViewDelegate, UITextFieldDelegate, BNRCloudStoreMessageDelegate>
@property (strong, nonatomic) NSArray *messages;
@property (strong, nonatomic) NSString *otherCellText;
@property (strong, nonatomic) UITextField *messageTextField;
@property (weak, nonatomic) UIBarButtonItem *sendButton;
@property (weak, nonatomic) UIBarButtonItem *subscribeButton;
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
    UIBarButtonItem *subButton = [[UIBarButtonItem alloc] initWithTitle:[self subscribeButtonTitle] style:UIBarButtonItemStylePlain target:self action:@selector(toggleSubscription)];
    self.subscribeButton = subButton;

    self.navigationItem.rightBarButtonItems = @[
                                                refreshButton,
                                                subButton
                                                ];

    self.navigationController.toolbarHidden = NO;

    self.navigationController.toolbarHidden = NO;


    [self refreshDataWithCompletion:^{
            [self scrollToBottom];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [BNRCloudStore sharedStore].messageDelegate = self;
    self.messageTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    CGRect f = CGRectMake(0, 0, 200, 30);
    self.messageTextField.frame = f;
    self.messageTextField.delegate = self;
    UIBarButtonItem *textFieldButton = [[UIBarButtonItem alloc] initWithCustomView:self.messageTextField];
    UIBarButtonItem *sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(sendMessage:)];
    self.sendButton = sendButton;
    UIBarButtonItem *handleButton = [[UIBarButtonItem alloc] initWithTitle:@"Me" style:UIBarButtonItemStylePlain target:self action:@selector(promptForNewHandle)];


    UIBarButtonItem *leftSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    UIBarButtonItem *rightSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

    self.navigationController.toolbar.items = @[
                                                leftSpace,
                                                handleButton,
                                                textFieldButton,
                                                sendButton,
                                                rightSpace
                                                ];
}

- (void)viewDidDisappear:(BOOL)animated {
    [BNRCloudStore sharedStore].messageDelegate = nil;
}

- (UITextField *)messageTextField {
    if(!_messageTextField) {
        _messageTextField = [[UITextField alloc] init];
        _messageTextField.borderStyle = UITextBorderStyleRoundedRect;
    }
    return _messageTextField;
}


#pragma mark - utilities

- (void)scrollToBottom {
    if(!self.messages.count)
        return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(self.messages.count-1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    });

}

- (void)asyncReload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (NSString*)subscribeButtonTitle {
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return (self.channel.subscribed?@"Unsubscribe":@"Subscribe");
    } else {
        return (self.channel.subscribed?@"X":@"+");
    }
}

- (void)refreshData {
    [self refreshDataWithCompletion:^{
    }];
}

- (void)refreshDataWithCompletion:(void(^)(void))completion {
    BNRCloudStore *store = [BNRCloudStore sharedStore];

    self.otherCellText = @"Loading...";
    [self asyncReload];

    [store fetchMessagesForChannel:self.channel completion:^(NSArray *messages, NSError *error){
        self.messages = messages;
        self.otherCellText = @"New message";
        [self asyncReload];
        if(completion)
            completion();
    }];
}

- (IBAction)sendMessage:(UIBarButtonItem *)sender {
    NSString *text = self.messageTextField.text;
    if(text.length) {
        self.messageTextField.text = nil;
        sender.enabled = NO;
        [[BNRCloudStore sharedStore] createNewMessageWithText:text assetFileUrl:nil assetType:BNRChatMessageAssetTypeNone channel:self.channel completion:^(BNRChatMessage *msg, NSError *err){
            self.messages = [self.messages arrayByAddingObject:msg];
            [self asyncReload];
            [self scrollToBottom];
            sender.enabled = YES;
        }];
    }
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
    return self.messages.count;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;

//    if(indexPath.row < self.messages.count) {
        BNRChatMessageCell *mCell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"];
        if(!mCell) {
            mCell = [BNRChatMessageCell bnr_instantiateCellFromNib];
        }
        BNRChatMessage *msg = self.messages[indexPath.row];
        mCell.message = msg;
        cell = mCell;
//    } else {
//        cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
//        if(!cell) {
//            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
//        }
//        cell.textLabel.text = self.otherCellText;
//        cell.detailTextLabel.text = nil;
//        UIButton *button = [UIButton buttonWithType:UIButtonTypeContactAdd];
//        [button addTarget:self action:@selector(promptForNewMessage) forControlEvents:UIControlEventTouchUpInside];
//        cell.accessoryView = button;
//    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)toggleSubscription {
    if(self.channel.subscribed) {
        self.subscribeButton.title = @"Unsubscribing...";
        [[BNRCloudStore sharedStore] unsubscribeFromChannel:self.channel completion:^(BNRChatChannel *channel, NSError *error){
            if(error) {
                NSLog(@"Error %@", error.localizedDescription);
                self.subscribeButton.title = @"Error!";
            } else {
                self.channel.subscribed = NO;
                self.subscribeButton.title = [self subscribeButtonTitle];
            }
            [self refreshData];
        }];
    } else {
        [[BNRCloudStore sharedStore] subscribeToChannel:self.channel completion:^(BNRChatChannel *channel, NSError *error){
            self.subscribeButton.title = @"Subscribing...";
            if(error) {
                NSLog(@"Error %@", error.localizedDescription);
                self.subscribeButton.title = @"Error!";
            } else {
                self.channel.subscribed = YES;
                self.subscribeButton.title = [self subscribeButtonTitle];
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


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if(textField.text.length) {
        [self sendMessage:nil];
    }
    return YES;
}

#pragma mark - BNRCloudStoreMessageDelegate

- (void)cloudStore:(BNRCloudStore *)store didReceiveMessage:(BNRChatMessage *)message onChannel:(BNRChatChannel *)channel {
    
    if(![self.channel isEqual:channel]) {
        return; // not for us
    } else {
        self.messages = [self.messages arrayByAddingObject:message];
        [self asyncReload];
        [self scrollToBottom];
    }
}

@end


