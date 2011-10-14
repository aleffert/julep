//
//  ADLUITabView.m
//  julep
//
//  Created by Akiva Leffert on 10/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLUITabView.h"

#import "ADLUIGestureConstants.h"

@interface ADLUITabView ()

@property (retain, nonatomic) UITextField* titleView;

@property (assign, nonatomic, getter = isDragging) BOOL dragging;
@property (assign, nonatomic) CGPoint currentDragLocation;
- (void)updateAppearance;


@end

@implementation ADLUITabView

@dynamic layer;
@dynamic hidden;

@synthesize currentDragLocation = mCurrentDragLocation;
@synthesize delegate = mDelegate;
@synthesize dragging = mDragging;
@synthesize titleView = mTitleView;
@synthesize title = mTitle;
@synthesize selected = mSelected;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self updateAppearance];
        
        self.titleView = [[[UITextField alloc] initWithFrame:CGRectInset(self.bounds, 8, 4)] autorelease];
        self.titleView.backgroundColor = [UIColor clearColor];
        self.titleView.textAlignment = UITextAlignmentCenter;
        self.titleView.delegate = self;
        self.titleView.userInteractionEnabled = NO;
        
        UILongPressGestureRecognizer* dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dragTab:)];
        dragGesture.minimumPressDuration = kADLDragInterval;
        
        UITapGestureRecognizer* editGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editTitleTapped:)];
        editGesture.numberOfTapsRequired = 2;
        
        UITapGestureRecognizer* selectGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectTapped:)];
        
        [self.titleView addGestureRecognizer:dragGesture];
        [self.titleView addGestureRecognizer:editGesture];
        [self.titleView addGestureRecognizer:selectGesture];
        
        [dragGesture release];
        [editGesture release];
        [selectGesture release];
        
        [self addSubview:self.titleView];
    }
    
    return self;
}

- (void)dealloc {
    self.titleView = nil;
    self.delegate = nil;
    self.title = nil;
    
    [super dealloc];
}

- (void)setTitle:(NSString *)newTitle {
    [newTitle retain];
    [mTitle release];
    mTitle = newTitle;
    
    self.titleView.text = newTitle;
}

- (void)setSelected:(BOOL)selected {
    if(selected != mSelected) {
        mSelected = selected;
        [self updateAppearance];
    }
}

- (void)updateAppearance {
    if(self.selected) {
        self.image = [UIImage imageNamed:@"ADLTabSelected"];
    }
    else {
        self.image = [UIImage imageNamed:@"ADLTabUnselected"];
    }
}

#pragma mark <UITextFieldDelegate>

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSAssert(textField == self.titleView, @"Unexpected text field");
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.titleView resignFirstResponder];
    self.titleView.userInteractionEnabled = NO;
    NSString* newTitle = self.titleView.text;
    if (newTitle.length > 0 && ![newTitle isEqualToString:self.title]) {
        [self.delegate shouldChangeTitleOfTab:self to:newTitle];
    }
}

- (void)selectTapped:(id)sender {
    if(!self.selected) {
        [self.delegate shouldSelectTab:self];
    }
}

- (void)editTitleTapped:(id)sender {
    self.titleView.userInteractionEnabled = YES;
    [self.titleView becomeFirstResponder];
}

- (void)dragBegan:(UILongPressGestureRecognizer*)gesture {
    self.currentDragLocation = [gesture locationInView:self.window];
    self.layer.opacity = .75;
    [self.delegate beginDraggingTab:self];
    self.dragging = YES;
}

- (void)dragChanged:(UILongPressGestureRecognizer*)gesture {
    CGPoint newLocation = [gesture locationInView:self.window];
    CGPoint parentLocation = [self.superview convertPoint:newLocation fromView:nil];
    CGFloat delta = newLocation.x - self.currentDragLocation.x;
    [self.delegate draggedTab:self toParentLocation:parentLocation.x withDelta:delta];
    
    self.currentDragLocation = newLocation;
}

- (void)dragEnded {
    self.layer.opacity = 1;
    self.dragging = NO;
    [self.delegate endDraggingTab:self];
}

- (void)dragCancelled {
    self.layer.opacity = 1;
    self.dragging = NO;
    [self.delegate cancelDraggingTab:self];
}

- (void)dragTab:(UILongPressGestureRecognizer*)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [self dragBegan:gesture];
            break;
        case UIGestureRecognizerStateChanged:
            [self dragChanged:gesture];
        case UIGestureRecognizerStateEnded:
            [self dragEnded];
        case UIGestureRecognizerStateCancelled:
            [self dragCancelled];
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStatePossible:
            NSAssert(NO, @"Unexpected gesture state");
            break;
    }
}

@end
