//
//  SSMessageTableViewCell.h
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//

typedef enum {
	SSMessageStyleLeft = 0,
	SSMessageStyleRight = 1
} SSMessageStyle;

@class SSMessageTableViewCellBubbleView;

@interface SSMessageTableViewCell : UITableViewCell 
{
    BOOL isChat;
}

@property (nonatomic, strong) VKMessage *message;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, assign) BOOL isChat, isRead;
@property (nonatomic, assign) CGSize bubbleSize;
@property (nonatomic, strong) SSMessageTableViewCellBubbleView *bubbleView;

- (void)setBackgroundImage:(UIImage *)backgroundImage forMessageStyle:(SSMessageStyle)messsageStyle;

@end
