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
#import "ADLPreferencesController.h"
#import "ADLUIElementServer.h"

#import "NSArray+ADLAdditions.h"

static NSString* kADLKeyboardShorcutCode = @"kADLQuickCreateCode";
static NSString* kADLKeyboardShortcutFlags = @"kADLQuickCreateFlags";

@interface ADLAppDelegate ()

- (void)openMainDocument;
- (NSString*)mainDocumentName;
- (NSString*)applicationName;
- (NSURL*)applicationSupportSubdirectoryURL;

- (void)registerHotKeyWithIdentifier:(NSString*)identifier;
- (void)startServer;

- (IBAction)showPreferences:(id)sender;

@property (retain, nonatomic) ADLListsDocument* mainDocument;
@property (retain, nonatomic) ADLAppServer* server;
@property (retain, nonatomic) ADLPreferencesController* preferencesController;

- (NSRunningApplication*)UIElementChildProcess;
- (void)updateDockBadgeCount;

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
    [self registerHotKeyWithIdentifier:kADLQuickCreateHotKeyIdentifier];
    [self registerHotKeyWithIdentifier:kADLQuickToggleHotKeyIdentifier];
    [self UIElementChildProcess]; // spawn ui element daemon
    [self startServer];
    [self updateDockBadgeCount];
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

- (id <ADLUIElementServer>)UIElementServer {
    [self UIElementChildProcess];
    return (ADLUIElementServer*)[NSConnection rootProxyForConnectionWithRegisteredName:kADLUIServerName host:nil];
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
    
    [self.mainDocument.modelAccess addModelChangedListener:self];
    
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

- (void)updateDockBadgeCount {
    NSDockTile* tile = [NSApp dockTile];
    NSUInteger unfinishedCount = self.mainDocument.modelAccess.unfinishedCountForBadge;
    if(unfinishedCount > 0) {
        tile.badgeLabel = [NSString stringWithFormat:@"%d", unfinishedCount];
    }
    else {
        tile.badgeLabel = nil;
    }
}

- (void)modelChanged:(ADLModelAccess *)model {
    [self updateDockBadgeCount];
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

#pragma mark Hot Keys

- (void)saveKeyCombo:(KeyCombo)combo withIdentifier:(NSString*)identifier {
    NSDictionary* comboDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithUnsignedInteger:combo.flags], kADLKeyboardShortcutFlags,
                               [NSNumber numberWithInteger:combo.code], kADLKeyboardShorcutCode,
                               nil];
    [[NSUserDefaults standardUserDefaults] setObject:comboDict forKey:identifier];
}

- (BOOL)hasKeyComboForIdentifier:(NSString *)identifier {
    return [[NSUserDefaults standardUserDefaults] objectForKey:identifier] != nil;
}

- (KeyCombo)keyComboForIdentifier:(NSString *)identifier {
    KeyCombo combo = SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags);
    NSDictionary* comboDict = [[NSUserDefaults standardUserDefaults] objectForKey:identifier];
    NSAssert(comboDict != nil, @"Asking for key combo when none exists");
    combo.code = [[comboDict objectForKey:kADLKeyboardShorcutCode] integerValue];
    combo.flags = [[comboDict objectForKey:kADLKeyboardShortcutFlags] integerValue];
    return combo;
}

- (void)registerHotKeyWithIdentifier:(NSString *)identifier {
    if ([self hasKeyComboForIdentifier:identifier]) {
        KeyCombo combo = [self keyComboForIdentifier:identifier];
        PTKeyCombo* keyCombo = [PTKeyCombo keyComboWithKeyCode:combo.code modifiers:SRCocoaToCarbonFlags(combo.flags)];
        
        PTHotKey* hotKey = [[PTHotKey alloc] initWithIdentifier:identifier keyCombo:keyCombo];
        hotKey.target = self;
        hotKey.action = @selector(hotKeyPressed:);
        [[PTHotKeyCenter sharedCenter] registerHotKey:hotKey];
        [hotKey release];
    }
}

- (void)clearSavedHotKeyWithIdentifier:(NSString*)identifier {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:identifier];
}

- (void)changedKeyComboTo:(KeyCombo)combo forIdentifier:(NSString *)identifier {
    PTHotKeyCenter* hotKeyCenter = [PTHotKeyCenter sharedCenter];
    PTHotKey* hotKey = [hotKeyCenter hotKeyWithIdentifier:kADLQuickCreateHotKeyIdentifier];
    [hotKeyCenter unregisterHotKey:hotKey];
    if(combo.code == ShortcutRecorderEmptyCode) {
        [self clearSavedHotKeyWithIdentifier:identifier];
    }
    else {
        [self saveKeyCombo:combo withIdentifier:identifier];
        [self registerHotKeyWithIdentifier:identifier];
    }
}


- (void)showQuickCreate {
    id <ADLUIElementServer> uiServer = self.UIElementServer;
    
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

- (void)showQuickToggle {
    id <ADLUIElementServer> uiServer = self.UIElementServer;
    [uiServer showQuickToggle];
}

- (void)hotKeyPressed:(PTHotKey*)hotKey {
    if([hotKey.identifier isEqual:kADLQuickCreateHotKeyIdentifier]) {
        [self showQuickCreate];
    }
    else if([hotKey.identifier isEqual:kADLQuickToggleHotKeyIdentifier]) {
        [self showQuickToggle];
    }
    else {
        NSAssert(NO, @"Unexpected hot key");
    }
}

#pragma mark UIServer Messages

- (void)addItemWithTitle:(NSString *)title toList:(NSURL *)list {
    ADLModelAccess* modelAccess = self.mainDocument.modelAccess;
    ADLListID* listID = [modelAccess listIDForURL:list];
    [modelAccess addItemWithTitle:title toListWithID:listID];
}


- (NSArray*)itemsWithSearchString:(NSString*)query {
    ADLModelAccess* modelAccess = self.mainDocument.modelAccess;
    NSArray* items = [modelAccess itemsWithSearchString:query];
    NSArray* result = [items arrayByMappingObjects:^(id object) {
        ADLItemID* itemID = object;
        ADLListID* list = [modelAccess listOwningItem:itemID];
        NSString* listTitle = [modelAccess titleOfList:list];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                itemID.URIRepresentation, @"url",
                [modelAccess titleOfItem:itemID], @"title",
                [NSNumber numberWithBool:[modelAccess completionStatusOfItem:itemID]], @"status",
                listTitle, @"list",
                nil];
    }];
    return result;
}

- (void)toggleItemAtURL:(NSURL *)url {
    ADLModelAccess* modelAccess = self.mainDocument.modelAccess;
    ADLItemID* itemID = [modelAccess itemIDForURL:url];
    BOOL status = [modelAccess completionStatusOfItem:itemID];
    [modelAccess setCompletionStatus:!status ofItem:itemID];
}

@end
