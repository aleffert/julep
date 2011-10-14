//
//  ADLUITabView.h
//  julep
//
//  Created by Akiva Leffert on 10/8/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLTabView.h"

@interface ADLUITabView : UIImageView <ADLTabView, UITextFieldDelegate>

@property (assign, nonatomic) id <ADLTabViewDelegate> delegate;

@end
