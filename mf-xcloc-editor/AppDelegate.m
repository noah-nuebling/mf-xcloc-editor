//
//  AppDelegate.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import "AppDelegate.h"
#import "Utility.h"

@implementation AppDelegate

#pragma mark - Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    ({
        NSString *path = @"/Users/Noah/Downloads/Mac Mouse Fix Translations (German) 3/Mac Mouse Fix.xcloc/Localized Contents/de.xliff";
        NSError *err = nil;
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: path] options: NSXMLNodeOptionsNone error: &err];
        if (err) fail(end, @"Loading XMLDocument from path '%@' failed with error: '%@'", path, err);
        
        self.sourceList.xliffDoc = doc;
        [self.sourceList reloadData];
    });
    
    end:
        {}
        
    
}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

@end
