//
//  NSArray+ADLAdditions.h
//  julep
//
//  Created by Akiva Leffert on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (ADLAdditions)

- (NSArray*)arrayByMappingObjects:(id (^)(id object))mapper;

@end


@interface NSMutableArray (ADLAdditions)

+ (NSMutableArray*)nonretainingMutableArray;
@end