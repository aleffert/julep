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

@property (retain, nonatomic) CALayer* backgroundLayer;
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

@synthesize backgroundLayer = mBackgroundLayer;
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
        self.wantsLayer = YES;
        
        self.backgroundLayer = [CALayer layer];
        self.backgroundLayer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        [self updateAppearance];
        [self.layer addSublayer:self.backgroundLayer];
        
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
    self.backgroundLayer = nil;
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
        self.backgroundLayer.contents = [NSImage imageNamed:@"ADLTabSelected"];
    }
    else {
        self.backgroundLayer.contents = [NSImage imageNamed:@"ADLTabUnselected"];
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
    self.layer.opacity = .75;
    [self.delegate beginDraggingTab:self];
    self.dragging = YES;
}

- (void)dragEnded {
    self.layer.opacity = 1;
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
