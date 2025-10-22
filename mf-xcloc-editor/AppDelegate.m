//
//  AppDelegate.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "MainWindowController.h"

@implementation AppDelegate

#pragma mark - Lifecycle

NSString *getXclocPath(void) {
    NSString *xclocPath;
    if ((0)) xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
    if ((0)) xclocPath = @"/Users/noah/mmf-stuff/mf-xcloc-editor/mf-xcloc-editor/example-docs/da.xcloc";
    else     xclocPath = @"/Users/noah/Downloads/Mac Mouse Fix Translations (German)/Mac Mouse Fix.xcloc";
    return xclocPath;
}

NSString *getXliffPath(NSString *xclocPath) {
    NSString *xliffPath = findPaths(xclocPath, ^BOOL (NSString *p){
        return [p hasSuffix: @".xliff"];
    })[0];
    return xliffPath;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self->mainController = [MainWindowController new];
    Outlets outlets = [self->mainController makeMainWindow];
    
    self->tableView = outlets.tableView;
    self->sourceList = outlets.sourceList;
    self->filterField = outlets.filterField;
    
    /// Get xcloc path
    auto xclocPath = getXclocPath();
    self->xclocPath = xclocPath;
    
    
    #define fail(msg...) ({ \
        mflog(msg); /** TODO: Maybe show an NSAlert. */\
        exit(1); \
    })
    
    
    {
        /// Load xliff
        NSXMLDocument *doc = nil;
        {
            auto xliffPath = getXliffPath(xclocPath);
        
            NSError *err = nil;
            doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: xliffPath] options: NSXMLNodeOptionsNone error: &err];
            if (err) fail(@"Loading XMLDocument from path '%@' failed with error: '%@'", xliffPath, err);
        }
        
        /// Load localizedStringData.plist
        NSArray *localizedStringsDataPlist = nil;
        {
            auto stringsDataPath = findPaths(xclocPath, ^BOOL (NSString *p) {
                return [p hasSuffix: @"localizedStringData.plist"];
            })[0];
            
            
            NSError *err = nil;
            localizedStringsDataPlist = [[NSArray alloc] initWithContentsOfURL: [NSURL fileURLWithPath: stringsDataPath] error: &err];
            if (err) fail(@"Loading localizedStringsData.plist failed with error: %@", err);
            
            /// TESTING
            mflog(@"Loaded localizedStringsData.plist: %@", localizedStringsDataPlist);
        }
        
        /// Store localizedStringsDataPlist
        self->tableView.localizedStringsDataPlist = localizedStringsDataPlist;
        
        /// Update SourceList
        self->sourceList.xliffDoc = doc;
        [self->sourceList reloadData];
    }
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification {

    /// Add menuItems
    
    
    if ((0)) /// Tried programmatically adding to mainMenu but then AppKit sends weird messages to AppDelegate like `-[submenu]`, `-[menu]` and `-[_requiresKERegistration]`.
    { /// Add "Find" item.
        auto fileMenuItem = [[NSApp mainMenu] itemAtIndex: 1];
        assert([fileMenuItem.title isEqual: @"File"]);
        [fileMenuItem.menu addItem: [NSMenuItem separatorItem]];
        [fileMenuItem.menu addItem: ({
            auto i = [NSMenuItem new];
            i.title = @"Find";
            i.keyEquivalent = @"F";
            i.image = [NSImage imageWithSystemSymbolName: @"magnifyingglass" accessibilityDescription: nil];
            i.keyEquivalentModifierMask = NSEventModifierFlagCommand;
            i.action = @selector(filterMenuItemSelected:);
            i.target = self;
        })];
    }
}

- (IBAction) filterMenuItemSelected: (id)sender {
    [self->filterField.window makeFirstResponder: self->filterField];
}

- (IBAction)quickLookMenuItemSelected:(id)sender {
    [self->tableView togglePreviewPanel: sender];
}


- (void) writeTranslationDataToFile {
    
    /// Write to file
    NSError *err = nil;
    NSString *xliffPath = getXliffPath(getXclocPath());
    
    [[self->sourceList.xliffDoc XMLStringWithOptions: NSXMLNodePrettyPrint] writeToFile: xliffPath atomically: YES encoding: NSUTF8StringEncoding error: &err];
    if (err) {
        assert(false);
        mflog(@"An error occured while writing to the xliff file: %@", err);
    }
    mflog(@"Wrote to xliff file: %@", xliffPath);
    
    /// Reload UI (Probably unnecessary) [Oct 2025]
    if ((0)) [self->sourceList reloadData];

}

- (BOOL) applicationSupportsSecureRestorableState: (NSApplication *)app { return YES; }
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender { return YES; }

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender {
    
    /// Close all windows
    ///     (Otherwise our `windowWillClose:` callbacks aren't called. See https://stackoverflow.com/q/2997571.
    for (NSWindow *w in [NSApp windows])
        [w close];
    
    return NSTerminateNow;
}

@end
