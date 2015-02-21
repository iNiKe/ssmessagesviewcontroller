//
//  SSMessageTableViewCell.m
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//

#import "SSMessageTableViewCell.h"
#import "SSMessageTableViewCellBubbleView.h"
#import "NKUtils.h"

@implementation SSMessageTableViewCell

static UIImage *VKPlaceholderImage = nil;
static UIColor *unreadColor = nil;

@synthesize timeLabel, avatarImageView, isChat, isRead, bubbleSize, bubbleView;

#pragma mark NSObject

+ (void)initialize
{
	if(self == [SSMessageTableViewCell class])
	{
        VKPlaceholderImage = [UIImage imageWithContentsOfResolutionIndependentFile:kVKPlaceholderImage];
        if ( !unreadColor )
            unreadColor = [UIColor colorWithRed:197.0/255.0 green:206.0/255.0 blue:221.0/255.0 alpha:0.6];
    }
}

- (void)dealloc {
    
}


#pragma mark UITableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;		
		self.textLabel.hidden = YES;
				
		bubbleView = [[SSMessageTableViewCellBubbleView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.contentView.frame.size.width, self.contentView.frame.size.height)];
		bubbleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:bubbleView];
        avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(6.0, 3.0, 28.0, 28.0)];
        avatarImageView.layer.masksToBounds = YES;
        avatarImageView.layer.cornerRadius = 14.0;
        avatarImageView.layer.opaque = NO;
        [self addSubview:avatarImageView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect frame;
    CGFloat cw = self.contentView.frame.size.width;
//    CGSize sz = [timeLabel.text sizeWithFont:timeLabel.font];
//    CGSize bsz = [SSMessageTableViewCellBubbleView bubbleSizeForText:_bubbleView.messageText];
//    CGSize bsz = [SSMessageTableViewCellBubbleView bubbleSizeForText:_bubbleView.message.body];
    if ( !self.message.messageRightAlign )
    {
        frame = avatarImageView.frame;
        frame.origin.x = 4;
        frame.origin.y = bubbleView.frame.size.height - 28;
        avatarImageView.frame = frame;
    }
    else
    {
        frame = avatarImageView.frame;
        frame.origin.x = cw - 32;
        frame.origin.y = bubbleView.frame.size.height - 28;
        avatarImageView.frame = frame;
    }
}

#pragma mark Getters

- (VKMessage *)message {
    return bubbleView.message;
}

#pragma mark Setters

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    self.bubbleView.selected = selected;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    self.bubbleView.selected = selected;
}

- (void)setIsRead:(BOOL)isRead_ {
//    if (self->isRead != isRead_)
    {
        if ( !isRead_ ) {
            self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
            self.backgroundView.backgroundColor = unreadColor;
        }
        else {
            self.backgroundView = nil;
            self.backgroundColor = [UIColor clearColor];
        }
        self->isRead = isRead_;
        [self setNeedsDisplay];
    }
}

- (void)setMessage:(VKMessage *)newMessage {
    bubbleView.message = newMessage;
    bubbleView.isChat = self.isChat;
    if ( self.isChat )
    {
        if ( !newMessage.contact )
            newMessage.contact = [VK contactById:newMessage.fromId];
        if ( newMessage.contact && newMessage.contact.photo )
        {
            __block id this = self;
            __block id ava = avatarImageView;
            [avatarImageView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:newMessage.contact.photo]] placeholderImage:VKPlaceholderImage success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                ((UIImageView *)ava).image = image;
                [((SSMessageTableViewCell *)this) setNeedsDisplay];
                [this setNeedsLayout];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                
            }];
        }
        else
            avatarImageView.image = VKPlaceholderImage;
    }
    [self setIsRead:newMessage.isRead];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage forMessageStyle:(SSMessageStyle)messsageStyle {
    self.backgroundView = nil;
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
}

@end
