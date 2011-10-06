//
//  ADLListsPileViewController.h
//  julep
//
//  Created by Akiva Leffert on 10/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLPileViewController.h"

@class ADLListViewController;

@interface ADLListsPileViewController : ADLPileViewController

@end


@interface ADLListsPileViewController (ADLCast)

@property (retain, nonatomic) ADLListViewController* currentViewController;
@property (retain, nonatomic) ADLListViewController* nextViewController;
@property (retain, nonatomic) ADLListViewController* prevViewController;

@end