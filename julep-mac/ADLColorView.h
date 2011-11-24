//
//  ADLColorView.h
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ADLColorView : NSView {
    CALayer* mColorLayer;
}

@property (assign, nonatomic) CGColorRef backgroundColor;

@end
