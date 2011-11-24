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

@class ADLNSTabViewController;
@class ADLListsPileViewController;
@class ADLAgnosticDocumentViewController;

@interface ADLDocumentViewController : NSViewController <ADLPileViewControllerDelegate, ADLCollectionChangedListener, ADLListViewControllerDelegate> {
    ADLNSTabViewController* mTabController;
    ADLListsPileViewController* mPileController;
    ADLAgnosticDocumentViewController* mAgnostic;
}

- (id)initWithModel:(ADLModelAccess*)modelAccess;

- (void)wasAddedToWindow;

@end
