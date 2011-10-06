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
@end

@implementation ADLListViewController

@synthesize listID = mListID;
@synthesize textView = mTextView;

- (id)init {
    if((self = [super initWithNibName:@"ADLListViewController" bundle:nil])) {
    }
    
    return self;
}

- (void)dealloc {
    self.textView = nil;
    [super dealloc];
}

- (ADLColorView*)colorView {
    return (ADLColorView*)self.view;
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
    
    [self.view addSubview:scrollview];
    
    [scrollview release];
}

- (void)loadView {
    [super loadView];
    [self viewDidLoad];
}

@end
