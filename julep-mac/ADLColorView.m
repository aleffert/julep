//
//  ADLColorView.m
//  julep
//
//  Created by Akiva Leffert on 9/19/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLColorView.h"

@interface ADLColorView ()

@property (retain, nonatomic) CALayer* colorLayer;

@end

@implementation ADLColorView

@synthesize colorLayer = mColorLayer;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.layer = [CALayer layer];
        self.wantsLayer = YES;
        self.layer.frame = self.bounds;
        self.colorLayer = [CALayer layer];
        self.colorLayer.frame = self.bounds;
        self.colorLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        self.colorLayer.needsDisplayOnBoundsChange = YES;
        // Deal with the CALayer vs NSView coordinate systems
        self.colorLayer.affineTransform = CGAffineTransformMakeScale(1., -1);
        [self.layer addSublayer:self.colorLayer];
    }
    
    return self;
}

- (void)dealloc {
    self.colorLayer = nil;
    [super dealloc];
}

- (CGColorRef)backgroundColor {
    return self.colorLayer.backgroundColor;
}

- (void)setBackgroundColor:(CGColorRef)backgroundColor {
    self.colorLayer.backgroundColor = backgroundColor;
}

@end
