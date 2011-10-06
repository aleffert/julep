//
//  ADLDocumentViewController.h
//  julep
//
//  Created by Akiva Leffert on 9/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLListViewController.h"
#import "ADLPileViewController.h"
#import "ADLModelAccess.h"

@interface ADLDocumentViewController : NSViewController <ADLPileViewControllerDelegate, ADLCollectionChangedListener, ADLListViewControllerDelegate>

- (id)initWithModel:(ADLModelAccess*)modelAccess;

- (void)wasAddedToWindow;

@end
