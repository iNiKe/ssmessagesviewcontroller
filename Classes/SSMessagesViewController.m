//
//  SSMessagesViewController.m
//  Messages
//
//  Created by Sam Soffes on 3/10/10.
//  Copyright 2010-2011 Sam Soffes. All rights reserved.
//

#import "SSMessagesViewController.h"
#import "SSMessageTableViewCell.h"
#import "SSMessageTableViewCellBubbleView.h"
#import "SAMTextField.h"
#import "AppDelegate.h"
#import "MapViewController.h"
#import "MessagesViewController.h"
//#import "UITableView+Gestures.h"
#import "NKUtils.h"
#import "UIKeyboardListener.h"
#import "PhotosViewController.h"
#import "AppDelegate.h"
#import "MsgViewController.h"

#import "VKAttachments.h"
#import "ProfileVQViewController.h"

#define kInputHeight            40.0f
#define kDurationUp             0.35f
#define kDurationDown           0.25f
#define kContainerViewHeight    40.0f

@interface HPGrowingTextView (NKUtils)

- (void)appendString:(NSString *)string;

@end

@implementation HPGrowingTextView (NKUtils)

- (void)appendString:(NSString *)string {
    if ( isStringOk(string) ) {
        if ( isStringOk(self.text) )
            self.text = [NSString stringWithFormat:@"%@ %@", self.internalTextView.text,string];
        else
            self.text = string;
    }
}

@end

@implementation Attachment

@synthesize imageView, url, uploadServer, deleteButton, attachType, coordinate;

@end

@implementation SSMessagesViewController

@synthesize tableView = _tableView;
@synthesize inputBackgroundView = _inputBackgroundView;
@synthesize sendButton = _sendButton;
@synthesize textView;
@synthesize selectedIndexPath;
@synthesize attachmentsView;
@synthesize refreshFooterView;
@synthesize _reloading, coordsSelected;
@synthesize popoverController;
@synthesize uploadOperation, imageUploader, attachments;
@synthesize currentAttach;
@synthesize imageData;
@synthesize currentIndex, chatId, uid;
@synthesize attachmentsString;
@synthesize contact;
@synthesize dialog;
@synthesize users;
@synthesize messages;
@synthesize lastActivity;

#pragma mark - UIViewController

- (id)init {
    self = [super init];
    if (self) {
        [self pad_init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	CGSize size = self.view.frame.size;
    CGFloat width = size.width;
    
	// Table view
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height - kInputHeight) style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundView = nil;
	_tableView.backgroundColor = [UIColor clearColor];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.separatorColor = [UIColor clearColor];
    
	[self.view addSubview:_tableView];
    
    CGFloat newWidth = self.view.bounds.size.width - 57.0;
    VK.bubbleMaxWidth = newWidth;

    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]) { // iOS 7
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    [self updateTableViewInsetsWithBottomInset:0];
    
    if ( self.tabBarController.tabBar && !self.hidesBottomBarWhenPushed )
        tabHeight = self.tabBarController.tabBar.frame.size.height;
    else
        tabHeight = 0;
    self.view.backgroundColor = lightBackgroundPatternColor();
    
//	speechToText = [[SpeechToTextModule alloc] init]; speechToText.delegate = self;
    
    containerView = [[UIView alloc] initWithFrame:CGRectMake(0, size.height - kContainerViewHeight, width, kContainerViewHeight)];
    containerView.backgroundColor = [UIColor clearColor];
    UIView *backTextView = [[UIView alloc] initWithFrame:CGRectMake(6.0 + 26.0 + 8.0, 0, width - 80.0 - 26.0 - 8.0, kContainerViewHeight)];
    backTextView.backgroundColor = [UIColor whiteColor];
    backTextView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	textView = [[HPGrowingTextView alloc] initWithFrame:CGRectMake(6.0 + 45.0, 3.0, width - 80.0 - 48.0 - 11.0, kInputHeight-3.0*2)];
    textView.contentInset = UIEdgeInsetsMake(0, 5.0, 0, 5.0);
    
	textView.minNumberOfLines = 1;
	textView.maxNumberOfLines = 6;
	textView.returnKeyType = UIReturnKeyNext;
	textView.font = [UIFont systemFontOfSize:15.0f];
	textView.delegate = self;
    textView.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(5.0, 0, 5.0, 0);
    textView.backgroundColor = [UIColor clearColor];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    placeHolderLabel = [[UILabel alloc] initWithFrame:CGRectMake(24.0, 9.0, textView.frame.size.width - 10, 22.0)];
    [backTextView addSubview:placeHolderLabel];
    placeHolderLabel.font = textView.font;
    placeHolderLabel.text = NSLocalizedString(@"Enter message", @"Введите сообщение");
    placeHolderLabel.textColor = [UIColor lightGrayColor];
    placeHolderLabel.backgroundColor = [UIColor clearColor];

    if ( VK.useAutocorrection )
        self.textView.internalTextView.autocorrectionType = UITextAutocorrectionTypeDefault;
    else
        self.textView.internalTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    
    [self.view addSubview:containerView];
	
    UIImage *rawEntryBackground = [UIImage imageNamed:@"MessageEntryInputField.png"];
    UIImage *entryBackground = [rawEntryBackground stretchableImageWithLeftCapWidth:13.0 topCapHeight:22.0];
    UIImageView *entryImageView = [[UIImageView alloc] initWithImage:entryBackground];
    entryImageView.frame = CGRectMake(5.0 + 28.0 + 6.0, 0, width - 72.0 - 28.0 - 6.0, kContainerViewHeight);
    entryImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    UIImage *rawBackground = [UIImage imageNamed:@"MessageEntryBackground.png"];
    UIImage *background = [rawBackground stretchableImageWithLeftCapWidth:13.0 topCapHeight:22.0];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:background];
    imageView.frame = CGRectMake(0, 0, width, containerView.frame.size.height);
    imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
    // view hierachy
    [containerView addSubview:imageView];
    [containerView addSubview:backTextView];
    [containerView addSubview:textView];
    [containerView addSubview:entryImageView];
    
//    UIImage *sendBtnBackground = [[UIImage imageWithContentsOfResolutionIndependentFile:@"MessageEntrySendButton.png"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
//    UIImage *selectedSendBtnBackground = [[UIImage imageWithContentsOfResolutionIndependentFile:@"MessageEntrySendButtonPressed.png"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];

/*
    // fix 2014/06/02
	UIButton *micButton = [UIButton buttonWithType:UIButtonTypeCustom];
	micButton.frame = CGRectMake(6 + 42, 13, 12, 18);
    micButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
	[micButton addTarget:self action:@selector(onMicButton:) forControlEvents:UIControlEventTouchUpInside];
    [micButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"mic.png"] forState:UIControlStateNormal];
//    [micButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"mic_pressed.png"] forState:UIControlStateHighlighted];
    //    [attachButton setEnabled:NO];
	[containerView addSubview:micButton];
*/
    
	clearButton = [UIButton buttonWithType:UIButtonTypeCustom];
	clearButton.frame = CGRectMake(width - 98, 12, 19, 19);
    clearButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[clearButton addTarget:self action:@selector(onClearButton:) forControlEvents:UIControlEventTouchUpInside];
    [clearButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"UITextFieldClearButton.png"] forState:UIControlStateNormal];
    [clearButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"UITextFieldClearButtonPressed.png"] forState:UIControlStateHighlighted];
	[containerView addSubview:clearButton];

	UIButton *attachButton = [UIButton buttonWithType:UIButtonTypeCustom];
	attachButton.frame = CGRectMake(6, 8, 28, 29);
    attachButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
	[attachButton addTarget:self action:@selector(onAttachButton:) forControlEvents:UIControlEventTouchUpInside];
    [attachButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"AttachButton.png"] forState:UIControlStateNormal];
    [attachButton setBackgroundImage:[UIImage imageWithContentsOfResolutionIndependentFile:@"AttachButton_Pressed.png"] forState:UIControlStateHighlighted];
//    [attachButton setEnabled:NO];
	[containerView addSubview:attachButton];

    UIImage *sendBtnBackground = [[UIImage imageWithContentsOfResolutionIndependentFile:@"SendButton.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:0];
    UIImage *selectedSendBtnBackground = [[UIImage imageWithContentsOfResolutionIndependentFile:@"SendButton_pressed.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:0];
    
	_sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
//	_sendButton.frame = CGRectMake(containerView.frame.size.width - 69, 8, 63, 27);
	_sendButton.frame = CGRectMake(containerView.frame.size.width - 65, 8, 59, 27);
    _sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[_sendButton setTitle:NSLocalizedString(@"Send", @"Отпр.") forState:UIControlStateNormal];
    [_sendButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
    _sendButton.titleLabel.shadowOffset = CGSizeMake (0.0, -1.0);
    _sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_sendButton addTarget:self action:@selector(sendText:) forControlEvents:UIControlEventTouchUpInside];
    [_sendButton setBackgroundImage:sendBtnBackground forState:UIControlStateNormal];
    [_sendButton setBackgroundImage:selectedSendBtnBackground forState:UIControlStateHighlighted];
    [_sendButton setEnabled:NO];
	[containerView addSubview:_sendButton];
    containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.cancelsTouchesInView = NO;  // Must pass through the tap to the UITableView, otherwise we can't touch the rows
    [_tableView addGestureRecognizer:tapGesture];
    
    [self updateAttachmetsHeight];
    [self createAttachmentsView];

    if (refreshFooterView == nil) {
        [self setupRefreshView];
    }
    _tableView.allowsSelection = NO;
    [self reloadTable];
    makeVKNavigationBarBackgroundImage(self);

    self.pad_motionManager = [(AppDelegate *)[[UIApplication sharedApplication] delegate] motionManager];
    pad_scrollView = _tableView;
    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(pad_state)) options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (selectedIndexPath) {
        UITableViewCell *cell = [_tableView cellForRowAtIndexPath:selectedIndexPath];
        [cell setSelected:NO animated:YES];
        selectedIndexPath = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self removeAttachmentsView];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self pad_stopReceivingTiltUpdates];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [self removeAttachmentsView];
    [self pad_dealloc];
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(pad_state)) context:NULL];
    }
    @catch (NSException *exception) {}
}

- (void)handleTapGesture:(UITapGestureRecognizer *)tapGesture {
    [self stopReceivingTiltUpdates];
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)tapGesture.view;
    if (selectedIndexPath) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
        [cell setSelected:NO animated:YES];
        selectedIndexPath = nil;
    }
    if ([UIKeyboardListener isVisible]) {
        [self resignTextView];
        return;
    }
    // DONE: Catch only bubble tap, else resign
    DLog(@".");
    if (![cell isKindOfClass:[SSMessageTableViewCell class]])
        return;
    
    CGPoint location = [tapGesture locationInView:cell];
    if (![cell.bubbleView hasMessageAtLocation:location]) {
        return;
    }
    else {
        selectedIndexPath = [_tableView indexPathForCell:cell];
        @try {
            [cell setSelected:YES animated:YES];
        }
        @catch (NSException *exception) {
        }
        @finally {
        }
        
        // DONE: If tap on avatar - open profile
        for (UIView *v in cell.subviews) {
            if ([v isKindOfClass:[UIImageView class]] && (CGRectContainsPoint(v.frame, location))) {
                int userId = (int)v.tag;
                if (userId > 0) {
                    [ProfileVQViewController pushVQProfileControllerTo:self.navigationController userId:userId];
                    return;
                }
            }
        }
        
        int currentPhoto = -1;
        NSArray *photos = [cell.message allPhotos];
        if (isArrayOk(photos)) {
            // DONE: Detect tapped photo and start viewing from it
            location = [tapGesture locationInView:cell.bubbleView];
            CellImage *image = [cell.bubbleView cellImageAtLocation:location];
            if (image)
                currentPhoto = (int)image.index;
            else
                currentPhoto = -1;
        }
        if (currentPhoto >= 0)
            [PhotosViewController pushControllerWithPhotos:photos toController:self.navigationController startOnGrid:NO currentPhoto:currentPhoto fromView:cell.bubbleView];
        else {
            // DONE: Open message view controller
            id controller = [MsgViewController msgViewControllerWithVKMessage:cell.message];
            if (controller)
                [self.navigationController pushViewController:controller animated:YES];
        }
    }
}

- (void)resignTextView {
    keyboardShown = NO;
    [self hideAttachmentsView];
    [textView resignFirstResponder];
}

- (void)reloadTableViewDataSource {
	//  should be calling your tableviews model to reload
	//  put here just for demo
	[self performSelector:@selector(doneLoadingTableViewData) withObject:nil afterDelay:1.0];
}

- (void)doneLoadingTableViewDataAnimated:(BOOL)animated
{
    //  model should call this when its done loading
    
    _reloading = NO;
    
    if (animated)
    {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:.3];
        //	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
        [self updateTableViewInsetsWithBottomInset:0.0];
        [UIView commitAnimations];
    }
    
    /*
     if ([_refreshHeaderView state] != EGOOPullRefreshNormal) {
     [_refreshHeaderView setState:EGOOPullRefreshNormal];
     [_refreshHeaderView setCurrentDate];  //  should check if data reload was successful
     }
     */
    if ([refreshFooterView state] != EGOOPullRefreshNormal) {
        [refreshFooterView setState:EGOOPullRefreshNormal];
        [refreshFooterView setCurrentDate];  //  should check if data reload was successful
    }
    [refreshFooterView setCurrentDate];
    [self repositionRefreshHeaderView];
}

- (void)doneLoadingTableViewData {
    [self doneLoadingTableViewDataAnimated:YES];
}

- (float)tableViewHeight {
	
    // return height of table view
    float height = [self.tableView contentSize].height;
    CGFloat tableHeight = _tableView.bounds.size.height;
    if ( height < tableHeight )
        height = tableHeight;
    return height;
}

- (float)endOfTableView:(UIScrollView *)scrollView {
    return [self tableViewHeight] - scrollView.bounds.size.height - scrollView.bounds.origin.y;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)showLoadingView {
    DLog(@".");
}

- (void)stopRecord {
    DLog(@".");
    //    [speechToText stopRecording:YES];
}

- (void)hideAttachmentsView {
    if ( attachmetsShown ) {
        attachmetsShown = NO;
        [self toggleAttachmentsView];
    }
}

- (void)toggleAttachmentsView {
    if ( attachmetsShown )
    {
        CGFloat decY = attachmetsHeight - tabHeight;
        [self resizeViewsForHeight:decY duration:kDurationUp];
        if ( keyboardShown )
            [self resignTextView];
    }
    else
    {
        if ( keyboardShown )
            [textView becomeFirstResponder];
        else
            [self resizeViewsForHeight:0 duration:kDurationDown];
    }
    attachmetsShown = !attachmetsShown;
}

- (void)updateTableViewInsetsWithBottomInset:(CGFloat)bottomInset {
    UIEdgeInsets insets = _tableView.contentInset;
    if (self.navigationController.navigationBar.translucent && (sysVersionFloat() >= 7.0) )
    {
        CGRect rect = self.navigationController.navigationBar.frame;
        CGFloat y = +rect.origin.y + rect.size.height;
//        CGFloat y = 200;

        insets.top = y;
    }
    insets.bottom = bottomInset;
    _tableView.contentInset = insets;
    _tableView.scrollIndicatorInsets = insets;
}

#pragma mark - UIViewController Rotation Events

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //    [self.tableView beginUpdates];
    CGFloat newWidth = self.view.bounds.size.width - 57.0;
    VK.bubbleMaxWidth = newWidth;
    [self.tableView reloadData];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self pad_stopReceivingTiltUpdates];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    //    [self.tableView endUpdates];
    //    [self reloadVisibleRows];
    [self.textView refreshHeight];  // fix 2014/05/23
    [self createAttachmentsView];
    [self updateAttachmetsHeight];
    //    [self reloadTable];
}

#pragma mark - Refresh Header

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view {
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view {
    return YES;
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view {
    return nil;
}

- (void)setupRefreshView {
    EGORefreshTableFooterView *view = [[EGORefreshTableFooterView alloc] initWithFrame:CGRectMake(0.0f, [self tableViewHeight], self.view.frame.size.width, 600.0f)];
    //		view.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
    view.backgroundColor = [UIColor clearColor];
    [self.tableView addSubview:view];
    _tableView.showsVerticalScrollIndicator = YES;
    refreshFooterView = view;
}

- (void)repositionRefreshHeaderView {
    CGFloat x = self.view.bounds.size.width / 2.0;
    CGFloat y = [self tableViewHeight] + 300.0f;
    refreshFooterView.center = CGPointMake(x, y);
    [self relocateFooterPullToRefreshView];
}

- (void)relocateFooterPullToRefreshView {
    
    CGFloat yOrigin = 0.0f;
    
    if ([self.tableView contentSize].height >= CGRectGetHeight([self.tableView frame])) {
        
        yOrigin = [self.tableView contentSize].height;
        
    } else {
        
        yOrigin = CGRectGetHeight([self.tableView frame]);
    }
    
    CGRect frame = [refreshFooterView frame];
    frame.origin.y = yOrigin;
    [refreshFooterView setFrame:frame];
    
    [self.tableView addSubview:refreshFooterView];
//    [self.tableView setContentInset:UIEdgeInsetsZero];
    [self updateTableViewInsetsWithBottomInset:0];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView.isDragging) {
        CGFloat endOfTable = [self endOfTableView:scrollView];
        if (self.refreshFooterView.state == EGOOPullRefreshPulling && endOfTable < 0.0f && endOfTable > -65.0f && !_reloading) {
            [refreshFooterView setState:EGOOPullRefreshNormal];
        } else if (refreshFooterView.state == EGOOPullRefreshNormal && endOfTable < -65.0f && !_reloading) {
            [refreshFooterView setState:EGOOPullRefreshPulling];
        }
        else
            [refreshFooterView refreshLastUpdatedDate];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    DLog(@".");
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    DLog(@".");
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if ([self endOfTableView:scrollView] <= -65.0f && !_reloading) {
        _reloading = YES;
        [self resignTextView];
        [self reloadTableViewDataSource];
        [self.refreshFooterView setState:EGOOPullRefreshLoading];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        [self updateTableViewInsetsWithBottomInset:60.0];
        //        _tableView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, 60.0f, 0.0f);
        [UIView commitAnimations];
    }
}

#pragma mark - UI

- (void)updateCanSend {
    [_sendButton setEnabled:isStringOk(self.textView.text) || isArrayOk(attachments) ];
}

- (void)scrollToBottom {
    [self scrollToBottomAnimated:YES];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    [self stopReceivingTiltUpdates];
    if ( isArrayOk(self.messages) )
    {
        @try {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.messages.count-1 inSection:0];
            if ( indexPath )
            {
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
                [self repositionRefreshHeaderView];
            }
        }
        @catch (NSException *exception) {
            DLog(@"NSException: %@ reason = %@", exception.name, exception.reason);
        }
    }
}

- (void)reloadTable {
    [self reloadTableWithScroll:YES];
}

- (void)reloadTableWithScroll:(BOOL)scroll {
    [self.tableView reloadData];
    if ( scroll )
        [self scrollToBottom];
}

- (void)resizeViewsForHeight:(CGFloat)height duration:(CGFloat)duration {
    CGRect frame = containerView.frame;
    CGFloat decY = height + frame.size.height;
    frame.origin.y = self.view.bounds.size.height - decY;
    
    CGRect tableFrame = _tableView.frame;
    tableFrame.size.height = frame.origin.y;
    
    // animations settings
    CGPoint contentOffset = _tableView.contentOffset;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    UIView *sv = [attachmentsView superview];
    
    CGRect wframe = sv.frame;
    CGRect aframe = attachmentsView.frame;
    if ( attachmetsShown )
    {
        aframe.origin.y = wframe.size.height - aframe.size.height;
        contentOffset.y += aframe.size.height;
    }
    else
    {
        aframe.origin.y = wframe.size.height;
        contentOffset.y -= aframe.size.height;
    }
    attachmentsView.frame = aframe;
    // set views with new info
    containerView.frame = frame;
    _tableView.frame = tableFrame;
    _tableView.contentOffset = contentOffset; // fix 2015/02/18 table content moves with attach view
    [self repositionRefreshHeaderView];
    // commit animations
    [UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    keyboardNotification = notification;
    CGRect keyboardBounds;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    NSNumber *duration = [notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    //    NSNumber *curve = [notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    keyboardBounds = [self.view convertRect:keyboardBounds toView:nil];
    //    RectLog(@"key", keyboardBounds);
    
    CGFloat decY = keyboardBounds.size.height - tabHeight;
    keyboardShown = YES;
    if ( !attachmetsShown )
        [self resizeViewsForHeight:decY duration:[duration doubleValue]];
    else
        [self hideAttachmentsView];
    [self scrollToBottom];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSNumber *duration = [notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    //    NSNumber *curve = [notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    if ( !attachmetsShown )
    {
        keyboardShown = NO;
        [self resizeViewsForHeight:0 duration:[duration doubleValue]];
    }
}

- (void)reloadVisibleRows {
    NSArray *visibleRows = [self.tableView indexPathsForVisibleRows];
    if (visibleRows.count > 0)
    {
        [self.tableView reloadRowsAtIndexPaths:visibleRows withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)removeAttachmentsView {
    if ( attachmentsView )
    {
        [attachmentsView removeFromSuperview];
        attachmentsView = nil;
    }
}

- (void)createAttachmentsView {
    if ( attachmentsView )
        return;
    [self removeAttachmentsView];
    attachmentsView = [[AttachmentsView alloc] initWithFrame:CGRectMake(0, 3000, self.view.bounds.size.width, attachmetsHeight) delegate:self];
    [self.view addSubview:attachmentsView];
}

- (void)updateLastActivity {
// Subclassed
}

- (void)contactChosen:(VKContact *)c {
    [self performSelector:@selector(selectContact:) withObject:c afterDelay:.5];
}

- (void)selectContact:(VKContact *)c {
//    [self.navigationController dismissModalViewControllerAnimated:YES];
//    [self.navigationController popViewControllerAnimated:YES];
    if ( !c ) 
        return;
    if ( addingParticipant )
    {
        // TODO: Title for chat
        if ( self.uid != c.userId )
        {
            [self resignTextView];
            if ( chatId > 0 )
            {
                NSMutableDictionary *params = [NSMutableDictionary dictionary];
                [params setObject:NI(self.chatId) forKey:@"chat_id"];
                [params setObject:NI(c.userId) forKey:kVKJUserId];
                [VK runVKApiMethod:kVKMMessagesAddChatUser params:params doneBlock:^(VKApiResponse *apiResponse) {
                    DLog(@"%@", apiResponse.response);
                    //    NSNumber *response = [api.response objectForKey:kVKJResponse];
                    //    if ( isNumberOk(response) && ( [response intValue] == 1 ) )
                    [self updateProfileButtonWithImage:nil];
                }];
            }
            else
            {
                NSString *uids = [NSString stringWithFormat:@"%i,%i",self.uid,c.userId];
                NSString *title = nil;
                if ( self.contact )
                    title = [NSString stringWithFormat:@"%@, %@", [self.contact firstName], [c firstName]];
                NSMutableDictionary *params = [NSMutableDictionary dictionary];
                if ( title )
                    [params setObject:title forKey:@"title"];
                [params setObject:uids forKey:@"user_ids"];
                [VK runVKApiMethod:kVKMMessagesCreateChat params:params doneBlock:^(VKApiResponse *apiResponse) {
                    DLog(@"%@", apiResponse.response);
                    if ( !apiResponse.error )
                    {
                        NSNumber *response = [apiResponse.response objectForKey:kVKJResponse];
                        if ( isNumberOk(response) )
                        {
                            // TODO: Ковертация в беседу
                            VKMessage *d = [[VKMessage alloc] init];
                            d.chat_id = [response intValue];
                            d.users_count = 3;
                            self.chatId = d.chat_id;
                            self.dialog = d;
                            
                            self.messages = [NSMutableArray array];
                            //            self.title =
                            [self updateLastActivity];
                            [self updateProfileButtonWithImage:nil];
                            [self reloadTable];
                            //            [MessagesViewController chatWithDialog:d controller:self.navigationController];
                        }
                    }
                }];
            }
        }
    }
    else
    {
        NSString *domain = nil;//c.domain;
//        if ( !isStringOk(domain) )
            domain = [NSString stringWithFormat:@"id%i", c.userId];
        NSString *str = [NSString stringWithFormat: NSLocalizedString(@"I suggest you a user: %@ http://vk.com/%@\n", @"Рекомендую пользователя: %@ http://vk.com/%@\n"), [c fullName], domain];
        [self.textView appendString:str];
    }
}

- (void)updateProfileButtonWithImage:(UIImage *)image {
    // Subclassed
}

#pragma mark - HPGrowingTextViewDelegate

- (void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView {
    [placeHolderLabel setHidden:isStringOk(textView.text)];
    [clearButton setHidden:!isStringOk(textView.text)];
    [self updateActivity];
    [self updateCanSend];
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height {
    float diff = (growingTextView.frame.size.height - height);
    
    CGRect r = containerView.frame;
    r.size.height -= diff;
    r.origin.y += diff;
    containerView.frame = r;
    
    CGRect tableFrame = _tableView.frame;
    tableFrame.size.height = r.origin.y;
    _tableView.frame = tableFrame;
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView didChangeHeight:(float)height {
    // fix 2014/05/22
    [self createAttachmentsView];
    [self updateAttachmetsHeight];
    [self reloadTable];
    [self repositionRefreshHeaderView];
    [self scrollToBottom];
}

#pragma mark - Attachments

- (void)deleteAllAttachments {
    [UIView beginAnimations:@"" context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    
    
    CGSize size = attachmentsView.scrollView.contentSize;
    CGPoint center = attachmentsView.buttonsView.center;
    for (Attachment *attach in attachments)
    {
        attach.imageView.image = nil;
        [attach.imageView removeFromSuperview];
        [attach.deleteButton removeFromSuperview];
        size.width -= kAIncX;
        center.x -= kAIncX;
    }
    attachmentsView.scrollView.contentSize = size;
    center.x -= 17.0;
    attachmentsView.buttonsView.center = center;
    attachmentsString = nil;
    [attachments removeAllObjects];
    [UIView commitAnimations];
    
    [self updateCanSend];
}

- (void)deleteAttachAtIndex:(int)idx {
    if ( idx >= attachments.count )
        return;
    Attachment *a = [attachments objectAtIndex:idx];
    if ( a )
    {
        a.imageView.image = nil;
        [UIView beginAnimations:@"" context:NULL];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationDuration:0.35];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        
        [a.imageView removeFromSuperview];
        [a.deleteButton removeFromSuperview];
        
        for ( int i = idx + 1; i < attachments.count; i++ )
        {
            Attachment *attach = [attachments objectAtIndex:i];
            CGPoint center = attach.imageView.center;
            center.x -= kAIncX;
            attach.imageView.center = center;
            center = attach.deleteButton.center;
            center.x -= kAIncX;
            attach.deleteButton.center = center;
            attach.deleteButton.tag--;
        }
        [attachments removeObjectAtIndex:idx];
        a = nil;
        CGSize size = attachmentsView.scrollView.contentSize;
        size.width -= kAIncX;
        attachmentsView.scrollView.contentSize = size;
        CGPoint center = attachmentsView.buttonsView.center;
        center.x -= kAIncX;
        if ( attachments.count < 1 )
            center.x -= 17.0;
        attachmentsView.buttonsView.center = center;
        [UIView commitAnimations];
    }
    [self updateCanSend];
}

- (void)mapViewController:(MapViewController *)controller didChoosenLocation:(CLLocationCoordinate2D)coordinate image:(UIImage *)image {
    [self insertImage:image attachType:kAttachTypeGeo].coordinate = coordinate;
    coordinates = coordinate;
    coordsSelected = YES;
}

- (Attachment *)insertImage:(UIImage *)image attachType:(int)attachType {
    if ( !attachments )
        attachments = [NSMutableArray array];
    [self updateActivity];
    if ( attachType == kAttachTypeGeo )
        for ( int i = 0; i < attachments.count; i++ )
        {
            Attachment *a = [attachments objectAtIndex:i];
            if ( a.attachType == kAttachTypeGeo )
                [self deleteAttachAtIndex:i];
        }
    
    CGFloat x = 17.0 + attachments.count * kAIncX;
    CGFloat y = 15.0;
    Attachment *attach = [[Attachment alloc] init];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectZero;
    imageView.layer.cornerRadius = 15.0;
    imageView.layer.masksToBounds = YES;
    imageView.layer.borderColor = [UIColor whiteColor].CGColor;
    imageView.layer.borderWidth = 2.0;
    static UIImage *deleteImage = nil;
    if ( !deleteImage )
        deleteImage = [UIImage imageWithContentsOfResolutionIndependentFile:@"Delete_attach.png"];
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(x + kAWidth - 25.0/2.0 - 4.0, y - 25.0/2 + 4.0, 25.0, 25.0)];
    [button setBackgroundImage:deleteImage forState:UIControlStateNormal];
    button.tag = attachments.count;
    [button addTarget:self action:@selector(deleteAttach:) forControlEvents:UIControlEventTouchUpInside];
    attach.deleteButton = button;
    attach.imageView = imageView;
    attach.attachType = attachType;
    [attachments addObject:attach];
    imageView.center = CGPointMake(x + kAIncX/2.0, y + kAHeight/2.0);
    [UIView beginAnimations:@"" context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    CGSize size = attachmentsView.scrollView.contentSize;
    size.width += kAIncX;
    attachmentsView.scrollView.contentSize = size;
    imageView.frame = CGRectMake(x, y, kAWidth, kAHeight);
    [self.attachmentsView.scrollView addSubview:imageView];
    [self.attachmentsView.scrollView addSubview:button];
    x += kAIncX;
    attachmentsView.buttonsView.center = CGPointMake(attachmentsView.buttonsView.bounds.size.width/2 + x, attachmentsView.buttonsView.center.y);
    
    [UIView commitAnimations];
    [self updateCanSend];
    return attach;
}

- (void)convertImage:(UIImage *)image {
    NSData *data = nil;
    if ( image )
    {
        DLog(@"image dimesions %1.0fx%1.0f", image.size.width, image.size.height);
        DLog(@"coverting image data...");
        // Create NSData object as PNG image data from camera image
        //        data = UIImagePNGRepresentation(image);
        @try
        {
            if ( ( VK.photoQuality == 1.0 ) || ( VK.photoQuality < 0 ) )
                data = UIImagePNGRepresentation(image);
            else
                data = UIImageJPEGRepresentation(image, VK.photoQuality);
        }
        @catch (NSException *exception) {
            DLog(@"error %@", exception.description);
        }
        
        
        DLog(@"image size %lu bytes", (unsigned long)data.length);
    }
    if ( [NSThread isMainThread] )
        [self uploadMailImage:data];
    else
    {
        [self performSelectorOnMainThread:@selector(uploadMailImage:) withObject:data waitUntilDone:NO];
    }
}

- (void)updateAttachmetsHeight {
    if ( UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) )
    {
        if (sysVersionFloat() < 7.0)
            attachmetsHeight = iPadDevice() ? 352.0 : 162.0;
        else
            attachmetsHeight = iPadDevice() ? 352.0 : 202.0;
    }
    else
        attachmetsHeight = iPadDevice() ? 264.0 : 216.0;
    CGRect r = attachmentsView.frame;
    r.size.height = attachmetsHeight;
    //    r.origin.y = containerView.frame.origin.y+containerView.frame.size.height;
    attachmentsView.frame = r;
}

#pragma mark - UIImagePickerController

- (void)dismissPopover {
    if ( iPadDevice() && self.popoverController && [self.popoverController isPopoverVisible])
    {
        [self.popoverController dismissPopoverAnimated:YES];
    }
}

- (void)closeImagePicker {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self dismissPopover];
}

- (void)attachPhotoSource:(UIImagePickerControllerSourceType)sourceType {
    @try
    {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        if ( !imagePicker ) return;
        imagePicker.delegate = self;
        if ( [[[UIDevice currentDevice] systemVersion] doubleValue] >= 3.1 )
            imagePicker.allowsEditing = NO;
        else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
            imagePicker.allowsImageEditing = NO; // depricated in iOS 3.1
#pragma GCC diagnostic pop
        //        UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
        //            sourceType = UIImagePickerControllerSourceTypeCamera;
        //            sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        //            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        
        if ( [UIImagePickerController isSourceTypeAvailable:sourceType] )
        {
            imagePicker.sourceType = sourceType;
            if ( !iPadDevice() || ( iPadDevice() && ( imagePicker.sourceType == UIImagePickerControllerSourceTypeCamera )  ) )
                [self presentViewController:imagePicker animated:YES completion:nil];
            else
            {
                self.popoverController = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
                
                popoverController.delegate = self;
                [self.popoverController presentPopoverFromRect:self.navigationController.navigationBar.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
        }
    }
    @catch (NSException *exception)
    {
        DLog(@"NSException %@ (%@)", [exception name], [exception reason]);
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self closeImagePicker];
    DLog(@"%@",info);
    UIImage *image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    if ( image )
    {
        //        [SVProgressHUD showWithStatus:NSLocalizedString(@"Saving image", @"Сохранение изображения") maskType:SVProgressHUDMaskTypeGradient];
        [VK postMessage:NSLocalizedString(@"Saving image", @"Сохранение изображения")];
        [self insertImage:image attachType:kAttachTypeImage];
    }
    else
    {
        DLog(@"image null");
    }
    // Save image
    //    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self closeImagePicker];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *errorString = NSLocalizedString(@"Saving image error", @"Ошибка сохранения изображения!");
    [SVProgressHUD showErrorWithStatus:errorString];// afterDelay:2.0];
    [VK postErrorMessage:errorString];
    if (error)
    {
        DLog(@"image saving error %@", [error localizedFailureReason]);
    }
    //    [self updateProfileImage:nil];
}

#pragma mark - Remote API

- (void)uploadAttachments:(int)index {
    if ( index >= attachments.count )
    {
        [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"Attachments uploaded", @"Приложения загружены")];// afterDelay:2.0];
        if ( !isStringOk(self.attachmentsString) )
            self.attachmentsString = [NSMutableString string];
        
        if ( self.attachmentsString.length > 0 )
        {
            attachmentsString = [NSMutableString stringWithFormat:@",attachment:\"%@\"", attachmentsString];
        }
        if ( coordsSelected )
        {
            [attachmentsString insertString:[NSString stringWithFormat:@",lat:%f,\"long\":%f",coordinates.latitude,coordinates.longitude] atIndex:0];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:kAttachmentsUploaded object:self];
    }
    else
    {
        while (index < attachments.count) 
        {
            if ( index < 1 )
                attachmentsString = [NSMutableString string];
            self.currentIndex = index;
            self.currentAttach = [attachments objectAtIndex:self.currentIndex];
            if ( currentAttach.attachType != kAttachTypeGeo )
            {
                [NSThread detachNewThreadSelector:@selector(convertImage:) toTarget:self withObject:self.currentAttach.imageView.image];  
                break;
            }
            else
            {
                coordsSelected = YES;
                coordinates = self.currentAttach.coordinate;
                index++;
            }
        }
        if ( index >= attachments.count )
        {
            self.currentIndex = index;
            [self uploadAttachments:index];
        }
    }
}

- (void)vkApiResponseSavePhoto:(VKApiResponse *)api {
    DLog(@"response = %@", api.response);
    /*
     response =     (
     {
     aid = "-3";
     created = 1335941944;
     height = 2048;
     id = "photo60469063_282919589";
     "owner_id" = 60469063;
     pid = 282919589;
     src = "http://cs5730.userapi.com/v5730063/8ab/TYIVC1dDi4c.jpg";
     "src_big" = "http://cs5730.userapi.com/v5730063/8ac/mRmkStgaqZM.jpg";
     "src_small" = "http://cs5730.userapi.com/v5730063/8aa/5fkSUNL8LvI.jpg";
     "src_xbig" = "http://cs5730.userapi.com/v5730063/8ad/ZuiE3-kLuK4.jpg";
     "src_xxbig" = "http://cs5730.userapi.com/v5730063/8ae/PfCYA-OCHM4.jpg";
     "src_xxxbig" = "http://cs5730.userapi.com/v5730063/8af/pJXgW5M-i90.jpg";
     text = "";
     width = 1530;
     }
     );
     
     */
    if ( !api.error && isDictionaryOk(api.response) )
    {
        NSArray *array = [api.response objectForKey:kVKJResponse];
        if ( isArrayOk(array) )
        {
            NSDictionary *response = [array objectAtIndex:0];
            NSString *ids = [response objectForKey:@"id"];
            if ( isStringOk(ids) )
            {
                if ( !attachmentsString )
                    attachmentsString = [NSMutableString stringWithString:ids];
                else
                    [attachmentsString appendFormat:@",%@",ids];
                self.currentIndex++;
                [self uploadAttachments:currentIndex];
            }
        }
    }
//    [self loadProfile];
}

- (void)vkApiResponseGetServer:(VKApiResponse *)api {
    /*
     response =     {
     "upload_url" = "http://cs303302.vk.com/upload.php?act=profile&mid=170919126&hash=70688acc7354c4990855b6f444b9a766&rhash=0f3d25f5e5fe471b1cc91d92792db12f&swfupload=1&m_aid=-6";
     }
     */
    BOOL ok = NO;
    if ( isDictionaryOk(api.response) )
    {
        DLog(@"response = %@", api.response);
        NSDictionary *response = [api.response objectForKey:kVKJResponse];
        if ( isDictionaryOk(response) )
        {
            NSString *uploadUrl = [response valueForKey:@"upload_url"];
            if ( isStringOk(uploadUrl) )
            {
                NSURL *url = [NSURL URLWithString:uploadUrl];
                self.imageUploader = [[VKImageUploader alloc] initWithHostName:[url host] customHeaderFields:nil];
                // {"server":10507,"photo":"{\"width\":200,\"height\":200}","mid":1718216,"hash":"cd8bc54a77b7fc671c3e22af99d4061f","message_code":1,"profile_aid":-6}                                                                                  
                [SVProgressHUD showWithStatus:NSLocalizedString(@"Uploading photo to server...", @"Загрузка фото на сервер...")];
                self.uploadOperation = [self.imageUploader uploadImageFromData:imageData url:uploadUrl 
                                                                  onCompletion:^(NSDictionary *response)
                                        {
                                            NSError *error = [VK getErrorForResults:response showMessage:YES];
                                            if ( !error )
                                            {
                                                /*                            
                                                 hash = 6c0809ab344c950c3080672365ae53bc;
                                                 "message_code" = 2;
                                                 mid = 1718216;
                                                 photo = "{\"photo\":\"7b5688afe3:w\",\"sizes\":[[\"s\",\"10507216\",\"1e\",\"BTbnhHi2nEU\",56,75],[\"m\",\"10507216\",\"1f\",\"0iHOmrd7G8A\",97,130],[\"x\",\"10507216\",\"20\",\"A3oS0LxQfow\",451,604],[\"y\",\"10507216\",\"21\",\"f7_2Yw3kiS4\",603,807],[\"z\",\"10507216\",\"22\",\"WXHG9yUfC7I\",765,1024],[\"w\",\"10507216\",\"23\",\"8qEdyi_AR1I\",1530,2048],[\"o\",\"10507216\",\"24\",\"fIAl6-uCDvM\",130,174],[\"p\",\"10507216\",\"25\",\"yoDQTAgpGjY\",200,268],[\"q\",\"10507216\",\"26\",\"j-rgtbjZsqc\",320,428],[\"r\",\"10507216\",\"27\",\"It4g-Wm_oLU\",510,683]],\"kid\":\"97e70319575900de8f28da916f685632\",\"width\":200,\"height\":150}";
                                                 "profile_aid" = "-6";
                                                 server = 10507;
                                                 */
                                                [SVProgressHUD showWithStatus:NSLocalizedString(@"Saving to server...", @"Сохранение на сервере...")];
                                                NSNumber *server = [response objectForKey:@"server"];
                                                NSString *photo = [response objectForKey:@"photo"];
                                                NSString *hash = [response objectForKey:@"hash"];
                                                NSMutableDictionary *params = [NSMutableDictionary dictionary];
                                                [params setValue:server forKey:@"server"];
                                                [params setValue:photo forKey:@"photo"];
                                                [params setValue:hash forKey:@"hash"];
                                                [VK runVKApiMethod:kVKMPhotosSaveMailPhoto params:params delegate:self selector:@selector(vkApiResponseSavePhoto:)];
                                            }
                                            else
                                            {
                                                [SVProgressHUD showErrorWithStatus:error.localizedDescription];// duration:2.0];
                                            }
                                            
                                            //                      self.uploadProgessBar.progress = 0.0;
                                        } 
                                                                       onError:^(NSError* error) 
                                        {
                                            [SVProgressHUD showErrorWithStatus:error.localizedDescription];// duration:2.0];
                                        }];    
                ok = YES;
                [self.uploadOperation onUploadProgressChanged:^(double progress)
                 {
                     if ( (int)(progress*100) % 10 == 0 ) 
                         DLog(@"%.2f", progress*100.0);
                     //                    self.uploadProgessBar.progress = progress;
                 }];
            }
        }
    }
    if ( !ok )
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Saving image error", @"Ошибка сохранения изображения!")];// afterDelay:2.0];
}

- (void)uploadMailImage:(NSData *)data {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Waiting for reply from server...", @"Получение ответа от сервера...")];
    self.imageData = data;
    [VK runVKApiMethod:kVKMPhotosGetMailUploadServer params:nil delegate:self selector:@selector(vkApiResponseGetServer:)];
    DLog(@"length = %lu", (unsigned long)self.imageData.length);
}

- (BOOL)didReceiveVoiceResponse:(NSData *)data {
    //    NSDictionary *r = [VK.jsonDecoder objectWithData:data];
    NSError *error = nil;
    if (data.length < 1)
        return NO;
    
    NSDictionary *r = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if ( isDictionaryOk(r) )
    {
        DLog(@"result = %@",r);
        //        NSString *ids  = [r objectForKey:@"id"];
        //        NSNumber *status = [r objectForKey:@"status"];
        NSArray *hypotheses = [r objectForKey:@"hypotheses"];
        if ( isArrayOk(hypotheses) )
        {
            NSDictionary *hypothes = [hypotheses objectAtIndex:0];
            if ( isDictionaryOk(hypothes) )
            {
                //            NSNumber *confidence = [hypotheses objectForKey:@"confidence"];
                NSString *utterance = [hypothes objectForKey:@"utterance"];
                if ( isStringOk(utterance) )
                {
                    [textView appendString:utterance];
                    [textView sizeToFit];
                    [self updateActivity];
                }
            }
        }
    }
    /*
     hypotheses
     confidence
     utterance
     status
     id
     */
    return YES;
}

- (void)updateActivity {
    // Subclassed
}

- (void)getOlderMessages {
    
}

- (int)getMessagesCount {
    return 0;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cellIdentifier";
    
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[SSMessageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.bubbleView.selected = cell.selected;
        UILongPressGestureRecognizer *r = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(cellWasLongPressed:)];
        [cell addGestureRecognizer:r];
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        tapGesture.numberOfTapsRequired = 1;
        tapGesture.cancelsTouchesInView = NO;  // Must pass through the tap to the UITableView, otherwise we can't touch the rows
        [cell addGestureRecognizer:tapGesture];
    }
    cell.bubbleView.selected = cell.selected;
	
//    cell.messageStyle = [self messageStyleForRowAtIndexPath:indexPath];
//	cell.messageText = [self textForRowAtIndexPath:indexPath];
    VKMessage *message = [self messageForRowAtIndexPath:indexPath];
    cell.isChat = self.chatId > 0;
	cell.message = message;
    cell.isRead = message.read_state;
    if (!cell.isRead)
    {
        DLog(@"isRead = %i (%i %@)",cell.message.read_state,cell.isRead,cell.message.body);
    }
    // TODO: Mark as Read group of messages
    [message markAsReadWithOkBlock:^(BOOL ok) {
        if (ok)
            cell.isRead = NO;
    }];
//    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if ( (messages.count > 5) && (indexPath.row < 5) )
        [self getOlderMessages];

    return cell;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ( cell )
    {
        cell.bubbleView.selected = NO;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ( cell )
    {
        cell.bubbleView.selected = YES;
    }
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    VKMessage *m = [self messageForRowAtIndexPath:indexPath];
	return [SSMessageTableViewCellBubbleView cellHeightForMessage:m];
}

#pragma mark SSMessagesViewController

- (VKMessage *)messageForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - PAD Tilt Controls

- (id)pad_scrollView {
    return pad_scrollView;
}

- (void)toggleTiltUpdates {
    if (receivingTiltUpdates)
        [self stopReceivingTiltUpdates];
    else
        [self startReceivingTiltUpdates];
}

- (void)startReceivingTiltUpdates {
    if (!receivingTiltUpdates)
    {
        [self pad_startReceivingTiltUpdates];
        receivingTiltUpdates = YES;
    }
}

- (void)stopReceivingTiltUpdates {
    [self pad_stopReceivingTiltUpdates];
    receivingTiltUpdates = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(pad_state))]) {
        [self updateUserInterfaceForState:[object pad_state]];
    }
}

- (void)updateUserInterfaceForState:(NSInteger)state {
    if (state == PADTiltViewControllerStateInactive) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
        
        if (sysVersionFloat() >= 7.0)
        {
            self.navigationController.navigationBar.barTintColor = kVKbarTintColor;
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        }
        self.navigationController.navigationBar.topItem.prompt = nil;
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    else if (state == PADTiltViewControllerStateInitializing || state == PADTiltViewControllerStateCalibrating) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        if (sysVersionFloat() >= 7.0)
        {
            self.navigationController.navigationBar.barTintColor = [UIColor lightGrayColor];
        }
        self.navigationController.navigationBar.topItem.prompt = NSLocalizedString(@"Calibrating Sensors", nil);
    }
    else if (state == PADTiltViewControllerStateActive) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        
        if (sysVersionFloat() >= 7.0)
        {
            self.navigationController.navigationBar.barTintColor = [UIColor lightGrayColor];
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        }
//        self.navigationController.navigationBar.topItem.prompt = NSLocalizedString(@"Sensors On", nil);
        self.navigationController.navigationBar.topItem.prompt = nil;
        [self.navigationController setNavigationBarHidden:YES animated:YES];
//        self.titleLabel.text = NSLocalizedString(@"Sensors On", nil);
//        self.subtitleLabel.text = NSLocalizedString(@"Tap or swipe the content to disable sensors", nil);
    }
}

#pragma mark - Actions

- (IBAction)markAsUnread:(id)sender {
    // DONE: Mark as Unread (Now VK API Disabled this feature)
    DLog(@".");
    SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[_tableView cellForRowAtIndexPath:selectedIndexPath];
    if ( cell && cell.message )
    {
        [VK markAsUnread:[NSString stringWithFormat:@"%i",cell.message.idx] okBlock:^(VKApiResponse *apiResponse, BOOL ok) {
            if (ok)
                cell.message.read_state = NO;
        }];
    }
}

- (IBAction)sendText:(id)sender {
    DLog(@".");
}

- (IBAction)onMicButton:(id)sender {
    //    [speechToText beginRecording];
    //    [self performSelector:@selector(stopRecord) withObject:nil afterDelay:10.0];
}

- (IBAction)onClearButton:(id)sender {
    textView.text = @"";
}

- (IBAction)onAttachButton:(id)sender {
    [self toggleAttachmentsView];
}

- (IBAction)deleteAttach:(id)sender {
    int idx = (int)((UIButton *)sender).tag;
    [self deleteAttachAtIndex:idx];
}

- (IBAction)suggestFriend:(id)sender {
    addingParticipant = NO;
    ContactsViewController *contactsViewController = [[ContactsViewController alloc] initWithStyle:UITableViewStylePlain];
    contactsViewController.sourceMode = kSourceModeAdd;
    contactsViewController.isChoosing = YES;
    contactsViewController.delegate = self;
    contactsViewController.contactsMode = kContactsModeFriends;
    [self.navigationController pushViewController:contactsViewController animated:YES];
}

- (IBAction)addParticipant:(id)sender {
    addingParticipant = YES;
    ContactsViewController *contactsViewController = [[ContactsViewController alloc] initWithStyle:UITableViewStylePlain];
    contactsViewController.sourceMode = kSourceModeAdd;
    contactsViewController.isChoosing = YES;
    contactsViewController.delegate = self;
    contactsViewController.contactsMode = kContactsModeFriends;
    [self.navigationController pushViewController:contactsViewController animated:YES];
}

- (IBAction)addPhoto:(id)sender {
    [self attachPhotoSource:UIImagePickerControllerSourceTypeCamera];
}

- (IBAction)addFromPhotoLibrary:(id)sender {
    [self attachPhotoSource:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
}

- (IBAction)addGeo:(id)sender {
    MapViewController *mapViewController = nil;
    if ( iPadDevice() )
        mapViewController = [[MapViewController alloc] initWithNibName:@"MapViewController_iPad" bundle:nil];
    else
        mapViewController = [[MapViewController alloc] initWithNibName:@"MapViewController_iPhone" bundle:nil];
    if ( !mapViewController ) return;
    mapViewController.delegate = self;
    [self.navigationController presentViewController:mapViewController animated:YES completion:nil];
}

- (void)delete:(id)sender {
    DLog(@".");
    if ( selectedIndexPath )
    {
        SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[_tableView cellForRowAtIndexPath:selectedIndexPath];
        if ( cell && cell.message )
        {
            [VK deleteMessage:cell.message okBlock:^(VKApiResponse *apiResponse, BOOL ok) {
                if (ok)
                {
                    [self.messages removeObjectAtIndex:selectedIndexPath.row];
                    [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:selectedIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }];
        }
    }
}

- (void)copy:(id)sender {
    DLog(@".");
    if ( selectedIndexPath )
    {
        SSMessageTableViewCell *cell = (SSMessageTableViewCell *)[_tableView cellForRowAtIndexPath:selectedIndexPath];
        if ( cell && cell.message )
            [[UIPasteboard generalPasteboard] setString:cell.message.body];
        [_tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
        [cell setSelected:NO animated:YES];
        selectedIndexPath = nil;
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    //    DLog(@"%@",NSStringFromSelector(action));
    if ( ( action == @selector(copy:) ) || ( action == @selector(delete:) || ( action == @selector(markAsUnread:) ) ) )
        return YES;
    else
        return NO;
}

- (void)cellWasLongPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        DLog(@".");
        SSMessageTableViewCell *cell = (SSMessageTableViewCell *)recognizer.view;
        if (selectedIndexPath)
        {
            @try {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
                [cell setSelected:NO animated:YES];
            }
            @catch (NSException *exception) { DLog(@"%@",exception); }
        }
        if (![cell isKindOfClass:[SSMessageTableViewCell class]])
            return;
        
        CGPoint location = [recognizer locationInView:cell];
        if (![cell.bubbleView hasMessageAtLocation:location])
        {
            [self startReceivingTiltUpdates];
        }
        else
        {
            //show your UIMenuHere
            selectedIndexPath = [_tableView indexPathForCell:cell];
            [cell setSelected:YES animated:YES];
            [_tableView selectRowAtIndexPath:selectedIndexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
            UIMenuController *theMenu = [UIMenuController sharedMenuController];
            [theMenu setTargetRect:cell.bubbleView.bubbleFrame inView:cell.bubbleView];
            //        [_tableView becomeFirstResponder];
            UIMenuItem *menuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Unread", @"Не прочтено") action:@selector(markAsUnread:)];
            [theMenu setMenuItems:@[menuItem]];
            [theMenu setMenuVisible:YES animated:YES];
        }
        [self resignTextView];
    }
}

@end
