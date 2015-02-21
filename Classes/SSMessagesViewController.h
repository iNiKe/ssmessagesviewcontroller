//
//  SSMessagesViewController.h
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//
//	This is an abstract class for displaying a UI similar to Apple's SMS application. A subclass should override the
//  messageStyleForRowAtIndexPath: and textForRowAtIndexPath: to customize this class.
//

#import "SSMessageTableViewCell.h"
#import "HPGrowingTextView.h"
#import "AttachmentsView.h"
#import "EGORefreshTableFooterView.h"
#import "ContactsViewController.h"
#import "VKImageUploader.h"
#import "MapViewController.h"
#import "UIViewController+PADTiltAdditions.h"
#import "PADTiltViewController.h"

#define kAttachmentsUploaded    @"AttachmentsUploaded"

#define kAttachTypeImage    1
#define kAttachTypeGeo      2
#define kAttachTypeAudio    3
#define kAttachTypeVideo    4
#define kAttachTypeDoc      5

@interface Attachment : NSObject
{
    UIImageView *imageView;
    UIButton *deleteButton;
    NSString *url, *uploadServer;
    CLLocationCoordinate2D coordinate;
    int attachType;
}
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) NSString *url, *uploadServer;
@property (nonatomic, assign) int attachType;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end

@class SSTextField;

@interface SSMessagesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, HPGrowingTextViewDelegate, ContactsDelegate,UIActionSheetDelegate, UIImagePickerControllerDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate, SelectLocationControllerDelegate>
{
@private
	
	UITableView *_tableView;
	UIImageView *_inputBackgroundView;
	UIButton *_sendButton;
    
    HPGrowingTextView *textView;
	UIView *containerView;
    AttachmentsView *attachmentsView;
    BOOL attachmetsShown, keyboardShown, _reloading, addingParticipant, coordsSelected;
    NSNotification *keyboardNotification;
    CGFloat attachmetsHeight, tabHeight;
    UILabel *placeHolderLabel;
    UIButton *clearButton;
    NSMutableArray *attachments, *users;
    NSMutableString *attachmentsString;
    CLLocationCoordinate2D coordinates;
    VKContact *contact;
    VKDialog *dialog;
    NSDate *lastActivity;
    BOOL receivingTiltUpdates;
    __unsafe_unretained id pad_scrollView;
}

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) UIImageView *inputBackgroundView;
@property (nonatomic, strong) HPGrowingTextView *textView;
@property (nonatomic, strong, readonly) UIButton *sendButton;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;
@property (nonatomic, strong) AttachmentsView *attachmentsView;
@property (nonatomic, strong) EGORefreshTableFooterView *refreshFooterView;
@property (nonatomic, assign) BOOL _reloading, coordsSelected;
@property (strong, nonatomic) UIPopoverController *popoverController;
@property (strong, nonatomic) MKNetworkOperation *uploadOperation;
@property (strong, nonatomic) VKImageUploader *imageUploader;
@property (strong, nonatomic) NSMutableArray *attachments, *users;
@property (nonatomic, strong) Attachment *currentAttach;
@property (nonatomic, strong) NSData *imageData;
@property (nonatomic, assign) int currentIndex, chatId, uid;
@property (nonatomic, strong) NSMutableString *attachmentsString;
@property (strong, nonatomic) VKContact *contact;
@property (strong, nonatomic) VKDialog *dialog;
@property (strong, nonatomic) NSMutableArray *messages;
@property (strong, nonatomic) NSDate *lastActivity;

- (VKMessage *)messageForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)resignTextView;
- (IBAction)sendText:(id)sender;
- (void)reloadTable;
- (void)reloadTableWithScroll:(BOOL)scroll;
- (void)doneLoadingTableViewData;
- (void)doneLoadingTableViewDataAnimated:(BOOL)animated;
- (void)scrollToBottom;
- (void)repositionRefreshHeaderView;
- (void)updateCanSend;
- (void)uploadAttachments:(int)index;
- (void)deleteAllAttachments;
- (void)setupRefreshView;
- (void)relocateFooterPullToRefreshView;
- (void)scrollToBottomAnimated:(BOOL)animated;
- (id)pad_scrollView;

@end
