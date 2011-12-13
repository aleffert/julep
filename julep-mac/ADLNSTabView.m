//
//  ADLNSTabView.m
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLNSTabView.h"

#import "ADLColor.h"
#import "ADLNSGestureConstants.h"
#import "NSShadow+ADLExtensions.h"

@interface ADLNSTabView ()

@property (retain, nonatomic) NSImageView* backgroundView;
@property (retain, nonatomic) NSTextField* titleView;

@property (retain, nonatomic) NSTimer* dragTimer;
@property (assign, nonatomic, getter = isDragging) BOOL dragging;
@property (assign, nonatomic) NSPoint currentDragLocation;
- (void)updateAppearance;
- (void)dragBegan:(NSTimer*)timer;
- (void)dragEnded;
- (void)spawnDragTimer;
- (void)cancelDragTimer;

@end

@implementation ADLNSTabView

@dynamic layer;
@dynamic hidden;

@synthesize backgroundView = mBackgroundView;
@synthesize currentDragLocation = mCurrentDragLocation;
@synthesize delegate = mDelegate;
@synthesize dragging = mDragging;
@synthesize dragTimer = mDragTimer;
@synthesize titleView = mTitleView;
@synthesize title = mTitle;
@synthesize selected = mSelected;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.backgroundView = [[[NSImageView alloc] initWithFrame:self.bounds] autorelease];
        [self updateAppearance];
        [self addSubview:self.backgroundView];
        
        self.titleView = [[[NSTextField alloc] initWithFrame:NSInsetRect(self.bounds, 8, 4)] autorelease];
        self.titleView.bezeled = NO;
        self.titleView.backgroundColor = [NSColor clearColor];
        self.titleView.alignment = NSCenterTextAlignment;
        self.titleView.delegate = self;
        self.titleView.editable = YES;
        self.titleView.selectable = NO;
        [self addSubview:self.titleView];
    }
    
    return self;
}

- (void)dealloc {
    self.backgroundView = nil;
    self.titleView = nil;
    self.delegate = nil;
    self.title = nil;
    [self cancelDragTimer];
    
    [super dealloc];
}

- (void)setTitle:(NSString *)newTitle {
    NSString* temp = [newTitle copy];
    [mTitle release];
    mTitle = temp;
    
    self.titleView.stringValue = newTitle;
}

- (void)setSelected:(BOOL)selected {
    if(selected != mSelected) {
        mSelected = selected;
        [self updateAppearance];
    }
}

- (void)updateAppearance {
    if(self.selected) {
        self.backgroundView.image = [NSImage imageNamed:@"ADLTabSelected"];
    }
    else {
        self.backgroundView.image = [NSImage imageNamed:@"ADLTabUnselected"];
    }
}

#pragma mark <NSTextFieldDelegate>

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.titleView resignFirstResponder];
    self.titleView.selectable = NO;
    self.titleView.editable = NO;
    NSString* newTitle = self.titleView.stringValue;
    if (newTitle.length > 0 && ![newTitle isEqualToString:self.title]) {
        [self.delegate shouldChangeTitleOfTab:self to:newTitle];
    }
}

#pragma mark Touch Interaction

- (void)cancelDragTimer {
    [self.dragTimer invalidate];
    self.dragTimer = nil;
}

- (void)spawnDragTimer {
    self.dragTimer = [NSTimer scheduledTimerWithTimeInterval:kADLDragInterval target:self selector:@selector(dragBegan:) userInfo:nil repeats:NO];
}

- (void)mouseUp:(NSEvent *)theEvent {
    if(self.dragging) {
        [self dragEnded];
    }
    else {
        [self cancelDragTimer];
        if(theEvent.clickCount == 1) {
            [self.delegate shouldSelectTab:self];
        }
        else if(theEvent.clickCount == 2) {
            self.titleView.selectable = YES;
            self.titleView.editable = YES;
            [self.titleView becomeFirstResponder];
        }
    }
}

- (void)dragBegan:(NSTimer*)timer {
    self.alphaValue = .75;
    [self.delegate beginDraggingTab:self];
    self.dragging = YES;
}

- (void)dragEnded {
    self.alphaValue = 1;
    self.dragging = NO;
    [self.delegate endDraggingTab:self];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    if(self.dragging) {
        NSPoint newLocation = theEvent.locationInWindow;
        NSPoint parentLocation = [self.superview convertPoint:newLocation fromView:nil];
        CGFloat delta = newLocation.x - self.currentDragLocation.x;
        [self.delegate draggedTab:self toParentLocation:parentLocation.x withDelta:delta];
        
        self.currentDragLocation = newLocation;
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [self spawnDragTimer];
    self.currentDragLocation = theEvent.locationInWindow;
}

@end
