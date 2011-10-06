//
//  ADLView.h
//  julep
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@protocol ADLView <NSObject>

@property (readonly, nonatomic) CALayer* layer;
@property (assign, nonatomic, getter=isHidden) BOOL hidden;

- (void)removeFromSuperview;

@end
