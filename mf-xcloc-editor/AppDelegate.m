//
//  AppDelegate.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuItemValidation>

@end

//
//  AppDelegate.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

@implementation AppDelegate

    {
        bool _filterOptions_Regex;
        bool _filterOptions_CaseSensitive;
    }

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
        #define ret(res) ({ result = (res); goto end; })
        #define isaction(sel) (menuItem.action == @selector(sel))
        
        {
            auto doc = getdoc_frontmost(); /// Careful: When no doc is open, `doc->someIvar` calls crash.  (When no doc is open, NSOpenPanel opens) [Oct 2025]
        
            if (isaction(quickLookMenuItemSelected:))
                ret(!!doc);
            
            if (isaction(filterMenuItemSelected:))
                ret(!!doc);
            if (isaction(caseSensitiveMenuItemSelected:)) {
                menuItem.state = self->_filterOptions_CaseSensitive;
                ret(!!doc);
            }
            if (isaction(regexMenuItemSelected:)) {
                menuItem.image = ({ /// Custom-draw `.*` icon for the regex menuItem. (SF Symbols doesn't offer that) [Dec 2025].
                    auto text = [[NSAttributedString alloc]
                        initWithString: @".*"
                        attributes: @{
                            NSFontAttributeName: [NSFont systemFontOfSize: 13 weight: NSFontWeightSemibold],
                            NSForegroundColorAttributeName: [NSColor labelColor],
                        }
                    ];
                    auto img = [NSImage imageWithSize: text.size flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
                        [text drawInRect: dstRect];
                        return YES;
                    }];
                    img.template = YES;
                    img;
                });
                menuItem.state = self->_filterOptions_Regex; /// Prevents macOS state restoration from wrongly initing the items's state (I think) [Dec 2025]
                ret(!!doc);
            }
            
            if (isaction(markAsTranslatedMenuItemSelected:)) {
                
                TableView *tableView = !doc?nil: doc->ctrl->out_tableView;
                
                if ([menuItem.identifier isEqual: @"mark_for_review"]) {
                    menuItem.title = kMFStr_MarkForReview;
                    menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkForReview_Symbol accessibilityDescription: nil];
                }
                else {
                    menuItem.title = kMFStr_MarkAsTranslated;
                    menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: nil];
                }
                
                if (
                    ![(id)[tableView.window firstResponder] respondsToSelector: @selector(isDescendantOf:)] ||                          /// [Dec 2025] Pretty sure I saw a crash that this should prevent.
                    ![(id)[tableView.window firstResponder] isDescendantOf: tableView]
                )                                                                                                                      ret (NO); /// Ignore input when tableView is not firstResponder to prevent accidental input [Oct 2025] || isDescendantOf: is necessary when editing an NSTextField.
                if (![tableView selectedItem])                                                                                         ret (NO);
                if (rowModel_isPluralParent([tableView selectedItem]))                                                                 ret (NO);
                if ([tableView  rowIsTranslated: [tableView selectedItem]] && [menuItem.identifier isEqual: @"mark_for_review"])       ret (YES);
                if (![tableView rowIsTranslated: [tableView selectedItem]] && [menuItem.identifier isEqual: @"mark_as_translated"])    ret (YES);
                ret (NO);
                
            }
            if (isaction(showInFilenameMenuItemSelected:)) {
                
                TableView *tableView = !doc?nil: doc->ctrl->out_tableView;;
                
                if ([menuItem.identifier isEqual: @"show_in_all"]) {
                    if (![tableView selectedItem]) {
                        menuItem.title = kMFStr_GoToAll; /// IIRC we decided for this two-item approach to make things searchable or something? Changing the `kMFStr_` here might defeat the purpose? But eh it works fine [Dec 2025]
                        menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_GoToAll_Symbol accessibilityDescription: kMFStr_GoToAll];
                    }
                    else {
                        menuItem.title = kMFStr_RevealInAll;
                        menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_RevealInAll_Symbol accessibilityDescription: kMFStr_RevealInAll];
                    }
                }
                else {
                    menuItem.title = kMFStr_RevealInFile(doc, [tableView selectedItem]);
                    menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_RevealInFile_Symbol accessibilityDescription: kMFStr_RevealInFile(doc, [tableView selectedItem])];
                }
                if (!doc)                                                                                             ret (NO);
                if (![doc->ctrl->out_sourceList allTransUnitsShown] && [menuItem.identifier isEqual: @"show_in_all"]) ret (YES);
                if (![tableView selectedItem])                                                                        ret (NO);
                if ([doc->ctrl->out_sourceList allTransUnitsShown] && [menuItem.identifier isEqual: @"show_in_file"]) ret (YES);
                ret (NO);
            }
            
            ret([super validateMenuItem: menuItem]);
        }
            
        end: {}
        #undef ret
        #undef isaction
        
        mflog(@"validateMenuItem: %d", result);
        
        return result;
    }

    - (IBAction) filterMenuItemSelected: (id)sender {
        [getdoc_frontmost()->ctrl->out_filterField.window makeFirstResponder: getdoc_frontmost()->ctrl->out_filterField];
    }
    
    - (IBAction)regexMenuItemSelected: (NSMenuItem *)sender         { sender.state = !sender.state; self->_filterOptions_Regex         = sender.state; [self updateFilterStuff: nil]; }
    - (IBAction)caseSensitiveMenuItemSelected: (NSMenuItem *)sender { sender.state = !sender.state; self->_filterOptions_CaseSensitive = sender.state; [self updateFilterStuff: nil]; }

    - (void) updateFilterStuff: (TableView *)tableView {
        
        mflog(@"regex: %d, case: %d", self->_filterOptions_Regex, self->_filterOptions_CaseSensitive);
        
        NSStringCompareOptions options = 0;
        if (!self->_filterOptions_CaseSensitive)  options |= NSCaseInsensitiveSearch;
        if (self ->_filterOptions_Regex)          options |= NSRegularExpressionSearch;
    
        if (tableView) /// Necessary because we're calling this in (TableView.m -init), before the tableView is available via `getdoc_alldocs()`. Very hacky. Could use KVO instead. [Dec 2025]
            [tableView updateFilterOptions: options];
        else
            for (XclocDocument *doc in getdoc_alldocs())
                [doc->ctrl->out_tableView updateFilterOptions: options];
    }

    - (IBAction) quickLookMenuItemSelected: (id)sender {
        [getdoc_frontmost()->ctrl->out_tableView togglePreviewPanel: sender];
    }

    - (IBAction) markAsTranslatedMenuItemSelected: (id)sender {
        auto tableView = getdoc_frontmost()->ctrl->out_tableView;
        [tableView toggleIsTranslatedState: [tableView selectedItem]];
    }
    - (IBAction) showInFilenameMenuItemSelected: (id)sender {
        
        XclocDocument *doc = getdoc_frontmost();
        
        auto transUnit = [doc->ctrl->out_tableView selectedItem];
    
        if ([doc->ctrl->out_sourceList allTransUnitsShown]) {
            [doc->ctrl->out_sourceList showFileOfTransUnit: transUnit];
        } else {
            [doc->ctrl->out_sourceList showAllTransUnits];
        }
    
    }


@end
