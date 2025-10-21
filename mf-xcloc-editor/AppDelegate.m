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
    
    NSString *xclocPath;
    if ((0)) xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
    if ((0)) xclocPath = @"/Users/noah/mmf-stuff/mf-xcloc-editor/mf-xcloc-editor/example-docs/da.xcloc";
    else     xclocPath = @"/Users/noah/Downloads/Mac Mouse Fix Translations (German)/Mac Mouse Fix.xcloc";
    
    NSString *xliffPath;
    for (NSString *p in [[NSFileManager defaultManager] enumeratorAtPath: xclocPath])
        if ([p hasSuffix: @".xliff"]) {
            xliffPath = [xclocPath stringByAppendingPathComponent: p];
            break;
        } /// We always expect there to be only one .xliff in the .xcloc

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
