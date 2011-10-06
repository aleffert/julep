//
//  ADLColor.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ADLColor : NSObject

+ (ADLColor*)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
+ (ADLColor*)colorWithWhite:(CGFloat)white alpha:(CGFloat)a;
+ (ADLColor*)colorWithCGColor:(CGColorRef)color;

+ (ADLColor*)whiteColor;
+ (ADLColor*)blackColor;
+ (ADLColor*)redColor;
+ (ADLColor*)greenColor;
+ (ADLColor*)blueColor;
+ (ADLColor*)clearColor;
+ (ADLColor*)cyanColor;
+ (ADLColor*)scrollViewBackgroundColor;

@property (readonly, assign, nonatomic) CGColorRef CGColor;

@end
