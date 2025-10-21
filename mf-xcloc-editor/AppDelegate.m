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

NSString *getXliffPath(void) {
    NSString *xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
    NSString *xliffPath = [xclocPath stringByAppendingPathComponent: @"Localized Contents/da.xliff"];
    return xliffPath;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self->mainController = [MainWindowController new];
    Outlets outlets = [self->mainController makeMainWindow];
    
    self->tableView = outlets.tableView;
    self->sourceList = outlets.sourceList;
    
    NSString *xliffPath = getXliffPath();
    
    NSError *err = nil;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: xliffPath] options: NSXMLNodeOptionsNone error: &err];
    if (err) fail(end, @"Loading XMLDocument from path '%@' failed with error: '%@'", xliffPath, err);

    self->sourceList.xliffDoc = doc;
    [self->sourceList reloadData];
    
    end: {}
    
}

- (void) writeTranslationDataToFile {
    
    /// Write to file
    NSError *err = nil;
    NSString *xliffPath = getXliffPath();
    [[self->sourceList.xliffDoc XMLString] writeToFile: xliffPath atomically: YES encoding: NSUTF8StringEncoding error: &err];
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
