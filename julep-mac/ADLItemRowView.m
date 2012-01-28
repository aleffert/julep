//
//  ADLItemRowView.m
//  julep
//
//  Created by Akiva Leffert on 1/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ADLItemRowView.h"

void ADLDrawThreePartImage(NSImage* image, NSRect targetRect, CGFloat leftCapWidth);

void ADLDrawThreePartImage(NSImage* image, NSRect targetRect, CGFloat leftCapWidth) {
    CGFloat rightCapWidth = image.size.width - leftCapWidth - 1;
    NSRect dstRect = targetRect;
    NSRect srcRect = NSMakeRect(0, 0, image.size.width, image.size.height);
    
    // Left
    srcRect.size.width = leftCapWidth;
    dstRect.size.width = leftCapWidth;
    [image drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.];
    
    // Center
    srcRect.origin.x = leftCapWidth;
    srcRect.size.width = 1;
    dstRect.origin.x += leftCapWidth;
    dstRect.size.width = targetRect.size.width - leftCapWidth - rightCapWidth;
    [image drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.];
    
    // Right
    srcRect.origin.x = leftCapWidth + 1;
    srcRect.size.width = rightCapWidth;
    dstRect.origin.x = NSMaxX(dstRect);
    dstRect.size.width = rightCapWidth;
    [image drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.];
}

@implementation ADLItemRowView

- (id)initWithFrame:(NSRect)frameRect{
    if((self = [super initWithFrame:frameRect])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAppearance) name:NSApplicationDidResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAppearance) name:NSApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (NSBackgroundStyle)interiorBackgroundStyle {
    return self.selected ? NSBackgroundStyleDark : NSBackgroundStyleLight;
}

- (BOOL)isFlipped {
    return NO;
}

- (void)updateAppearance {
    [self setNeedsDisplay:YES];
}

- (NSImage*)backgroundImageForCurrentState {
    BOOL active = [[NSApplication sharedApplication] isActive];
    if(active) {
        if(self.selected) {
            return [NSImage imageNamed:@"ADLItemSelected"];
        }
        else {
            return [NSImage imageNamed:@"ADLItemUnselected"];
        }
    }
    else {
        if(self.selected) {
            return [NSImage imageNamed:@"ADLItemSelectedInactive"];
        }
        else {
            return [NSImage imageNamed:@"ADLItemUnselectedInactive"];
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    NSImage* image = [self backgroundImageForCurrentState];
    ADLDrawThreePartImage(image, NSOffsetRect(NSInsetRect(self.bounds, 4, 2), 0, -2), 40);
}

@end
