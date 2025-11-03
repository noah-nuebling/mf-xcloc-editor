//
//  AppDelegate.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "XclocWindowController.h"
#import "XclocDocumentController.h"
#import "Constants.h"
#import "XclocDocument.h"
#import "RowUtils.h"
#import "MFUI.h"


@implementation AppDelegate

#pragma mark - Lifecycle

    - (instancetype)init
    {
        self = [super init];
        if (self) {
            /// Register custom documentController (Src: https://stackoverflow.com/a/7373892)
            [XclocDocumentController new];
        }
        return self;
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

    - (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
        
        if ((0)) { /// TESTING
        
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

    - (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)sender {
        
        /// Close all windows
        ///     (Otherwise our `windowWillClose:` callbacks aren't called. See https://stackoverflow.com/q/2997571.
        ///         Update: Shouldn't be necessary anymore since `windowWillClose:` was only used to restore window frames which is now handled by restorable state stuff (See `XclocDocumentController` and `setFrameUsingName: @"TheeeEditor"`)
        for (NSWindow *w in [NSApp windows])
            [w close];
        
        return NSTerminateNow;
    }

#pragma mark - Config
    
    - (BOOL) applicationSupportsSecureRestorableState: (NSApplication *)app           { return YES; }
    - (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender { return NO; } /// Document-based apps don't usually do this on macOS I think [Oct 2025]
    
    - (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)sender               {
        mflog(@"applicationShouldOpenUntitledFile:");
        return YES;
    }
    - (BOOL) applicationOpenUntitledFile:(NSApplication *)sender {
        
        /// This is called when the app is opened or 'reopened' with no windows visible. See docs of `applicationShouldHandleReopen:hasVisibleWindows:`
        /// Default impl calls `[NSDocumentController openUntitledDocumentAndDisplay:]`
        
        {
            [NSDocumentController.sharedDocumentController openDocument: self];
            return YES;
        }
        
        if ((0)) {
            NSArray<NSString *> *xclocPaths = @[];
            if ((0)) {
                NSString *xclocPath;
                if ((0)) xclocPath = @"/Users/noah/mmf-stuff/xcode-localization-screenshot-fix/CustomImplForLocalizationScreenshotTest/Notes/Examples/example-da.xcloc";
                if ((0)) xclocPath = @"/Users/noah/mmf-stuff/mf-xcloc-editor/mf-xcloc-editor/example-docs/da.xcloc";
                else     xclocPath = @"/Users/noah/Downloads/Mac Mouse Fix Translations (German)/Mac Mouse Fix.xcloc";
                xclocPaths = @[xclocPath];
            }
        
            return YES;
        }
    
    }
    

#pragma mark - MenuItems

    - (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
        
        BOOL result = NO;
        #define ret(res) { result = (res); goto end; }
        
        auto doc = getdoc_frontmost();
        if (!doc) ret(NO);    /// When no doc is open, none of these menu-items apply, also the `getdoc_frontmost()->someIvar` calls would crash.  (When no doc is open, NSOpenPanel opens) [Oct 2025]
        
        if (menuItem.action == @selector(filterMenuItemSelected:)) {
            ret(YES);
        }
        else if (menuItem.action == @selector(quickLookMenuItemSelected:)) {
            ret(YES);
        }
        else if (menuItem.action == @selector(markAsTranslatedMenuItemSelected:)) {
            
            TableView *tableView = doc->ctrl->out_tableView;
            
            if (![(id)[tableView.window firstResponder] isDescendantOf: tableView]) { /// Ignore input when tableView is not firstResponder to prevent accidental input [Oct 2025] || isDescendantOf: is necessary when editing an NSTextField.
                ret(NO);
            }
            
            NSXMLElement *selectedTransUnit = [tableView selectedItem];
            if (
                selectedTransUnit == nil ||
                rowModel_isPluralParent(selectedTransUnit) /// Pluralizable string is selected
            ) {
                menuItem.title = kMFStr_MarkAsTranslated; /// Setting the image/title here as well so they are not 'unitialized' raw values from the IB. [Oct 2025]
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: nil];
                ret(NO);
            }
            else if ([tableView rowIsTranslated: selectedTransUnit]) {
                menuItem.title = kMFStr_MarkForReview;
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkForReview_Symbol accessibilityDescription: nil];
                ret(YES);
            }
            else {
                menuItem.title = kMFStr_MarkAsTranslated;
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: nil];
                ret(YES);
            }
        
            ret(YES);
        }
        else
            ret([super validateMenuItem: menuItem]);
            
        end: {}
        #undef ret
        
        mflog(@"validateMenuItem: %d", result);
        
        return result;
    }

    - (IBAction) filterMenuItemSelected: (id)sender {
        [getdoc_frontmost()->ctrl->out_filterField.window makeFirstResponder: getdoc_frontmost()->ctrl->out_filterField];
    }

    - (IBAction) quickLookMenuItemSelected: (id)sender {
        [getdoc_frontmost()->ctrl->out_tableView togglePreviewPanel: sender];
    }

    - (IBAction) markAsTranslatedMenuItemSelected: (id)sender {
        auto tableView = getdoc_frontmost()->ctrl->out_tableView;
        [tableView toggleIsTranslatedState: [tableView selectedItem]];
    }


@end
