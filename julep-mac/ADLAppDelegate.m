//
//  ADLAppDelegate.m
//  julep-mac
//
//  Created by Akiva Leffert on 8/22/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <CalendarStore/CalendarStore.h>

#import <ShortcutRecorder/ShortcutRecorder.h>
#import <ShortcutRecorder/PTHotKeyCenter.h>
#import <ShortcutRecorder/PTHotKey.h>
#import <ShortcutRecorder/PTKeyCombo.h>

#import "ADLAppDelegate.h"

#import "ADLListsDocument.h"
#import "ADLModelAccess.h"
#import "ADLPreferencesController.h"
#import "ADLUIElementServer.h"

#import "NSArray+ADLAdditions.h"

static NSString* kADLQuickCreateCode = @"kADLQuickCreateCode";
static NSString* kADLQuickCreateFlags = @"kADLQuickCreateFlags";
static NSString* kADLQuickCreateHotKeyIdentifier = @"kADLQuickCreateHotKeyIdentifier";

@interface ADLAppDelegate ()

- (void)openMainDocument;
- (NSString*)mainDocumentName;
- (NSString*)applicationName;
- (NSURL*)applicationSupportSubdirectoryURL;

- (void)registerQuickCreateHotKey;
- (void)startServer;

- (IBAction)showPreferences:(id)sender;

@property (retain, nonatomic) ADLListsDocument* mainDocument;
@property (retain, nonatomic) ADLAppServer* server;
@property (retain, nonatomic) ADLPreferencesController* preferencesController;

- (NSRunningApplication*)UIElementChildProcess;

@end

static NSString* kADLApplicationName = @"Julep";
static NSString* kADLMainDocumentName = @"database.julep";
static NSString* kADLJulepDocumentType = @"julep";

@implementation ADLAppDelegate

@synthesize mainDocument = mMainDocument;
@synthesize preferencesController = mPreferencesController;
@synthesize server = mServer;

- (void)dealloc {
    self.mainDocument = nil;
    self.preferencesController = nil;
    self.server = nil;
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self openMainDocument];
    [self registerQuickCreateHotKey];
    [self UIElementChildProcess]; // spawn ui element daemon
    [self startServer];
}

- (void)startServer {
    self.server = [[[ADLAppServer alloc] init] autorelease];
    self.server.delegate = self;
    [self.server start];
}

- (NSRunningApplication*)UIElementChildProcess {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"Julep-UIElement" withExtension:@"app"];
    NSError* error = nil;
    NSRunningApplication* app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchWithoutActivation configuration:NULL error:&error];
    NSAssert(error == nil, @"error spawning child process");
    return app;
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
    NSError* error = nil;
    ADLListsDocument* document = nil;
    if([self.mainDocumentURL checkResourceIsReachableAndReturnError:&error]) {
        document = [[ADLListsDocument alloc] initWithContentsOfURL: self.mainDocumentURL ofType:kADLJulepDocumentType error:&error];
    }
    else {
        error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:self.applicationSupportSubdirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
        NSAssert(error == nil, @"Error creating application support subdirectory: %@", error);
        document = [[ADLListsDocument alloc] init];
        [document saveToURL:self.mainDocumentURL ofType:kADLJulepDocumentType forSaveOperation:NSSaveOperation error:&error];
        [document.modelAccess populateDefaults];
    }
    
    [document.modelAccess syncWithDataStore];
    
    NSAssert(document != nil, @"Unable to open main document");
    NSAssert(error == nil, @"Error opening document: %@", error);
    
    self.mainDocument = document;
    
    [[NSDocumentController sharedDocumentController] addDocument:self.mainDocument];
    [self.mainDocument makeWindowControllers];
    [self.mainDocument showWindows];
    
    [document release];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    return [self.mainDocument shouldApplicationTerminate];
}

- (void)applicationWillBecomeActive:(NSNotification *)notification {
    if([NSApplication sharedApplication].windows.count == 0) {
        [self.mainDocument showWindows];
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return NO;
}

#pragma mark Preferences

- (void)showPreferences:(id)sender {
    if(self.preferencesController == nil) {
        self.preferencesController = [[[ADLPreferencesController alloc] initWithWindow:nil] autorelease];
        self.preferencesController.modelAccess = self.mainDocument.modelAccess;
        self.preferencesController.listIDs = self.mainDocument.modelAccess.listIDs;
        self.preferencesController.delegate = self;
    }
    [self.preferencesController showWindow:sender];
}

- (void)saveQuickCreateKeyCombo:(KeyCombo)combo {
    [[NSUserDefaults standardUserDefaults] setInteger:combo.flags forKey:kADLQuickCreateFlags];
    [[NSUserDefaults standardUserDefaults] setInteger:combo.code forKey:kADLQuickCreateCode];
}

- (void)showQuickCreateFromHotKey:(PTHotKey*)hotKey {
    id <ADLUIElementServer> uiServer = (ADLUIElementServer*)[NSConnection rootProxyForConnectionWithRegisteredName:kADLUIServerName host:nil];
    
    ADLModelAccess* modelAccess = self.mainDocument.modelAccess;
    NSArray* listIDs = modelAccess.listIDs;
    NSArray* listNames = [listIDs arrayByMappingObjects:^(id object) {
        ADLListID* listID = object;
        return [modelAccess titleOfList:listID];
    }];
    NSArray* listURLs = [listIDs arrayByMappingObjects:^(id object) {
        ADLListID* listID = object;
        return listID.URIRepresentation;
    }];
    
    [uiServer showQuickCreateWithListIDs:listURLs named:listNames];
}

- (BOOL)hasQuickCreateKeyCombo {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kADLQuickCreateFlags] != nil;
}

- (KeyCombo)quickCreateKeyCombo {
    KeyCombo combo = SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags);
    combo.code = [[NSUserDefaults standardUserDefaults] integerForKey:kADLQuickCreateCode];
    combo.flags = [[NSUserDefaults standardUserDefaults] integerForKey:kADLQuickCreateFlags];
    return combo;
}

- (void)registerQuickCreateHotKey {
    if ([self hasQuickCreateKeyCombo]) {
        KeyCombo combo = [self quickCreateKeyCombo];
        PTKeyCombo* keyCombo = [PTKeyCombo keyComboWithKeyCode:combo.code modifiers:SRCocoaToCarbonFlags(combo.flags)];
        
        PTHotKey* hotKey = [[PTHotKey alloc] initWithIdentifier:kADLQuickCreateHotKeyIdentifier keyCombo:keyCombo];
        hotKey.target = self;
        hotKey.action = @selector(showQuickCreateFromHotKey:);
        [[PTHotKeyCenter sharedCenter] registerHotKey:hotKey];
        [hotKey release];
    }
}

- (void)changedQuickCreateKeyComboTo:(KeyCombo)combo {
    PTHotKeyCenter* hotKeyCenter = [PTHotKeyCenter sharedCenter];
    PTHotKey* hotKey = [hotKeyCenter hotKeyWithIdentifier:kADLQuickCreateHotKeyIdentifier];
    [hotKeyCenter unregisterHotKey:hotKey];
    [self saveQuickCreateKeyCombo:combo];
    [self registerQuickCreateHotKey];
}

- (void)addItemWithTitle:(NSString *)title toList:(NSURL *)list {
    ADLListID* listID = [self.mainDocument.modelAccess listIDForURL:list];
    [self.mainDocument.modelAccess addItemWithTitle:title toListWithID:listID];
}

@end
