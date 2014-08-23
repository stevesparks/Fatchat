//
//  BNRChatMessage.h
//  Fatchat
//
//  Created by Steve Sparks on 8/22/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BNRChatMessageAssetType) {
    BNRChatMessageAssetTypeNone,
    BNRChatMessageAssetTypePhoto,
    BNRChatMessageAssetTypeFile
};

@interface BNRChatMessage : NSObject
@property (nonatomic) BOOL seen;
@property (nonatomic) BOOL replied;

@property (nonatomic) NSString *message;
@property (nonatomic) NSString *senderName;
@property (nonatomic) NSDate *createdDate;

@property (nonatomic) id asset;
@property (nonatomic) BNRChatMessageAssetType assetType;

- (void)loadAsset:(NSURL*)url ;

@end
