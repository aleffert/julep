//
//  ADLListViewController.m
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListViewController.h"

@interface ADLListViewController ()

@property (retain, nonatomic) NSTextView* textView;
@property (retain, nonatomic) NSString* savedBodyText;
@property (assign, nonatomic) BOOL hasChanges;

@end

@implementation ADLListViewController

@synthesize listID = mListID;
@synthesize textView = mTextView;
@synthesize delegate = mDelegate;
@synthesize savedBodyText = mSavedBodyText;
@synthesize hasChanges = mHasChanges;

- (id)init {
    if((self = [super initWithNibName:@"ADLListViewController" bundle:nil])) {
    }
    
    return self;
}

- (void)dealloc {
    if(self.hasChanges) {
        [self.delegate listViewController:self textChangedTo:self.textView.textStorage.string];
    }
    [self.delegate listViewControllerWillDealloc:self];
    self.textView = nil;
    [super dealloc];
}

- (void)viewDidLoad {
    self.view.wantsLayer = YES;
    
    NSScrollView *scrollview = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    scrollview.wantsLayer = YES;
    NSSize contentSize = [scrollview contentSize];
    
    scrollview.borderType = NSNoBorder;
    scrollview.hasVerticalScroller = YES;
    scrollview.hasHorizontalScroller = NO;
    scrollview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollview.verticalScrollElasticity = NSScrollElasticityAllowed;
    
    self.textView = [[[NSTextView alloc] initWithFrame:self.view.bounds] autorelease];
    self.textView.wantsLayer = YES;
    self.textView.verticallyResizable = YES;
    self.textView.horizontallyResizable = NO;
    self.textView.minSize = CGSizeMake(0, contentSize.height);
    self.textView.maxSize = CGSizeMake(FLT_MAX, FLT_MAX);
    self.textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.textView.textContainer.containerSize = NSMakeSize(contentSize.width, FLT_MAX);
    self.textView.textContainer.widthTracksTextView = YES;
    scrollview.documentView = self.textView;
    
    if(self.savedBodyText != nil) {
        self.bodyText = self.savedBodyText;
        self.savedBodyText = nil;
    }
    
    self.textView.delegate = self;
    
    [self.view addSubview:scrollview];
    
    [scrollview release];
}

- (void)didActivate {
    NSAssert(self.textView != nil, @"Text view not initialized");
    [self.textView.window makeFirstResponder:self.textView];
    self.textView.window.initialFirstResponder = self.textView;
}

- (void)textDidChange:(NSNotification *)notification {
    self.hasChanges = YES;
}

- (void)textDidEndEditing:(NSNotification*)notification {
    if(self.hasChanges) {
        [self.delegate  listViewController:self textChangedTo:self.textView.textStorage.string];
        self.hasChanges = NO;
    }
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

- (void)setBodyText:(NSString *)bodyText {
    if(self.textView == nil) {
        self.savedBodyText = bodyText;
    }
    NSRange textRange = NSMakeRange(0, self.textView.textStorage.length);
    [self.textView.textStorage replaceCharactersInRange:textRange withString:bodyText];
}

- (NSString*)bodyText {
    return self.textView.textStorage.string;
}

- (void)changedListWithID:(ADLListID *)listID bodyText:(NSString*)bodyText {
    if([listID isEqual: self.listID] && ![self.textView.string isEqualToString:bodyText]) {
        self.bodyText = bodyText;
    }
}

@end
