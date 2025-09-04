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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    {
        self->mainController = [MainWindowController new];
        Outlets outlets = [self->mainController makeMainWindow];
        
        self->tableView = outlets.tableView;
        self->sourceList = outlets.sourceList;
        
        NSString *xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
        #define getXliffPath(xclocPath, locale) [xclocPath stringByAppendingPathComponent: stringf(@"Localized Contents/%@.xliff", (locale))];
        NSString *xliffPath = getXliffPath(xclocPath, @"da")
        
        NSError *err = nil;
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: xliffPath] options: NSXMLNodeOptionsNone error: &err];
        if (err) fail(end, @"Loading XMLDocument from path '%@' failed with error: '%@'", xliffPath, err);

        self->sourceList.xliffDoc = doc;
        [self->sourceList reloadData];
    };
    
    end:
        {}
    
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

@end
