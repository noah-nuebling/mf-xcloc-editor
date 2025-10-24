//
//  AppDelegate.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "MainWindowController.h"
#import "Constants.h"
#import "XclocDocument.h"

@implementation AppDelegate

#pragma mark - Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    if ((1)) { /// TESTING
    
        NSString *xclocPath;
        if ((0)) xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
        if ((0)) xclocPath = @"/Users/noah/mmf-stuff/mf-xcloc-editor/mf-xcloc-editor/example-docs/da.xcloc";
        else     xclocPath = @"/Users/noah/Downloads/Mac Mouse Fix Translations (German)/Mac Mouse Fix.xcloc";
    
        [NSDocumentController.sharedDocumentController
            openDocumentWithContentsOfURL: [NSURL fileURLWithPath: xclocPath]
            display: YES
            completionHandler: ^void (NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                mflog(@"Open document result: %@ | %@ | %@", document, @(documentWasAlreadyOpen), error);
            }
        ];
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

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
    
    /// TODO: Maybe delete some of the default menuItems we don't need.
    /// TODO: Make kMFStr_MarkAsTranslated item grayed out when pluralizable string is selected.
    
    if (menuItem.action == @selector(filterMenuItemSelected:)) {
        return YES;
    }
    else if (menuItem.action == @selector(quickLookMenuItemSelected:)) {
        return YES;
    }
    else if (menuItem.action == @selector(markAsTranslatedMenuItemSelected:)) {
        
        NSXMLElement *selectedRow = [getdoc_frontmost()->ctrl->out_tableView selectedRowModel];
        if (selectedRow == nil) {
            menuItem.title = kMFStr_MarkAsTranslated; /// Setting the image/title here as well so they are not 'unitialized' raw values from the IB. [Oct 2025]
            menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: nil];
            return NO;
        }
        else if ([getdoc_frontmost()->ctrl->out_tableView rowIsTranslated: selectedRow]) {
            menuItem.title = kMFStr_MarkForReview;
            menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkForReview_Symbol accessibilityDescription: nil];
            return YES;
        }
        else {
            menuItem.title = kMFStr_MarkAsTranslated;
            menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: nil];
            return YES;
        }
    
        return YES;
    }
    else
        return [super validateMenuItem: menuItem];
}

- (IBAction) filterMenuItemSelected: (id)sender {
    [getdoc_frontmost()->ctrl->out_filterField.window makeFirstResponder: getdoc_frontmost()->ctrl->out_filterField];
}

- (IBAction) quickLookMenuItemSelected: (id)sender {
    [getdoc_frontmost()->ctrl->out_tableView togglePreviewPanel: sender];
}

- (IBAction) markAsTranslatedMenuItemSelected: (id)sender {
    auto tableView = getdoc_frontmost()->ctrl->out_tableView;
    [tableView toggleIsTranslatedState: [tableView selectedRowModel]];
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
