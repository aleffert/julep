//
//  ADLItem.h
//  julep
//
//  Created by Akiva Leffert on 10/14/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ADLList;

@interface ADLItem : NSManagedObject

@property (nonatomic, retain) NSString * uid;
@property (nonatomic, retain) ADLList *owner;

@end
