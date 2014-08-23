//
//  BNRCloudStore.m
//  Fatchat
//
//  Created by Steve Sparks on 8/22/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BNRCloudStore.h"
#import "BNRChatChannel.h"
#import "BNRChatMessage.h"
#import "BNRChannelSubscription.h"

#import <CloudKit/CloudKit.h>

@interface BNRCloudStore()
@property (strong, nonatomic) CKDatabase *publicDB;
@property (strong, nonatomic) CKRecordZone *publicZone;
@end

NSString * const ChannelNameKey = @"channelName";
NSString * const MessageTextKey = @"text";
NSString * const AssetKey = @"asset";
NSString * const AssetTypeKey = @"assetType";
NSString * const MyIdentifierKey = @"myIdentifier";
NSString * const SubscriptionKey = @"subscription";
NSString * const SenderKey = @"sender";

NSString * const ChannelCreateType = @"channel";
NSString * const MessageType = @"message";
NSString * const SubscriptionType = @"subscription";

@interface BNRCloudStore() {
    NSString *_handle;
}
@property (copy, nonatomic) NSArray *channels;
@property (copy, nonatomic) NSArray *subscriptions;

@end

@implementation BNRCloudStore

+ (instancetype) sharedStore {
    static BNRCloudStore *theStore = nil;
    if(!theStore) {
        theStore = [[BNRCloudStore alloc] init];
    }
    return theStore;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        self.publicDB = [[CKContainer defaultContainer] publicCloudDatabase];
        self.publicZone = nil;
        self.handle = [[NSUserDefaults standardUserDefaults] valueForKey:SenderKey];
    }
    return self;
}

- (NSString *)myIdentifier {
    if(!_myIdentifier) {
        _myIdentifier = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    }
    return _myIdentifier;
}

- (NSString *)handle {
    if(!_handle) {
        _handle = [NSString stringWithFormat:@"Anon %06d", (arc4random()%1000000)];
    }
    return _handle;
}

- (void)setHandle:(NSString *)handle {
    [[NSUserDefaults standardUserDefaults] setValue:handle forKey:SenderKey];
    _handle = handle;
}

#pragma mark - Channels

/**
 *
 * 1. Channels
 *
 * Let's start with "channels". To create a channel, we save a record to the zone
 * with a RecordType of "channel". Thus searching for channels is querying for this
 * record type. Destroying a channel is simply removing this record, though it should
 * remove the appropriate messages, as well.
 *
 */
- (void)createNewChannel:(NSString *)channelName completion:(void (^)(BNRChatChannel *, NSError *))completion {
    __block BNRChatChannel *channel = [[BNRChatChannel alloc] init];
    channel.name = channelName;

    if([self.channelDelegate respondsToSelector:@selector(cloudStore:shouldCreateChannel:)]) {
        BOOL val = [self.channelDelegate cloudStore:self shouldCreateChannel:channel];
        if(!val)
            return;
    }

    CKRecord *record = [[CKRecord alloc] initWithRecordType:ChannelCreateType];
    [record setValue:channelName forKey:ChannelNameKey];

    [self.publicDB saveRecord:record completionHandler:^(CKRecord *savedRecord, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }

        if(!savedRecord) {
            channel = nil;
        }

        if(completion) {
            completion(channel, error);
        }
    }];
}

- (void)fetchChannelsWithCompletion:(void (^)(NSArray *, NSError *))completion {
    NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
    CKQuery *query = [[CKQuery alloc] initWithRecordType:ChannelCreateType predicate:predicate];
    [self.publicDB performQuery:query inZoneWithID:self.publicZone.zoneID completionHandler:^(NSArray *results, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        NSMutableArray *arr = nil;
        if(results) {
            arr = [[NSMutableArray alloc] initWithCapacity:results.count];
            for(CKRecord *record in results) {
                BNRChatChannel *channel = [[BNRChatChannel alloc] init];
                channel.name = [record valueForKey:ChannelNameKey];
                channel.createdDate = record.creationDate;
                [arr addObject:channel];
            }
        }

        // Sort by created date
        self.channels = [arr sortedArrayUsingComparator:^NSComparisonResult(BNRChatChannel *channel1, BNRChatChannel *channel2){
            return [channel1.createdDate compare:channel2.createdDate];
        }]; // property type `copy`

//        completion(self.channels, error);
        [self populateSubscriptionsWithCompletion:completion];
    }];
}

- (BNRChatChannel*)channelWithName:(NSString*)name {
    __block BNRChatChannel *ret = nil;
    [self.channels indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop){
        BNRChatChannel *channel = obj;
        if([channel.name isEqualToString:name]) {
            ret = channel;
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    return ret;
}

#pragma mark - Subscriptions

- (CKNotificationInfo *)notificationInfoForChannel:(BNRChatChannel*)channel {
    CKNotificationInfo *note = [[CKNotificationInfo alloc] init];
    note.alertBody = @"Alert Body";
    note.shouldBadge = YES;
    note.shouldSendContentAvailable = NO;
    return note;
}

- (void)subscribeToChannel:(BNRChatChannel *)channel completion:(void (^)(BNRChatChannel *, NSError *))completion {
    if(channel.subscribed)
        return;

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channelName = %@", channel.name];
    CKSubscription *subscription = [[CKSubscription alloc] initWithRecordType:MessageType predicate:predicate options:CKSubscriptionOptionsFiresOnRecordCreation];
    subscription.zoneID = self.publicZone.zoneID;
    subscription.notificationInfo = [self notificationInfoForChannel:channel];

    [self.publicDB saveSubscription:subscription completionHandler:^(CKSubscription *subscription, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        if(subscription) {
            [self recordSubscription:subscription toChannel:channel];
        }
        if(completion) {
            completion(channel, error);
        }
    }];
}

- (void)recordSubscription:(CKSubscription *)subscription toChannel:(BNRChatChannel*)channel {
    CKRecord *record = [[CKRecord alloc] initWithRecordType:SubscriptionType];
    [record setValue:channel.name forKey:ChannelNameKey];
    [record setValue:self.myIdentifier forKey:MyIdentifierKey];
    [record setValue:subscription.subscriptionID forKey:SubscriptionKey];

    [self.publicDB saveRecord:record completionHandler:^(CKRecord *record, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        
    }];
}

- (void)populateSubscriptionsWithCompletion:(void(^)(NSArray *, NSError *))completion {
    NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
    CKQuery *query = [[CKQuery alloc] initWithRecordType:SubscriptionType predicate:predicate];

    CKQueryOperation *queryOp = [[CKQueryOperation alloc] initWithQuery:query];
    NSMutableArray *subs = [[NSMutableArray alloc] init];
    queryOp.recordFetchedBlock = ^(CKRecord *record) {
        NSString *channelName = [record valueForKey:ChannelNameKey];
        BNRChatChannel *channel = [self channelWithName:channelName];
        channel.subscribed = YES;

        BNRChannelSubscription *sub = [[BNRChannelSubscription alloc] init];
        sub.recordID = record.recordID;
        sub.channel = channel;
        sub.subscription = [record valueForKey:SubscriptionKey];
        [subs addObject:sub];
    };

    queryOp.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        self.subscriptions = [subs copy];
        completion(self.channels, error);
    };

    //    [queryOp start];

    [self.publicDB performQuery:query inZoneWithID:self.publicZone.zoneID completionHandler:^(NSArray *results, NSError *error){
        for(CKRecord *record in results) {
            queryOp.recordFetchedBlock(record);
        }
        queryOp.queryCompletionBlock(nil, error);
    }];
}

- (BNRChannelSubscription*)subscriptionForChannel:(BNRChatChannel*)channel {
    BNRChannelSubscription *ret = nil;
    for(BNRChannelSubscription *sub in self.subscriptions) {
        if([sub.channel isEqual:channel]) {
            ret = sub;
        }
    }
    return ret;
}

- (void)unsubscribeFromChannel:(BNRChatChannel*)channel completion:(void (^)(BNRChatChannel *, NSError *))completion {
    if(!channel.subscribed) {
        return;
    }

    BNRChannelSubscription *sub = [self subscriptionForChannel:channel];

    NSMutableArray *arr = [self.subscriptions mutableCopy];
    [arr removeObject:sub];
    self.subscriptions = arr;

    [self.publicDB deleteSubscriptionWithID:sub.subscription.subscriptionID completionHandler:^(NSString *subscriptionId, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        [self deleteSubscriptionRecord:sub];
        if(completion) {
            completion(channel, error);
        }
    }];
}

- (void)deleteSubscriptionRecord:(BNRChannelSubscription *)channelSubscription {
    [self.publicDB deleteRecordWithID:channelSubscription.recordID completionHandler:^(CKRecordID *id, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }

    }];
}


#pragma mark - Messages

- (BNRChatMessage*)messageWithRecord:(CKRecord*)record {
    BNRChatMessage *newMessage = [[BNRChatMessage alloc] init];
    newMessage.message = [record valueForKey:MessageTextKey];
    newMessage.createdDate = record.creationDate;
    newMessage.assetType = [[record valueForKey:AssetTypeKey] integerValue];
    newMessage.senderName = [record valueForKey:SenderKey];
    if(newMessage.assetType != BNRChatMessageAssetTypeNone) {
        newMessage.asset = [record valueForKey:AssetKey];
    }

    return newMessage;
}

- (void)createNewMessageWithText:(NSString *)text assetFileUrl:(NSURL *)assetFileUrl assetType:(BNRChatMessageAssetType)assetType channel:(BNRChatChannel*)channel completion:(void (^)(BNRChatMessage *, NSError *))completion {
    NSParameterAssert(channel);
    NSParameterAssert(text);

    // Create a new CloudKit record of type "message"
    CKRecord *record = [[CKRecord alloc] initWithRecordType:MessageType];

    // Set the basic values
    [record setValue:text forKey:MessageTextKey];
    [record setValue:channel.name forKey:ChannelNameKey];
    [record setValue:self.handle forKey:SenderKey];

    // Attach an asset if given one.
    if(assetFileUrl) {
        CKAsset *asset = [[CKAsset alloc] initWithFileURL:assetFileUrl];
        [record setValue:@(assetType) forKey:AssetTypeKey];
        [record setValue:asset forKey:AssetKey];
    }

    BNRChatMessage *message = [self messageWithRecord:record];

    if([self.messageDelegate respondsToSelector:@selector(cloudStore:shouldSendMessage:onChannel:)]) {
        if([self.messageDelegate cloudStore:self shouldSendMessage:message onChannel:channel]) {
            // TODO: call completion
            return;
        }
    }

    [self.publicDB saveRecord:record completionHandler:^(CKRecord *record, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        if(completion) {
            completion(message, error);
        }
        if(record) {
            if([self.messageDelegate respondsToSelector:@selector(cloudStore:didSendMessage:onChannel:)]) {
                [self.messageDelegate cloudStore:self didSendMessage:message onChannel:channel];
            }
        }
    }];
}

- (void)fetchMessagesForChannel:(BNRChatChannel *)channel completion:(void (^)(NSArray *, NSError *))completion {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channelName = %@", channel.name];
//    NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
    NSLog(@"%@", predicate.description);
    CKQuery *query = [[CKQuery alloc] initWithRecordType:MessageType predicate:predicate];


    [self.publicDB performQuery:query inZoneWithID:self.publicZone.zoneID completionHandler:^(NSArray *results, NSError *error){
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        NSMutableArray *arr = [[NSMutableArray alloc] init];

        for (CKRecord *record in results) {
            BNRChatMessage *msg = [self messageWithRecord:record];
            [arr addObject:msg];
        }

        NSArray *sortedArray = [arr sortedArrayUsingComparator:^NSComparisonResult(BNRChatMessage*msg1, BNRChatMessage *msg2){
            return [msg1.createdDate compare:msg2.createdDate];
        }];
        completion(sortedArray, error);
    }];

    /*
    CKQueryOperation *queryOp = [[CKQueryOperation alloc] initWithQuery:query];

    NSMutableArray *arr = [[NSMutableArray alloc] init];

    queryOp.recordFetchedBlock = ^(CKRecord *record) {
        BNRChatMessage *msg = [self messageWithRecord:record];
        [arr addObject:msg];
    };

    queryOp.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
        if(error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        NSArray *sortedArray = [arr sortedArrayUsingComparator:^NSComparisonResult(BNRChatMessage*msg1, BNRChatMessage *msg2){
            return [msg1.createdDate compare:msg2.createdDate];
        }];
        completion(sortedArray, error);
    };

    [queryOp start];
     */
}

- (void)didReceiveNotification:(NSDictionary *)notificationInfo {
    
}

@end
