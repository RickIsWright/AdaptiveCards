//
//  ViewController.m
//  ViewController
//
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "ViewController.h"
#import "ACRChatWindow.h"
#import "ACRCustomSubmitTargetBuilder.h"
#import "ADCResolver.h"
#import "AdaptiveCards/ACRAggregateTarget.h"
#import "AdaptiveCards/ACRButton.h"
#import "AdaptiveFileBrowserSource.h"
#import "CustomActionNewType.h"
#import "CustomActionOpenURLRenderer.h"
#import "CustomActionSetRenderer.h"
#import "CustomInputNumberRenderer.h"
#import "CustomProgressBarRenderer.h"
#import "CustomTextBlockRenderer.h"
#import <SafariServices/SafariServices.h>

CGFloat kAdaptiveCardsWidth = 360;

@interface ViewController () {
    BOOL _enableCustomRenderer;
    ACOResourceResolvers *_resolvers;
    id<ACRIBaseActionSetRenderer> _defaultRenderer;
    ACRChatWindow *_dataSource;
}

@end

@implementation ViewController
+ (void)applyConstraints:(NSArray<NSString *> *)formats variables:(NSDictionary *)variables
{
    NSArray<NSLayoutConstraint *> *constraints = nil;

    for (NSString *format in formats) {
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:format
                                                              options:0
                                                              metrics:nil
                                                                views:variables];
        [NSLayoutConstraint activateConstraints:constraints];
    }
}

- (IBAction)editText:(id)sender
{
    if (!self.editableStr) {
        return;
    }

    UIStackView *filebrowserView = self.compositeFileBrowserView;
    if (!self.editView) {
        CGRect desiredDimension = filebrowserView.frame;
        self.editView = [[UITextView alloc] initWithFrame:desiredDimension textContainer:nil];

        [self.view addSubview:self.editView];
        self.editView.directionalLockEnabled = NO;
        self.editView.showsHorizontalScrollIndicator = YES;
        self.editView.keyboardType = UIKeyboardTypeAlphabet;

        CGRect frame = CGRectMake(0, 0, self.editView.frame.size.width, 30);
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:frame];
        UIBarButtonItem *flexSpace =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                          target:nil
                                                          action:nil];
        UIBarButtonItem *doneButton =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                          target:self
                                                          action:@selector(dismissKeyboard)];
        [toolBar setItems:@[ doneButton, flexSpace ] animated:NO];
        [toolBar sizeToFit];
        self.editView.inputAccessoryView = toolBar;
    }
    self.editView.hidden = NO;
    self.editView.delegate = self;

    NSMutableAttributedString *content =
        [[NSMutableAttributedString alloc] initWithString:self.editableStr];
    NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
    para.lineBreakMode = NSLineBreakByCharWrapping;
    para.alignment = NSTextAlignmentLeft;
    [content addAttributes:@{NSParagraphStyleAttributeName : para} range:NSMakeRange(0, 1)];
    self.editView.attributedText = content;
    UIFontDescriptor *dec = self.editView.font.fontDescriptor;
    self.editView.font = [UIFont fontWithDescriptor:dec size:15];
    self.editView.layer.borderWidth = 0.8;
    filebrowserView.hidden = YES;
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
    return YES;
}

- (void)dismissKeyboard
{
    [self.editView resignFirstResponder];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [textView becomeFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
}

- (IBAction)toggleCustomRenderer:(id)sender
{
    _enableCustomRenderer = !_enableCustomRenderer;
    ACRRegistration *registration = [ACRRegistration getInstance];

    if (_enableCustomRenderer) {
        // enum will be part of API in next iterations when custom renderer extended to non-action
        // type - tracked by issue #809
        [registration setActionRenderer:[CustomActionOpenURLRenderer getInstance]
                        cardElementType:@3];
        [registration setBaseCardElementRenderer:[CustomTextBlockRenderer getInstance]
                                 cardElementType:ACRTextBlock];
        [registration setBaseCardElementRenderer:[CustomInputNumberRenderer getInstance]
                                 cardElementType:ACRNumberInput];
        [registration setBaseCardElementRenderer:[CustomActionSetRenderer getInstance] cardElementType:ACRActionSet];

        [[ACRTargetBuilderRegistration getInstance] setTargetBuilder:[ACRCustomSubmitTargetBuilder getInstance] actionElementType:ACRSubmit capability:ACRAction];
        [[ACRTargetBuilderRegistration getInstance] setTargetBuilder:[ACRCustomSubmitTargetBuilder getInstance] actionElementType:ACRSubmit capability:ACRQuickReply];
        _enableCustomRendererButton.backgroundColor = UIColor.redColor;
        _defaultRenderer = [registration getActionSetRenderer];
        [registration setActionSetRenderer:self];
    } else {
        [registration setActionRenderer:nil cardElementType:@3];
        [registration setBaseCardElementRenderer:nil cardElementType:ACRTextBlock];
        [registration setBaseCardElementRenderer:nil cardElementType:ACRNumberInput];
        [registration setBaseCardElementRenderer:nil cardElementType:ACRImage];
        [registration setBaseCardElementRenderer:nil cardElementType:ACRActionSet];
        [registration setActionSetRenderer:nil];
        _enableCustomRendererButton.backgroundColor = [UIColor colorWithRed:0 / 255
                                                                      green:122.0 / 255
                                                                       blue:1
                                                                      alpha:1];
    }
    [self update:self.editableStr];
}

- (IBAction)applyText:(id)sender
{
    if (_editView.text != NULL && ![_editView.text isEqualToString:@""]) {
        [self update:self.editView.text];
    }
    self.editView.hidden = YES;
    self.compositeFileBrowserView.hidden = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    kAdaptiveCardsWidth = [[UIScreen mainScreen] bounds].size.width - 32.0f;
    
    NSString *errorMSG = @"{\"type\": \"AdaptiveCard\", \"$schema\": "
                         @"\"http://adaptivecards.io/schemas/adaptive-card.json\",\"version\": "
                         @"\"1.2\", \"body\": [ {"
                         @"\"type\": \"TextBlock\", \"text\": \"Rendering Failed\","
                         @"\"weight\": \"Bolder\", \"color\": "
                         @"\"Attention\", \"horizontalAlignment\": \"Center\""
                         @"} ] }";
    _errorCard = [ACOAdaptiveCard fromJson:errorMSG];
    [self registerForKeyboardNotifications];
    _resolvers = [[ACOResourceResolvers alloc] init];
    ADCResolver *resolver = [[ADCResolver alloc] init];
    [_resolvers setResourceResolver:resolver scheme:@"http"];
    [_resolvers setResourceResolver:resolver scheme:@"https"];
    [_resolvers setResourceResolver:resolver scheme:@"data"];
    // register a custom scheme bundle with resolver
    [_resolvers setResourceResolver:resolver scheme:@"bundle"];
    _enableCustomRenderer = NO;
    self.curView = nil;

    self.ACVTabVC = [[ACVTableViewController alloc] init];
    [self addChildViewController:self.ACVTabVC];
    self.ACVTabVC.delegate = self;
    self.ACVTabVC.tableView.rowHeight = 25;
    self.ACVTabVC.tableView.sectionFooterHeight = 5;
    self.ACVTabVC.tableView.sectionHeaderHeight = 5;
    self.ACVTabVC.tableView.scrollEnabled = YES;
    self.ACVTabVC.tableView.showsVerticalScrollIndicator = YES;
    self.ACVTabVC.tableView.userInteractionEnabled = YES;
    self.ACVTabVC.tableView.bounces = YES;
    self.ACVTabVC.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    UITableView *ACVTabView = self.ACVTabVC.tableView;
    _compositeFileBrowserView = [[UIStackView alloc] init];
    _compositeFileBrowserView.backgroundColor = UIColor.lightGrayColor;
    _compositeFileBrowserView.translatesAutoresizingMaskIntoConstraints = NO;
    _compositeFileBrowserView.alignment = UIStackViewAlignmentCenter;
    _compositeFileBrowserView.axis = UILayoutConstraintAxisVertical;
    [self.view addSubview:_compositeFileBrowserView];
    [_compositeFileBrowserView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor
                                                            constant:10]
        .active = YES;
    [_compositeFileBrowserView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                             constant:-10]
        .active = YES;

    UIView *fileBrowserView =
        [[AdaptiveFileBrowserSource alloc] initWithFrame:CGRectMake(20, 40, kAdaptiveCardsWidth, 55)
                                        WithDataDelegate:self.ACVTabVC];
    fileBrowserView.translatesAutoresizingMaskIntoConstraints = NO;
    [_compositeFileBrowserView addArrangedSubview:fileBrowserView];

    [_compositeFileBrowserView addArrangedSubview:ACVTabView];
    ACVTabView.translatesAutoresizingMaskIntoConstraints = NO;
    ACVTabView.showsVerticalScrollIndicator = YES;

    [ACVTabView.widthAnchor constraintEqualToAnchor:fileBrowserView.widthAnchor].active = YES;
    self.ACVTabVC.tableHeight = [ACVTabView.heightAnchor constraintEqualToConstant:200.0];
    self.ACVTabVC.tableHeight.active = YES;
    ACVTabView.hidden = YES;

    UIStackView *buttonLayout = [[UIStackView alloc] init];
    self.buttonLayout = buttonLayout;

    // try button
    buttonLayout.axis = UILayoutConstraintAxisVertical;
    self.tryButton = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.tryButton setTitle:@"Try Yourself" forState:UIControlStateNormal];
    [self.tryButton setTitleColor:[UIColor colorWithRed:0 / 255 green:122.0 / 255 blue:1 alpha:1]
                         forState:UIControlStateSelected];
    self.tryButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;

    [self.tryButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.tryButton addTarget:self
                       action:@selector(editText:)
             forControlEvents:UIControlEventTouchUpInside];
    [buttonLayout addArrangedSubview:self.tryButton];
    self.tryButton.backgroundColor = [UIColor colorWithRed:0 / 255
                                                     green:122.0 / 255
                                                      blue:1
                                                     alpha:1];
    self.tryButton.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);

    // apply button
    self.applyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyButton setTitle:@"Apply" forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor colorWithRed:0 / 255 green:122.0 / 255 blue:1 alpha:1]
                           forState:UIControlStateSelected];
    [self.applyButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    self.applyButton.backgroundColor = [UIColor colorWithRed:0 / 255
                                                       green:122.0 / 255
                                                        blue:1
                                                       alpha:1];
    self.applyButton.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);

    [self.applyButton addTarget:self
                         action:@selector(applyText:)
               forControlEvents:UIControlEventTouchUpInside];
    [buttonLayout addArrangedSubview:self.applyButton];

    // custon renderer button
    self.enableCustomRendererButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.enableCustomRendererButton
        setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.enableCustomRendererButton setTitle:@"Enable Custom Renderer"
                                     forState:UIControlStateNormal];
    [self.enableCustomRendererButton setTitleColor:[UIColor colorWithRed:0 / 255
                                                                   green:122.0 / 255
                                                                    blue:1
                                                                   alpha:1]
                                          forState:UIControlStateSelected];
    [self.enableCustomRendererButton setTitleColor:UIColor.whiteColor
                                          forState:UIControlStateNormal];
    self.enableCustomRendererButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;

    self.enableCustomRendererButton.backgroundColor = [UIColor colorWithRed:0 / 255
                                                                      green:122.0 / 255
                                                                       blue:1
                                                                      alpha:1];
    self.enableCustomRendererButton.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);

    [self.enableCustomRendererButton addTarget:self
                                        action:@selector(toggleCustomRenderer:)
                              forControlEvents:UIControlEventTouchUpInside];
    [buttonLayout addArrangedSubview:self.enableCustomRendererButton];
    self.applyButton.layer.cornerRadius = 10;
    self.tryButton.layer.cornerRadius = 10;
    self.enableCustomRendererButton.layer.cornerRadius = 10;

    [self.view addSubview:buttonLayout];
    buttonLayout.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonLayout.widthAnchor constraintEqualToConstant:kAdaptiveCardsWidth].active = YES;
    [buttonLayout.centerXAnchor constraintEqualToAnchor:fileBrowserView.centerXAnchor].active = YES;

    buttonLayout.alignment = UIStackViewAlignmentFill;
    buttonLayout.distribution = UIStackViewDistributionEqualCentering;
    buttonLayout.spacing = 10;

    self.chatWindow = [[UITableView alloc] init];
    self.chatWindow.translatesAutoresizingMaskIntoConstraints = NO;
    self.chatWindow.separatorStyle = UITableViewCellSeparatorStyleNone;
    _dataSource = [[ACRChatWindow alloc] init];
    _dataSource.adaptiveCardsDelegates = self;
    self.chatWindow.dataSource = _dataSource;

    [self.view addSubview:self.chatWindow];

    UITableView *chatWindow = self.chatWindow;
    NSDictionary *viewMap =
        NSDictionaryOfVariableBindings(_compositeFileBrowserView, buttonLayout, chatWindow);

    NSArray<NSString *> *formats = [NSArray
        arrayWithObjects:@"V:|-70-[_compositeFileBrowserView]-[buttonLayout]-[chatWindow]-40@100-|",
                         @"H:|-[chatWindow]-|", nil];

    [ViewController applyConstraints:formats variables:viewMap];

    ACOFeatureRegistration *featureReg = [ACOFeatureRegistration getInstance];
    [featureReg addFeature:@"acTest" featureVersion:@"1.0"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)update:(NSString *)jsonStr
{
    self.editableStr = jsonStr;
    [_dataSource insertCard:jsonStr];
    [self.chatWindow reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    float verticalContentInset = self.scrView.frame.size.height - self.curView.frame.size.height;
    verticalContentInset = (verticalContentInset <= 0) ? 20 : verticalContentInset;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, verticalContentInset, 0.0);
    self.scrView.contentInset = contentInsets;
}

- (void)fromACVTable:(ACVTableViewController *)avcTabVc userSelectedJson:(NSString *)jsonStr
{
    [self update:jsonStr];
}

- (void)source:(ACVTableViewController *)avcTabVc userconfig:(NSString *)payload
{
    self.hostconfig = payload;
}

- (void)didFetchUserResponses:(ACOAdaptiveCard *)card action:(ACOBaseActionElement *)action
{
    if (action.type == ACROpenUrl) {
        NSURL *url = [NSURL URLWithString:[action url]];
        SFSafariViewController *svc = [[SFSafariViewController alloc] initWithURL:url];
        [self presentViewController:svc animated:YES completion:nil];
    } else if (action.type == ACRSubmit) {
        NSData *userInputsAsJson = [card inputs];
        NSString *actionDataField = [action data];

        NSData *actionData = [actionDataField dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *combinedData = [actionData mutableCopy];
        [combinedData appendData:userInputsAsJson];
        NSString *str = [[NSString alloc] initWithData:combinedData
                                              encoding:NSUTF8StringEncoding];
        [self presentViewController:[self createAlertController:@"user response fetched" message:str] animated:YES completion:nil];

    } else if (action.type == ACRUnknownAction) {
        if ([action isKindOfClass:[CustomActionNewType class]]) {
            CustomActionNewType *newType = (CustomActionNewType *)action;
            newType.alertController = [self createAlertController:@"successfully rendered new button type" message:newType.alertMessage];
            [self presentViewController:newType.alertController animated:YES completion:nil];
        }
    } else if (action.type == ACRToggleVisibility) {
        NSLog(@"toggle visibility");
    } else {
        if (@available(iOS 11.0, *)) {
            [self.chatWindow performBatchUpdates:^(void) {
                [self.chatWindow reloadRowsAtIndexPaths:self.chatWindow.indexPathsForVisibleRows withRowAnimation:UITableViewRowAnimationNone];}
                                      completion:nil];
        } else {
            [self.chatWindow reloadData];
        }
    }
}

- (UIAlertController *)createAlertController:(NSString *)title message:(NSString *)message
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
    return alertController;
}

- (void)didChangeViewLayout:(CGRect)oldFrame newFrame:(CGRect)newFrame
{
    //[self.chatWindow reloadData];
}

- (void)didChangeViewLayout:(CGRect)oldFrame newFrame:(CGRect)newFrame properties:(NSDictionary *)properties
{
    NSString *actiontype = (NSString *)properties[ACRAggregateTargetActionType];
    if ([actiontype isEqualToString:ACRAggregateTargetSubmitAction]) {
        UIView *focusedView = properties[ACRAggregateTargetFirstResponder];
        if (focusedView && [focusedView isKindOfClass:[UIView class]]) {
            [self.chatWindow setContentOffset:focusedView.frame.origin animated:YES];
            [self.chatWindow reloadData];
        }
    } else {
        [self.chatWindow scrollRectToVisible:newFrame animated:YES];
    }
}

- (void)didChangeVisibility:(UIButton *)button isVisible:(BOOL)isVisible
{
    if (isVisible) {
        button.backgroundColor = [UIColor redColor];
    } else {
        if ([button isKindOfClass:[ACRButton class]]) {
            ACRButton *acrButton = (ACRButton *)button;
            if (acrButton.sentiment &&
                [@"default" caseInsensitiveCompare:acrButton.sentiment] != NSOrderedSame) {
                [acrButton applySentimentStyling];
            } else {
                button.backgroundColor = [UIColor colorWithRed:0.11 green:0.68 blue:0.97 alpha:1.0];
            }
        } else {
            button.backgroundColor = [UIColor colorWithRed:0.11 green:0.68 blue:0.97 alpha:1.0];
        }
    }
}

- (void)didFetchMediaViewController:(AVPlayerViewController *)controller
                               card:(ACOAdaptiveCard *)card
{
    [self addChildViewController:controller];
    [controller didMoveToParentViewController:self];
}

- (UIView *)renderButtons:(ACRView *)rootView
                   inputs:(NSMutableArray *)inputs
                superview:(UIView<ACRIContentHoldingView> *)superview
                     card:(ACOAdaptiveCard *)card
               hostConfig:(ACOHostConfig *)config
{
    UIView *actionSetView = [_defaultRenderer renderButtons:rootView
                                                     inputs:inputs
                                                  superview:superview
                                                       card:card
                                                 hostConfig:config];
    ((UIScrollView *)actionSetView).showsHorizontalScrollIndicator = NO;
    return actionSetView;
}
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification *)aNotification
{
    NSDictionary *info = [aNotification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGSize kbSize = kbFrame.size;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    CGRect scrollViewFrame = _scrView.frame;
    if (scrollViewFrame.origin.y + scrollViewFrame.size.height > kbFrame.origin.y) {
        self.scrView.contentInset = contentInsets;
        self.scrView.scrollIndicatorInsets = contentInsets;
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification *)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrView.contentInset = contentInsets;
    self.scrView.scrollIndicatorInsets = contentInsets;
}

- (void)didLoadElements
{
    NSArray *arrayOfRowsToReload = @[ [NSIndexPath indexPathForRow:[self.chatWindow numberOfRowsInSection:0] - 1 inSection:0] ];
    [self.chatWindow reloadRowsAtIndexPaths:arrayOfRowsToReload withRowAnimation:UITableViewRowAnimationNone];
}

@end
