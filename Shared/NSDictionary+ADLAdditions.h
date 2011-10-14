//
//  NSDictionary+ADLAdditions.h
//  julep
//
//  Created by Akiva Leffert on 10/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (ADLAdditions)

+ (NSMutableDictionary*)noCopyingMutableDictionary;

@end
