//
//  SSMessageTableViewCellBubbleView.m
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//

#import "SSMessageTableViewCellBubbleView.h"
#import "NKUtils.h"
#import "NKDates.h"
#import "UIImageView+AFNetworking.h"
#import "VKontakte.h"

static UIFont *textFont = nil;
static UIFont *timeFont = nil;
static NSLineBreakMode kLineBreakMode = NSLineBreakByWordWrapping;
//static CGFloat kMaxWidth = 223.0f; // TODO: Make dynamic
static CGFloat kPaddingTop = 4.0f;
static CGFloat kPaddingBottom = 8.0f;
static CGFloat kMarginTop = 2.0f;
static CGFloat kMarginBottom = 2.0f;
//static UIImage *leftBackgroundImage = nil;
//static UIImage *rightBackgroundImage = nil;
static UIImage *VKPlaceholderImage = nil;
static UIColor *timeColor = nil;
static UIColor *textColor = nil;
static UIColor *textSelectedColor = nil;
static UIColor *backgroundColor = nil;
static UIImage *leftBubble = nil;
static UIImage *leftBubbleSelected = nil;
static UIImage *rightBubble = nil;
static UIImage *rightBubbleSelected = nil;
static CGFloat chatOfs = 35.0;
static CGFloat screenScale = 0.0;
static UIImage *photoPlaceholder = nil;


@implementation SSMessageTableViewCellBubbleView

@synthesize message;
@synthesize bubbleImage;
@synthesize bubbleFrame, textFrame;
@synthesize bubbleSize, textSize;
@synthesize textX;
@synthesize selected, isChat;

#pragma mark Class Methods

+ (void)initialize {
	if(self == [SSMessageTableViewCellBubbleView class]) {
        if (screenScale == 0.0) {
            screenScale = [UIScreen mainScreen].scale;
            photoPlaceholder = [UIImage imageWithContentsOfResolutionIndependentFile:@"Add_Photo_Button_Image"];
        }
        
        VKPlaceholderImage = [UIImage imageWithContentsOfResolutionIndependentFile:kVKPlaceholderImage];
        timeColor = [UIColor colorWithRed:118.0/255.0 green:130.0/255.0 blue:150.0/255.0 alpha:1.0];
        textColor = [UIColor blackColor];
        textSelectedColor = [UIColor whiteColor];
        backgroundColor = [UIColor clearColor];
        textFont = [UIFont systemFontOfSize:15.0];
        timeFont = [UIFont systemFontOfSize:14.0];
        leftBubble = [[UIImage imageWithContentsOfResolutionIndependentFile:@"Grey_Bubble.png"] stretchableImageWithLeftCapWidth:22 topCapHeight:14];
        leftBubbleSelected = [[UIImage imageWithContentsOfResolutionIndependentFile:@"Grey_Bubble_Selected.png"] stretchableImageWithLeftCapWidth:22 topCapHeight:14];
        
        rightBubble = [[UIImage imageWithContentsOfResolutionIndependentFile:@"Blue_Bubble.png"] stretchableImageWithLeftCapWidth:18 topCapHeight:14];
        rightBubbleSelected = [[UIImage imageWithContentsOfResolutionIndependentFile:@"Blue_Bubble_Selected.png"] stretchableImageWithLeftCapWidth:18 topCapHeight:14];
        //	self.leftBackgroundImage = [[UIImage imageNamed:@"SSMessageTableViewCellBackgroundClear.png"] stretchableImageWithLeftCapWidth:24 topCapHeight:14];
        //	self.rightBackgroundImage = [[UIImage imageNamed:@"SSMessageTableViewCellBackgroundGreen.png"] stretchableImageWithLeftCapWidth:17 topCapHeight:14];
    }
}

+ (CGSize)onlyTextSizeForMessage:(VKMessage *)msg {
	CGSize maxSize = CGSizeMake(VK.bubbleMaxWidth - 35.0f, 3000.0f);
    static NSMutableParagraphStyle *paragraphStyle = nil;
    if (!paragraphStyle)
    {
        paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineBreakMode = kLineBreakMode;
    }
    NSDictionary *attrs = @{NSFontAttributeName:textFont,NSParagraphStyleAttributeName:paragraphStyle};
    CGSize sz = [msg.body boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil].size;
    return sz;
}

+ (CGSize)textSizeForMessage:(VKMessage *)msg {
    CGSize sz = [self onlyTextSizeForMessage:msg];
    CGSize sz2 = [VKAttachments attachSizeForMessage:msg maxWidth:VK.bubbleMaxWidth];
    sz.width = MAX(sz.width, sz2.width);
    sz.height = sz.height + sz2.height;
	return sz;
}

+ (CGSize)bubbleSizeForMessage:(VKMessage *)msg {
	CGSize textSize = [self textSizeForMessage:msg];
	return CGSizeMake(textSize.width + 35.0f, textSize.height + kPaddingTop + kPaddingBottom);
}

+ (CGFloat)cellHeightForMessage:(VKMessage *)msg {
	return [self bubbleSizeForMessage:msg].height + kMarginTop + kMarginBottom;
}

#pragma mark NSObject

- (void)setSelected:(BOOL)newSelected {
    if ( self->selected != newSelected ) {
        self->selected = newSelected;
        [self updateMessageBubble];
        [self setNeedsDisplay];
    }
}

- (void)dealloc {
}


#pragma mark UIView

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
//		self.backgroundColor = [UIColor colorWithRed:0.859f green:0.886f blue:0.929f alpha:1.0f];
        self.backgroundColor = backgroundColor;
        bubbleImage = leftBubble;
        message = nil;
        selected = NO;
        //        isChat = YES;
	}
	return self;
}

- (void)setMessage:(VKMessage *)newMessage {
    self->message = newMessage;
    timeText = lastDateStr(message.date);
    static NSMutableParagraphStyle *paragraphStyle = nil;
    if (!paragraphStyle) {
        paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineBreakMode = kLineBreakMode;
    }
    NSDictionary *attrs = @{NSFontAttributeName:textFont,NSParagraphStyleAttributeName:paragraphStyle};
    timeSize = [timeText sizeWithAttributes:attrs];

    CGSize onlyTextSize = [[self class] onlyTextSizeForMessage:message];
    
    textSize = [[self class] textSizeForMessage:message];
    bubbleSize = CGSizeMake(textSize.width + 35.0f, textSize.height + kPaddingTop + kPaddingBottom);
    CGPoint point;
    point.x = 10;
    point.y = onlyTextSize.height + 10.0;
    cellImages = [NSMutableArray array];
    
    if ( isArrayOk(newMessage.attachments) ) {
//        CGSize maxSize = CGSizeMake(kMaxWidth - 35.0f, 3000.0f);
        
        int height = 0, width = 0;
        for ( NSDictionary *a in newMessage.attachments )
            if ( isDictionaryOk(a) ) {
                NSString *photo = nil; NSDictionary *attachImage = nil;
                NSString *type = [a objectForKey:kVKAttachType];
                if ( [type caseInsensitiveCompare:kVKAttachDocument] == NSOrderedSame ) {
                    // TODO: Document attacment
                }
                else if ( [type caseInsensitiveCompare:kVKAttachAudio] == NSOrderedSame ) {
                    // TODO: Audio attacment
                }
                else if ( [type caseInsensitiveCompare:kVKAttachVideo] == NSOrderedSame ) {
                    // TODO: Video attacment
                }
                else if ( [type caseInsensitiveCompare:kVKAttachWall] == NSOrderedSame ) {
                    // TODO: Wall attacment
                }
                else if ( [type caseInsensitiveCompare:kVKAttachSticker] == NSOrderedSame ) {
                    // DONE: Sticker attacment
                    attachImage = [a objectForKey:kVKAttachSticker];
                    if ( isDictionaryOk(attachImage) ) {
                        self->message.bubbleInvisible = YES;
                        photo = [attachImage objectForKey:@"photo_256"];
                    }
                }
                else if ( [type caseInsensitiveCompare:kVKAttachPhoto] == NSOrderedSame ) {
                    attachImage = [VKAttachments photoForAttach:[a objectForKey:kVKAttachPhoto]];
                    if ( !isDictionaryOk(attachImage) )
                        attachImage = [a objectForKey:kVKAttachPhoto];
                    if ( isDictionaryOk(attachImage) ) {
                        photo = [attachImage objectForKey:kVKAttachSrc];
                    }
                }
                else {
//                    DLog(@"%@: %@",type,a);
//                    sz.height += 20;
                }
                
                if (isDictionaryOk(attachImage)) {
                    height = [[attachImage objectForKey:kVKAttachHeight] intValue];
                    width =  [[attachImage objectForKey:kVKAttachWidth]  intValue];
                    if (screenScale == 2.0) { width /= 2; height /= 2; }
                    CellImage *ci = [[CellImage alloc] init];
                    ci.frame = CGRectMake(point.x, point.y, width, height);
                    ci.index = cellImages.count;
                    [cellImages addObject:ci];
                    point.y += height + 10.0;
                    __weak CellImage *_ci = ci;
                    __weak typeof(self) this = self;
                    ci.imageView = [[UIImageView alloc] initWithImage:photoPlaceholder];
                    [ci.imageView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:photo]] placeholderImage:photoPlaceholder success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                        _ci.imageView.image = image;
/*
                        _ci.imageView.alpha = 0.0;
                        [UIImageView beginAnimations:@"FadeInOut" context:nil];
                        [UIImageView setAnimationDuration:0.25f];
                        [UIImageView setAnimationCurve:UIViewAnimationCurveEaseIn];
                        _ci.imageView.alpha = 1.0;
                        [UIImageView commitAnimations];
*/
                        [this setNeedsDisplay];
                    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                    }];
                }
        }
        
    }
    
    [self updateMessageBubble];
    [self setNeedsLayout];
}

- (CellImage *)cellImageAtLocation:(CGPoint)location {
    // DONE: Get CellImage at given location
    for (CellImage *i in cellImages) {
        CGRect imageRect = CGRectMake(_imageDrawOffset.x + i.frame.origin.x, i.frame.origin.y, i.frame.size.width, i.frame.size.height);
        if (CGRectContainsPoint(imageRect, location)) {
            return i;
        }
    }
    return nil;
}

- (BOOL)hasMessageAtLocation:(CGPoint)location {
    BOOL inside = NO;
    if (message.messageRightAlign) {
        if ( location.x > (self.frame.size.width - bubbleSize.width) )
            inside = YES;
    }
    else {
        if ( location.x < (bubbleSize.width) )
            inside = YES;
    }
    return inside;
}

- (void)updateMessageBubble {
    if (message.bubbleInvisible)
        bubbleImage = nil;
    else if ( selected )
        bubbleImage = (message && message.messageRightAlign) ? rightBubbleSelected : leftBubbleSelected;
    else
        bubbleImage = (message && message.messageRightAlign) ? rightBubble : leftBubble;
}

- (void)drawRect:(CGRect)frame {
//	bubbleFrame = CGRectMake((message.messageRightAlign ? self.frame.size.width - bubbleSize.width : 0.0f), kMarginTop, bubbleSize.width, bubbleSize.height);
//	textSize = [[self class] textSizeForText:message.body];
//	textX = (CGFloat)bubbleImage.leftCapWidth - 3.0f + (message.messageRightAlign ? bubbleFrame.origin.x : 0.0f);
//	textFrame = CGRectMake(textX, kPaddingTop + kMarginTop, textSize.width, textSize.height);

	[bubbleImage drawInRect:bubbleFrame];
    
    if ( selected )
        [textSelectedColor set];
    else
        [textColor set];
    
    static NSMutableParagraphStyle *textStyle = nil;
    if (!textStyle) {
        textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
        textStyle.lineBreakMode = NSLineBreakByWordWrapping;
    }

    textStyle.alignment = message.messageRightAlign ? NSTextAlignmentRight : NSTextAlignmentLeft;

    [message.body drawInRect:textFrame withAttributes:@{NSFontAttributeName:textFont, NSParagraphStyleAttributeName:textStyle}];
    
    [timeColor set];
    [timeText drawAtPoint:_timeDrawOffset withAttributes:@{NSFontAttributeName:timeFont,NSForegroundColorAttributeName:[UIColor lightGrayColor]}];
    
    for ( CellImage *ci in cellImages ) {
        CGPoint xy = CGPointMake(_imageDrawOffset.x + ci.frame.origin.x, ci.frame.origin.y);
        [ci.imageView.image drawAtPoint:xy];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
	bubbleFrame = CGRectMake((message.messageRightAlign ? self.frame.size.width - bubbleSize.width : 0.0f), kMarginTop, bubbleSize.width, bubbleSize.height);
	textX = (CGFloat)bubbleImage.leftCapWidth - 3.0f + (message.messageRightAlign ? bubbleFrame.origin.x : 0.0f);
	textFrame = CGRectMake(textX, kPaddingTop + kMarginTop, textSize.width, textSize.height + 10.0);
    if ( isChat ) {
        if ( message.messageRightAlign ) {
            textX -= chatOfs;
            bubbleFrame.origin.x -= chatOfs; 
            textFrame.origin.x -= chatOfs; 
        }
        else {
            textX += 35.0;
            textFrame.origin.x += chatOfs; 
            bubbleFrame.origin.x += chatOfs; 
        }
    }
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[self findSuperViewWithClass:[UITableViewCell class]];
    CGFloat cw = cell.contentView.frame.size.width;

    // fix 2014/05/07
    if ( message.messageRightAlign ) {
        _timeDrawOffset.x = cw - 5 - bubbleSize.width - timeSize.width;
        if ( isChat ) _timeDrawOffset.x -= chatOfs;
    }
    else {
        _timeDrawOffset.x = bubbleSize.width + 5;
        if ( isChat ) _timeDrawOffset.x += chatOfs;
    }
    _timeDrawOffset.y = self.frame.size.height - 24;

    if ( message.messageRightAlign ) {
        if ( isChat ) _imageDrawOffset.x -= chatOfs;
        _imageDrawOffset.x = cw - bubbleSize.width + 12;
    }
    else {
        _imageDrawOffset.x = 15;
        if ( isChat ) _imageDrawOffset.x += chatOfs;
    }
    [self setNeedsDisplay];
}

@end
