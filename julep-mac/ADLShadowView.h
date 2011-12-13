//
//  ADLShadowView.h
//  julep
//
//  Created by Akiva Leffert on 12/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ADLShadowView : NSView

@property (retain, nonatomic) NSShadow* shadow;
@property (assign, nonatomic) NSEdgeInsets insets;

@end
