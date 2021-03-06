//
//  ADLTableView.m
//  julep
//
//  Created by Akiva Leffert on 12/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLTableView.h"

@implementation ADLTableView

- (void)keyDown:(NSEvent *)theEvent {
    if([theEvent.characters isEqualToString:@" "]) { // SPACE
        [self.delegate tableViewShouldToggleSelection:self];
    }
    else if([theEvent.characters isEqualToString:@"\033"]) { // ESCAPE
        [self.delegate tableViewShouldClearSelection:self];
    }
    else if([theEvent.characters isEqualToString:@"\r"]) { // RETURN
        [self.delegate tableViewShouldEditSelection:self];
    }
    else {
        [super keyDown:theEvent];
    }
}

-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    CGFloat newWidth = self.enclosingScrollView.frame.size.width;
    if(self.tableColumns.count > 0) {
        [[self.tableColumns objectAtIndex:0] setWidth:newWidth];
    }
}

@end
