//
//  ADLItemViewTextField.m
//  julep
//
//  Created by Akiva Leffert on 12/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLItemViewTextField.h"

@implementation ADLItemViewTextField

- (void)mouseDown:(NSEvent *)theEvent {
    NSLog(@"foo");
}

- (void)mouseUp:(NSEvent *)theEvent {
    if (theEvent.clickCount == 2 && self.currentEditor != nil) {
        [self.window makeFirstResponder:self];
    }
}

@end
