//
//  ADLAppDelegate.m
//  julep
//
//  Created by Akiva Leffert on 8/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ADLAppDelegate.h"

#import "ADLDocumentViewController.h"
#import "ADLListsDocument.h"
#import "ADLModelAccess.h"

@interface ADLAppDelegate ()

//@property (retain, nonatomic) UIWindow *window;
@property (retain, nonatomic) UITabBarController* tabController;

@property (retain, nonatomic) ADLListsDocument* mainDocument;
@property (retain, nonatomic) ADLDocumentViewController* documentViewController;

- (void)openMainDocument;

@end

static NSString* kADLApplicationName = @"Julep";
static NSString* kADLMainDocumentName = @"database.julep";
static NSString* kADLJulepDocumentType = @"julep";

@implementation ADLAppDelegate

@synthesize mainDocument = mMainDocument;
@synthesize window = mWindow;
@synthesize tabController = mTabController;
@synthesize documentViewController = mDocumentViewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    [self.window makeKeyAndVisible];
    ADLDocumentViewController* dvc = [[ADLDocumentViewController alloc] initWithNibName:nil bundle:nil];
    dvc.tabBarItem.title = @"Lists";
    // Override point for customization after application launch.
    self.tabController = [[[UITabBarController alloc] init] autorelease];
    self.tabController.viewControllers = [NSArray arrayWithObjects:dvc, nil];
    
    self.window.rootViewController = self.tabController;
    self.documentViewController = dvc;
    
    [dvc release];
    
    [self openMainDocument];
    
    return YES;
}


- (NSString*)mainDocumentName {
    return kADLMainDocumentName;
}

- (NSString*)applicationName {
    return kADLApplicationName;
}

- (NSURL*)applicationSupportSubdirectoryURL {
    NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSAssert(urls.count > 0, @"Unable to find application support directory");
    NSURL* appSupportURL = [urls objectAtIndex:0];
    return [appSupportURL URLByAppendingPathComponent:self.applicationName isDirectory:YES];
}

- (NSURL*)mainDocumentURL {
    return [self.applicationSupportSubdirectoryURL URLByAppendingPathComponent:self.mainDocumentName];
}

- (void)openMainDocument {
    NSURL* documentURL = self.mainDocumentURL;
    ADLListsDocument* document = [[ADLListsDocument alloc] initWithFileURL:documentURL];
    
    self.mainDocument = document;
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    document.persistentStoreOptions = options;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:documentURL.path]) {
        [document openWithCompletionHandler:^(BOOL success){
            NSAssert(success, @"Unable to open document");
            self.documentViewController.modelAccess = document.modelAccess;
            [document.modelAccess syncWithDataStore];
        }];
    }
    else {
        NSError* error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:self.applicationSupportSubdirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
        [document saveToURL:documentURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
            NSAssert(success, @"Unable to do initial save");
            [document.modelAccess populateDefaults];
            [document.modelAccess syncWithDataStore];
            self.documentViewController.modelAccess = document.modelAccess;
        }];
    }
    
    [document release];
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
