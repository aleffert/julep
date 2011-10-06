//
//  ADLItem.h
//  julep
//
//  Created by Akiva Leffert on 9/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ADLList;

@interface ADLItem : NSManagedObject {
@private
}
@property (nonatomic, retain) ADLList *owner;

@end
