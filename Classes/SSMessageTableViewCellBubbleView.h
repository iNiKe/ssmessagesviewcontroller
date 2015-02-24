//
//  SSMessageTableViewCellBubbleView.h
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//

#import "SSMessageTableViewCell.h"
#import "VKAttachments.h"

@interface SSMessageTableViewCellBubbleView : UIView {

    UIImage *bubbleImage;
    NSString *timeText;
    CGSize timeSize;
    NSMutableArray *cellImages;
    CGPoint _timeDrawOffset;
    CGPoint _imageDrawOffset;
@private
}

@property (nonatomic, strong) VKMessage *message;
@property (nonatomic, strong) UIImage *bubbleImage;
@property (nonatomic, assign) CGRect bubbleFrame, textFrame;
@property (nonatomic, assign) CGSize bubbleSize, textSize;
@property (nonatomic, assign) CGFloat textX;
@property (nonatomic, assign) BOOL selected, isChat;

+ (CGSize)textSizeForMessage:(VKMessage *)msg;
+ (CGSize)bubbleSizeForMessage:(VKMessage *)msg;
+ (CGFloat)cellHeightForMessage:(VKMessage *)msg;
- (void)updateMessageBubble;
- (BOOL)hasMessageAtLocation:(CGPoint)location;
- (CellImage *)cellImageAtLocation:(CGPoint)location;

@end
