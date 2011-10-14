//
//  ADLColor.m
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLColor.h"

@interface ADLColor ()

@property (assign, nonatomic) CGColorRef CGColor;

@end

@implementation ADLColor

@synthesize CGColor = mCGColor;

- (ADLColor*)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    self = [super init];
    if(self) {
#if TARGET_OS_IPHONE
        self.CGColor = [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
#else
        CGColorRef color = CGColorCreateGenericRGB(r, g, b, a);
        self.CGColor = color;
        CGColorRelease(color);
#endif
    }
    return self;
}

- (ADLColor*)initWithCGColor:(CGColorRef)color {
    self = [super init];
    if(self) {
        self.CGColor = color;
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)setCGColor:(CGColorRef)newColor {
    CGColorRetain(newColor);
    CGColorRelease(mCGColor);
    mCGColor = newColor;
}

+ (ADLColor*)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    return [[[self alloc] initWithRed:r green:g blue:b alpha:a] autorelease];
}

+ (ADLColor*)colorWithWhite:(CGFloat)white alpha:(CGFloat)a {
    return [self colorWithRed:white green:white blue:white alpha:a];
}

+ (ADLColor*)colorWithCGColor:(CGColorRef)color {
    return [[[self alloc] initWithCGColor:color] autorelease];
}

#if !TARGET_OS_IPHONE

static void ADLDrawPatternImage (void *info, CGContextRef ctx)
{
    CGImageRef image = (CGImageRef) info;
    CGContextDrawTiledImage(ctx, CGRectMake(0,0, CGImageGetWidth(image),CGImageGetHeight(image)), image);
}

// callback for CreateImagePattern.
static void ADLReleasePatternImage( void *image )
{
    CGImageRelease((CGImageRef)image);
}

+ (ADLColor*)colorWithNSImage:(NSImage*)image {
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    
    static CGPatternCallbacks callbacks = {0, ADLDrawPatternImage, ADLReleasePatternImage};
    CGPatternRef pattern = CGPatternCreate(cgImage, CGRectMake(0, 0, width, height), CGAffineTransformIdentity, width, height, kCGPatternTilingConstantSpacingMinimalDistortion, true, &callbacks);
    
    CGColorSpaceRef space = CGColorSpaceCreatePattern(NULL);
    CGFloat components[1] = {1.};
    CGColorRef color = CGColorCreateWithPattern(space, pattern, components);
    
    ADLColor* result = [self colorWithCGColor:color];
    CGColorRelease(color);
    CGColorSpaceRelease(space);
    CGPatternRelease(pattern);
    return result;
}
#endif

+ (ADLColor*)clearColor {
    return [self colorWithWhite:0. alpha:0.];
}

+ (ADLColor*)blackColor {
    return [self colorWithWhite:0. alpha:1.];
}

+ (ADLColor*)whiteColor {
    return [self colorWithWhite:1. alpha:1.];
}

+ (ADLColor*)greenColor {
    return [self colorWithRed:0 green:1. blue:0. alpha:1.];
}

+ (ADLColor*)redColor {
    return [self colorWithRed:1. green:0. blue:0. alpha:1.];
}

+ (ADLColor*)blueColor {
    return [self colorWithRed:0. green:0. blue:1. alpha:1.];
}

+ (ADLColor*)cyanColor {
    return [self colorWithRed:0 green:1. blue:1. alpha:1.];
}

+ (ADLColor*)scrollViewBackgroundColor {
#if TARGET_OS_IPHONE
    return [ADLColor colorWithCGColor:[UIColor scrollViewTexturedBackgroundColor].CGColor];
#elif TARGET_OS_MAC
    return [ADLColor colorWithNSImage:[NSImage imageNamed:@"ADLLinen"]];
#endif
}

@end
