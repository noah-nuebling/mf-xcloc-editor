//
//  TableView.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

///
/// See:
///     https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TableView/PopulatingView-TablesProgrammatically/PopulatingView-TablesProgrammatically.html#//apple_ref/doc/uid/10000026i-CH14-SW1
///

#import "TableView.h"
#import "Utility.h"
#import "NSObject+Additions.h"
#import "AppDelegate.h"
#import "MFQLPreviewItem.h"
#import "Constants.h"
#import "XclocDocument.h"
#import "RowUtils.h"
#import "MFTextField.h"

@implementation TableView
    {
        NSString *_filterString;
        NSMutableArray<NSXMLElement *> *_displayedTransUnits; /// Main dataModel displayed by this table.
        id _lastQLPanelDisplayState;
    }

    #pragma mark - Lifecycle

    - (instancetype) initWithFrame: (NSRect)frame {
        
        self = [super initWithFrame: frame];
        if (!self) return nil;
        
        self.delegate   = self; /// [Jun 2025] Will this lead to retain cycles or other problems?
        self.dataSource = self;
        
        /// Configure style
        self.gridStyleMask = /*NSTableViewSolidVerticalGridLineMask |*/ NSTableViewSolidHorizontalGridLineMask;
        self.style = NSTableViewStyleFullWidth;
        self.usesAutomaticRowHeights = YES;
        
        /// Register ReusableViews
        ///     Not sure this is necesssary / correct. What about `theReusableCell_TableState` [Oct 2025]
        [self registerNib: [[NSNib alloc] initWithNibNamed: @"ReusableViews" bundle: nil]  forIdentifier: @"theReusableCell_Table"];
        
        /// Add columns
        {
            auto mfui_tablecol = ^NSTableColumn *(NSString *identifier, NSString *title) {
                auto v = [[NSTableColumn alloc] initWithIdentifier: identifier];
                [v setSortDescriptorPrototype: [NSSortDescriptor sortDescriptorWithKey: v.identifier ascending: YES]];
                v.title = title;
                return v;
            };
            [self addTableColumn: mfui_tablecol(@"id",     @"ID")];
            [self addTableColumn: mfui_tablecol(@"state",  @"State")];
            [self addTableColumn: mfui_tablecol(@"source", @"Source")];
            [self addTableColumn: mfui_tablecol(@"target", @"Target")];
            [self addTableColumn: mfui_tablecol(@"note",   @"Note")];
        }
        
        /// Add right-click menu
        {
            auto mfui_menu = ^NSMenu * (NSArray<NSMenuItem *> *items) {
                auto v = [NSMenu new];
                for (id item in items) [v addItem: item];
                return v;
            };
            auto mfui_item = ^NSMenuItem *(NSString *identifier, NSString *symbolName, NSString *title) {
                auto v = [NSMenuItem new];
                v.identifier = identifier;
                v.title = title;
                v.image = [NSImage imageWithSystemSymbolName: symbolName accessibilityDescription: nil];
                v.action = @selector(tableMenuItemClicked:);
                v.target = self;
                return v;
            };
            
            self.menu = mfui_menu(@[
                mfui_item(@"mark_as_translated", kMFStr_MarkAsTranslated_Symbol, kMFStr_MarkAsTranslated), /// validateMenuItem: in AppDelegate.m [Oct 2025]
                mfui_item(@"mark_for_review",    kMFStr_MarkForReview_Symbol, kMFStr_MarkForReview),
            ]);
        }
        
        
        /// Return
        return self;
    }
    
    #pragma mark - Keyboard control
    
        - (void) returnFocus {
            
            /// After another UIElement has had keyboardFocus, it can use this method to give it back to the `TableView`
            
            [self.window makeFirstResponder: self];
            if (self.selectedRow == -1) {
                NSInteger row = [self rowAtPoint: NSMakePoint(0, self.visibleRect.origin.y + self.headerView.frame.size.height)]; /// Get first displayed row on screen. || On `self.headerView` usage: Currently seeing `self.visibleRect.origin.y` be `-28`. The visibleRect is 28 taller than the frame. `self.headerView` is 28 tall, so we're using that to compensate[Oct 2025]
                [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
            }
            
            [self scrollRowToVisible: self.selectedRow];
            
        }
    
        - (void) keyDown: (NSEvent *)theEvent {
            
            if (
                (0) && /// Disable keyboard controls for previewItems, cause it's not that useful and currently produces a bit of weird behavior (I think. Can't remember what [Oct 2025])
                QLPreviewPanel.sharedPreviewPanel.visible
            ) {
                if (eventIsKey(theEvent, NSLeftArrowFunctionKey)) /// Flip through different screenshots containing the currently selected string. Could also implement this in `previewPanel:handleEvent:` [Oct 2025]
                    [self _incrementCurrentPreviewItem: -1];
                else if (eventIsKey(theEvent, NSRightArrowFunctionKey))
                    [self _incrementCurrentPreviewItem: +1];
                else
                    [super keyDown: theEvent];
            }
            else {
                if (eventIsKey(theEvent, NSLeftArrowFunctionKey))   /// Select the sourceList
                    [getdoc(self)->ctrl->out_sourceList.window makeFirstResponder: getdoc(self)->ctrl->out_sourceList];
                else if (eventIsKey(theEvent, ' '))	/// Space key opens the preview panel. || TODO: Also support Command-Y (using Menu Item)
                    [self togglePreviewPanel: self];
                else
                    [super keyDown: theEvent]; /// Handling of UpArrow and DownArrow is built-in to `NSTableView` [Oct 2025]
            }
        }
        - (void) cancelOperation: (id)sender {
            
            if ([[self.window firstResponder] isKindOfClass: [NSTextView class]]) { /// If the user is editing a translation, cancel editing
                [super cancelOperation: sender];
                return;
            }
            
            [getdoc(self)->ctrl->out_sourceList.window makeFirstResponder: getdoc(self)->ctrl->out_sourceList]; /// Return focus to sidebar when user hits escape while editing transUnits. Also see other `cancelOperation:` overrides. [Oct 2025]
        }
    
        - (BOOL) control: (NSControl*)control textView: (NSTextView*)textView doCommandBySelector: (SEL)commandSelector {
            
            BOOL didHandle = NO;
         
            if (isclass(control, MFTextField)) {
                
                /// Let users enter newlines in the `@"target"` cells' (without holding Option – which may not be discoverable)
                ///     Src: https://developer.apple.com/library/archive/qa/qa1454/_index.html
                ///     Implementing this in TableView cause TableView is the delegate of `MFTextField`. Not sure if that's good. [Oct 2025]
                ///     Idea: Could also instead add shift-return for newline to make it more discoverable for LLM users.
                
                {
                    if (commandSelector == @selector(insertNewline:)) { /// Map Return -> newline
                        [textView insertNewlineIgnoringFieldEditor: self];
                        didHandle = YES;
                    }
                    else if (commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) { /// Map Option-Return -> end-editing (So we can still navigate everything with the keyboard)
                        [textView insertNewline: self];
                        didHandle = YES;
                    }
                }
                
                /// Let users enter tabs (without holding Option)
                ///     Not actually sure this is a good idea? (If I used indentation in any MMF UIStrings, I mustve used spaces not tabs) [Oct 2025]
                if ((1))
                {
                    if (commandSelector == @selector(insertTab:)) {
                        [textView insertTabIgnoringFieldEditor: self];
                        didHandle = YES;
                    }
                }
            }
         
            return didHandle;
        }
    
    #pragma mark - Sorting
    
    - (void) tableView: (NSTableView *)tableView sortDescriptorsDidChange: (NSArray<NSSortDescriptor *> *)oldDescriptors { /// This is called when the user clicks the column headers to sort them.
        
        auto previouslySelectedRowID = rowModel_getCellModel([self rowModel: [self selectedRow]], @"id");
        
        [self update_rowModelSorting];
        [self reloadData];
        
        [self restoreSelectionWithPreviouslySelectedRowID: previouslySelectedRowID];
    }

    #pragma mark - Filtering
    - (void) updateFilter: (NSString *)filterString {
        
        _filterString = filterString;
        [self bigUpdateAndStuff];
    }

    #pragma mark - Data
    
    
    - (NSXMLElement *) selectedRowModel {
        return [self rowModel: self.selectedRow];
    }
    
    - (NSXMLElement *) rowModel: (NSInteger)row {
        if (row == -1) return nil; /// `self.selectedRow` can return -1 if no row is selected
        return _displayedTransUnits[row];
    }

    - (void) update_rowModels {
        
        /// Filter
        _displayedTransUnits = [NSMutableArray new];
        for (NSXMLElement *transUnit in self.transUnits) {
            
            
            { /// Validate
                assert(isclass(transUnit, NSXMLElement));
                assert([transUnit.name isEqual: @"trans-unit"]);
            }
            
            if (![_filterString length]) { [_displayedTransUnits addObject: transUnit]; }
            else {
                auto combinedRowString = stringf(@"%@\n%@\n%@\n%@\n%@",
                    rowModel_getCellModel(transUnit, @"id"),
                    rowModel_getCellModel(transUnit, @"source"),
                    rowModel_getCellModel(transUnit, @"target"),
                    rowModel_getCellModel(transUnit, @"note"),
                    rowModel_getCellModel(transUnit, @"state")
                );
                if (
                    [combinedRowString /// Fixme: search actual UIStrings instead of cellModel strings.
                        rangeOfString: _filterString
                        options: (/*NSRegularExpressionSearch |*/ NSCaseInsensitiveSearch)
                    ]
                    .location != NSNotFound
                ) {
                    [(NSMutableArray *)_displayedTransUnits addObject: transUnit];
                }
            }
        }
        
        /// Sort
        [self update_rowModelSorting];
    }
    
    - (void) update_rowModelSorting {
    
        mflog(@"Updating _rowToSortedRow with sortDescriptors: (only using the first one): %@", self.sortDescriptors);
        
        NSSortDescriptor *desc = self.sortDescriptors.firstObject;
        if (!desc) { return; }
        
        if ((0)) {
            NSInteger rowCount = [self numberOfRowsInTableView: self]; /// -[numberOfRows] gives wrong results while swtiching files not sure what's going on [Oct 2025]
        }
        
        [_displayedTransUnits sortUsingComparator: ^NSComparisonResult(NSXMLElement *i, NSXMLElement *j) {
            NSComparisonResult comp;
            if ([desc.key isEqual: @"state"]) {
                comp = (
                    [_stateOrder indexOfObject: rowModel_getCellModel(i, @"state")] -
                    [_stateOrder indexOfObject: rowModel_getCellModel(j, @"state")]
                );
            }
            else {
                comp = [
                    rowModel_getCellModel(i, desc.key) compare:
                    rowModel_getCellModel(j, desc.key)
                ];
            }
            return desc.ascending ? comp : -comp;
        }];
    }


- (void) restoreSelectionWithPreviouslySelectedRowID: (NSString *)previouslySelectedRowID {
    /// Restore the selection after reloadData resets it.
    NSInteger newIndex = -1;
    NSInteger i = 0;
    for (NSXMLElement *transUnit in _displayedTransUnits) {
        if ([rowModel_getCellModel(transUnit, @"id") isEqual: previouslySelectedRowID]) {
            newIndex = i;
            break;
        }
        i++;
    }
    if (newIndex != -1) {
        [self selectRowIndexes: [NSIndexSet indexSetWithIndex: newIndex] byExtendingSelection: NO];
        [self scrollRowToVisible: newIndex]; /// Tried to do a better job of keeping the row in the same position than `scrollRowToVisible:` but can't get it to work. Coordinates flip and `rectOfRow:` result seems inconsistent. [Oct 2025] || ... update: This still fails sometimes, though rarely. Maybe the APIs are broken? How do they even know how tall all the rows are?
    }
}

- (void) bigUpdateAndStuff {
        
        /// Fully update the table with new rows, but try to preserve the selection.
        ///     Not sure this is a good abstraction to have, I don't really understand it [Oct 2025]
        
        auto previouslySelectedRowID = rowModel_getCellModel([self rowModel: [self selectedRow]], @"id");
        
        [self update_rowModels];;
        [self reloadData];
        
        [self restoreSelectionWithPreviouslySelectedRowID: previouslySelectedRowID];
    }

    - (void) reloadWithNewData: (NSArray <NSXMLElement *> *)transUnits {
        
        self->_transUnits = transUnits;
        [self bigUpdateAndStuff];

    }
    
    #pragma mark - Quick Look
    
        /// See Apple `QuickLookDownloader` sample project: https://developer.apple.com/library/archive/samplecode/QuickLookDownloader/Introduction/Intro.html
    
        - (NSDictionary *_Nullable) _localizedStringsDataPlist_GetEntryForRowModel: (NSXMLElement *)transUnit {
            
            /**
                Example `localizedStringsDataPlist.plist` entry from `Mac Mouse Fix.xloc`:
                ```
                {
                    bundleID = "some.id";
                    bundlePath = "some/path";
                    screenshots =         (
                                    {
                            frame = "{{168, 734}, {585, 36}}";
                            name = "3. Copy - ButtonsTab State 0.jpeg";
                        },
                                    {
                            frame = "{{168, 1006}, {585, 36}}";
                            name = "13. Copy - ButtonsTab State 0.jpeg";
                        },
                                    {
                            frame = "{{168, 734}, {585, 36}}";
                            name = "3. Copy - ButtonsTab State 1.jpeg";
                        }
                    );
                    stringKey = "trigger.substring.click.1";
                    tableName = Localizable;
                },
                ```
            */
            
            NSDictionary *matchingPlistEntry = nil;
            for (NSDictionary *entry in getdoc(self).localizedStringsDataPlist) {
                if ([entry[@"stringKey"] isEqual: rowModel_getCellModel(transUnit, @"id")]) {
                    if (matchingPlistEntry) assert(false); /// Multiple entries for this key
                    matchingPlistEntry = entry;
                }
            }
            if ((0)) assert([matchingPlistEntry[@"tableName"] isEqual: rowModel_getCellModel(transUnit, @"fileName")]); /// Our `rowModel` doesn't actually have a `@"fileName"`, but if it did, this should be true. [Oct 2025]
            
            return matchingPlistEntry;
        };
        
        - (IBAction) quickLookButtonPressed: (id)quickLookButton {
            NSInteger row = [[quickLookButton mf_associatedObjectForKey: @"rowOfQuickLookButton"] integerValue];
            
            if (self.selectedRow == row) {
                [self togglePreviewPanel: nil];
            }
            else {
                [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
                [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: nil];
            }
        }
        
        - (IBAction)togglePreviewPanel:(id)previewPanel {
            if (
                [QLPreviewPanel sharedPreviewPanelExists] &&
                [[QLPreviewPanel sharedPreviewPanel] isVisible]
            ) {
                [[QLPreviewPanel sharedPreviewPanel] orderOut: nil];
            }
            else {
                [self returnFocus];
                [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: nil];
            }
        }
        
        - (void) _incrementCurrentPreviewItem: (int)increment {
            
            NSInteger newIndex;
            { /// Increment the index and then bring it back into the valid range. In MMF and elsewhere we have a utility function for this called something like 'cycle'.
                newIndex = (QLPreviewPanel.sharedPreviewPanel.currentPreviewItemIndex + increment);
                NSInteger stride = [self numberOfPreviewItemsInPreviewPanel: nil];
                if (!stride) newIndex = 0; /// Not sure what this should be – -1? [Oct 2025]`
                else {
                    while (newIndex < 0)        newIndex += stride;
                    while (newIndex >= stride)  newIndex -= stride;
                }
            }
        
            QLPreviewPanel.sharedPreviewPanel.currentPreviewItemIndex = newIndex;
        }
        - (void)tableViewSelectionDidChange:(NSNotification *)notification {
            [QLPreviewPanel.sharedPreviewPanel reloadData];
        }
        
        #pragma mark QLPreviewPanelController
        
            /// These are from an NSObject category not a protocol. Not mentioned in any docs. All hail the lord Claude 4.5.
            
            - (BOOL) acceptsPreviewPanelControl: (QLPreviewPanel *)panel {
                return YES;
            }
            - (void) beginPreviewPanelControl: (QLPreviewPanel *)panel {
                [panel setDelegate: self];
                [panel setDataSource: self];
                /// Restore displayState
                ///     Problem: QuickLook panel is comically big and when you close and reopen it, it looses its previous size [Oct 2025]
                ///     Solution ideas:
                ///         - `[panel displayState]` sounds like its made for restoring size but is always nil [Oct 2025]
                ///             (The `<QLPreviewItem>`s also have displayState I haven't looked into that.
                ///         - We can override frame in `windowDidBecomeKey:` but then the QLPreviewPanel overrides it back once the content is fully loaded it seems
                ///         - Did some digging and looks like `-[QLPreviewPanelController adjustedPanelFrame:ignoringCurrentFrame:]` is the thing determining the size.
                ///             -> We could swizzle it, but that's too crazy [Oct 2025]
                ///         - Sidenote: While digging I found `"QLPreviewKeepConstantWidth"` (`CFPreferences` app value). I tried to set it in hopes of it making it keep the width we set in `windowDidBecomeKey:` but it didn't work. Not sure I was doing it right.
                if (_lastQLPanelDisplayState) [panel setDisplayState: _lastQLPanelDisplayState];
                return;
            }
            - (void) endPreviewPanelControl: (QLPreviewPanel *)panel {
                _lastQLPanelDisplayState = [panel displayState]; /// This is always nil. || TODO: Make QLPanel window default sizes better & implement size restoration
                return;
            }

        #pragma mark QLPreviewPanelDelegate
        
            - (NSRect) previewPanel: (QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem: (id <QLPreviewItem>)item {
                
                
                NSRect sourceFrame_Window = {};
                
                if ((0))
                {
                    NSRect colRect = [self rectOfColumn: [self columnWithIdentifier: @"id"]];
                    NSRect rowRect = [self rectOfRow: [self selectedRow]];
                    NSRect sourceRect = NSIntersectionRect(colRect, rowRect);
                    sourceFrame_Window = [self convertRect: sourceRect toView: nil];
                }
                else {
                    NSTableCellView *cellView = [self viewAtColumn: [self columnWithIdentifier: @"id"] row: [self selectedRow] makeIfNecessary: NO];
                    NSButton *quickLookButton = firstmatch(cellView.subviews, cellView.subviews.count, nil, sv, [sv.identifier isEqual: @"quick-look-button"]); /// We previously used `[cell nextKeyView];`. I thought it worked but here it didn't [Oct 2025]
                    sourceFrame_Window = [quickLookButton.superview convertRect: quickLookButton.frame toView: nil];
                }
                
                NSRect sourceFrame_Screen = [self.window convertRectToScreen: sourceFrame_Window];
                
                return sourceFrame_Screen;
            }
            
            - (id) previewPanel: (QLPreviewPanel *)panel transitionImageForPreviewItem: (id<QLPreviewItem>)item contentRect: (NSRect *)contentRect {
                
                if ((0)) /// Setting eye doesn't really show an eye, but it makes the panel fade out during the transition
                    return [NSImage imageWithSystemSymbolName: @"eye" accessibilityDescription: nil];
                else if ((1))
                    return [[NSImage alloc] initWithSize: NSMakeSize(10, 10)]; /// Use empty image in hopes of getting a faster fade-out like finder, but it looks the same as using @"eye"
                else
                    return nil;
            }
            
            - (BOOL) previewPanel: (QLPreviewPanel *)panel handleEvent: (NSEvent *)event {
                /// redirect all key down events from the QLPanel to the table view (So you can flip through rows) [Oct 2025]
                if ([event type] == NSEventTypeKeyDown) {
                    if (!eventIsKey(event, NSUpArrowFunctionKey) && !eventIsKey(event, NSDownArrowFunctionKey)) /// We disable it for NSUpArrowFunctionKey and NSDownArrowFunctionKey cause the blue row highlight is a little distracting
                        [self.window makeKeyAndOrderFront: nil]; /// Without this, the `filterField` (Command-F) and "Switch between `SourceList` and `TableView`" (LeftArrow / RightArrow) keys don't work properly. [Oct 2025]
                    [self keyDown: event];
                    return YES;
                }
                return NO;
            }
        

        #pragma mark QLPreviewPanelDataSource

            - (NSInteger) numberOfPreviewItemsInPreviewPanel: (QLPreviewPanel *)panel {
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self rowModel: self.selectedRow]];
                return [plistEntry[@"screenshots"] count];
            };

            - (id <QLPreviewItem>) previewPanel: (QLPreviewPanel *)panel previewItemAtIndex: (NSInteger)index {
                
                mflog(@"previewItemAtIndex: called with index: %ld", index);
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self rowModel: self.selectedRow]];
                NSDictionary *screenshotEntry = plistEntry[@"screenshots"][index];
                
                NSRect frame = NSRectFromString(screenshotEntry[@"frame"]);
                NSString *name = screenshotEntry[@"name"];
                
                NSString *imagePath = findPaths([stringf(@"%@%@", [getdoc(self).fileURL path], @"/Notes/Screenshots/") stringByStandardizingPath], ^BOOL(NSString *path) {
                    return [[path lastPathComponent] isEqual: name];
                })[0];
                
                auto image = [[NSImage alloc] initWithContentsOfFile: imagePath];
                
                auto annotatedImage = [NSImage imageWithSize: image.size flipped: YES drawingHandler: ^BOOL(NSRect dstRect) {
                    
                    [image drawInRect: dstRect]; /// This line is slow
                    
                    [NSColor.systemRedColor setStroke];
                    
                    auto path = [NSBezierPath bezierPathWithRect: frame];
                    [path setLineWidth: 3.0];
                    [path stroke];

                    return YES;
                }];
                
                /// Get `annotatedImagePath`
                ///     We have to write the annotated image to a file to get the QLPreviewPanel to load it.
                ///         Xcode's xcloc editor circumvents this somehow (But it's also buggy and doesn't update the annotations correctly)
                ///         If the `annotatedImagePath` is a unique identifier for the annotated image, we could use it to cache the annotatedImage. [Oct 2025]
                
                auto annotatedImagePath = [[[[NSFileManager defaultManager] temporaryDirectory] path] stringByAppendingPathComponent: stringf(@"%@%@%@%@%@%@",
                    @"/mf-xcloc-editor/annotated-screenshots/",
                    [[imagePath lastPathComponent] stringByDeletingPathExtension],
                    @" --- ",
                    NSStringFromRect(frame),
                    @".",
                    [imagePath pathExtension]
                )];
                
                /// Check if annotatedImage already exists
                /// This is how we cache. Makes things noticably more responsive. `-[NSImage drawInRect:]` is apparently reallyyyy slow. (Cache shaves off like half a second on my M1 MBA on a single run – which seems strange) [Oct 2025]
                ///     Idea: Claude suggests this may be because the image is compressed? We did choose compressed jpegs to reduce file size IIRC, due to the Xcode bug that forced us to duplicate the images. Compression may no longer be beneficial when switching from Xcode -> mf-xcloc editor. [Oct 2025]
                if ([[NSFileManager defaultManager] fileExistsAtPath: annotatedImagePath]) {
                    mflog(@"Using cached annotatedImage file at: %@", annotatedImagePath);
                }
                else {
                    mflog(@"Creating new annotatedImage file at: %@", annotatedImagePath);
                
                    /// Make parent dirs
                    NSError *err = nil;
                    [[NSFileManager defaultManager] createDirectoryAtPath: [annotatedImagePath stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: &err];
                    if (err) assert(false);
                    
                    /// Write `annotatedImage` to `annotatedImagePath`
                    ///     I'm not sure what's the proper way to do this.
                    ///         (Tried `representationOfImageRepsInArray:` and it didn't work)
                    err = nil;
                    auto jpegData = imageData(annotatedImage, NSBitmapImageFileTypeJPEG, @{});
                    [jpegData writeToFile: annotatedImagePath options: NSDataWritingAtomic error: &err];
                    if (err) assert(false);
                }
                
                auto item = [MFQLPreviewItem new];
                {
                    item.previewItemTitle = [imagePath lastPathComponent];
                    item.previewItemURL   = [NSURL fileURLWithPath: annotatedImagePath];
                    // item.previewItemDisplayState = nil; /// Do we need this? [Oct 2025]
                }
                
                return item;
            };
    
    #pragma mark - Selection
    
    #if 0
        - (NSTableViewSelectionHighlightStyle)selectionHighlightStyle {
            return NSTableViewSelectionHighlightStyleNone;
        }
    #endif
    
    #pragma mark - Menu Items
    
    - (NSInteger) indexOfColumnWithIdentifier: (NSUserInterfaceItemIdentifier)identifier {
        NSInteger i = 0;
        for (NSTableColumn *col in self.tableColumns) {
            if ([col.identifier isEqual: identifier]) return i;
            i++;
        }
        return -1;
    }
    - (void) tableMenuItemClicked: (NSMenuItem *)menuItem {
        [self toggleIsTranslatedState: self.selectedRowModel]; /// All our menuItems are for toggling and `validateMenuItem:` makes it so we can only toggle [Oct 2025]
    }
    
    - (void) toggleIsTranslatedState: (NSXMLElement *)transUnit {
        
        BOOL isTranslated = [self rowIsTranslated: transUnit];
        
        /// Register undo / redo
        {
            auto undoManager = [getdoc(self) undoManager];
            [[undoManager prepareWithInvocationTarget: self] toggleIsTranslatedState: transUnit]; /// Just calling toggle to undo could become incorrect if anything else except this method updates the state.
            [undoManager setActionName: (isTranslated ^ [undoManager isUndoing]) ? kMFStr_MarkForReview : kMFStr_MarkAsTranslated];
        }
        
        /// Update datamodel
        if (!isTranslated)
            rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_Translated);
        else
            rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_NeedsReview);
        
        /// Save to disk
        [getdoc(self) writeTranslationDataToFile];
        [getdoc(self)->ctrl->out_sourceList progressHasChanged]; /// Update the progress percentage indicators
        
        /// `Find transUnit in UI`
        ///     I think this is only necessary if we're undoing. Otherwise the row we're toggling will already be on-screen and selected
        NSInteger row = [_displayedTransUnits indexOfObject: transUnit];
        if (row == NSNotFound) {
            /// Remove the filter
            [getdoc(self)->ctrl->out_filterField setStringValue: @""];
            [self updateFilter: @""]; /// Maybe be unnecessary – Updating `out_filterField` may call this automatically
            /// Try again
            row = [_displayedTransUnits indexOfObject: transUnit];
        }
        if (row == NSNotFound) {
            /// Navigate to AllDocuments
            [getdoc(self)->ctrl->out_sourceList showAllTransUnits];
            row = [_displayedTransUnits indexOfObject: transUnit];
        }
        if (row == NSNotFound) {
            assert(false); /// Give up – don't think this can happen.
        }
        
        /// Reload transUnit UI
        ///     (Don't think this is necessary if we called `updateFilter:` or `showAllTransUnits`, cause those will already have reloaded the whole table[Oct 2025]
        [self /// Specifying rows and colums  to updatefor speedup, but I think the delay is just built in to NSMenu  (macOS Tahoe, [Oct 2025])
            reloadDataForRowIndexes:    [NSIndexSet indexSetWithIndex: row]
            columnIndexes:              [NSIndexSet indexSetWithIndex: [self indexOfColumnWithIdentifier: @"state"]]
        ];
        
        /// Show transUnit row
        ///     Should only be necessary if we're undoing. See `Find transUnit in UI` above [Oct 2025]
        [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        [self scrollRowToVisible: row];
        
    }
    
    - (BOOL) rowIsTranslated: (NSXMLElement *)transUnit {
        auto state = rowModel_getCellModel(transUnit, @"state");
        return [state isEqual: kMFTransUnitState_Translated];
    }
    
    - (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
        
        auto transUnit = [self rowModel: self.clickedRow];
        
        if ([rowModel_getCellModel(transUnit, @"state") isEqual: @"mf_dont_translate"])
            return NO;
        if (
            [rowModel_getCellModel(transUnit, @"state") isEqual: kMFTransUnitState_Translated] &&
            [menuItem.identifier isEqual: @"mark_as_translated"]
        ) {
            return NO;
        }
        if (
            ![rowModel_getCellModel(transUnit, @"state") isEqual: kMFTransUnitState_Translated] && /// `tableMenuItemClicked:` expects us to only allow toggling (only one of the two items may be active) [Oct 2025]. (This may be stupid)
            [menuItem.identifier isEqual: @"mark_for_review"]
        ) {
            return NO;
        }
        
        return YES;
    }

    #pragma mark - NSTableView

    #pragma mark - NSTableViewDataSource

    - (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView {
        return [_displayedTransUnits count];
    }
    
    - (NSView *) tableView: (NSTableView *)tableView viewForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row {
    
        #define iscol(colid) [[tableColumn identifier] isEqual: (colid)]
        
        NSXMLElement *transUnit = [self rowModel: row];
        
        /// Get model value
        NSString *uiString = rowModel_getCellModel(transUnit, [tableColumn identifier]);
        
        /// Remove redundant stuff from IB-generated notes
        if (iscol(@"note")) {
            
            NSDictionary *notesDict = [NSPropertyListSerialization /// The Notes generated by IB are old-style plists with the keys directly at the root. Old Xcode .strings files had the same format IIRC. [Oct 2025]
                propertyListWithData: [uiString dataUsingEncoding: NSUTF8StringEncoding]
                options: 0
                format: NULL
                error: nil
            ];
            if (!isclass(notesDict, NSDictionary)) {
                if (notesDict) mflog(@"Found non-NSDictionary plist notes: %@", notesDict); /// If the comment is a plain string without quotes, that is also a valid plist [Oct 2025]
            }
            else {
                
                if
                (
                    (
                        notesDict.allKeys.count == 3 && /// Complex validation is just a sanity check [Oct 2025]
                        (
                            [toset(notesDict.allKeys) isEqual: toset(@[         @"Class", @"ObjectID", @"title"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[         @"Class", @"ObjectID", @"ibShadowedToolTip"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[         @"Class", @"ObjectID", @"placeholderString"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[         @"Class", @"ObjectID", @"label"])]
                        )
                    )
                    ||
                    (
                        notesDict.allKeys.count == 4 &&
                        (
                            [toset(notesDict.allKeys) isEqual: toset(@[@"Note", @"Class", @"ObjectID", @"title"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[@"Note", @"Class", @"ObjectID", @"ibShadowedToolTip"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[@"Note", @"Class", @"ObjectID", @"placeholderString"])] ||
                            [toset(notesDict.allKeys) isEqual: toset(@[@"Note", @"Class", @"ObjectID", @"label"])]
                            
                        )
                    )
                ) {
                    uiString = notesDict[@"Note"] ?: @"";
                }
                else
                    assert(false);
            }
        }
        
        /// Special stuff for `<target>` column
        bool targetCellShouldBeEditable = true;
        
        /// Handle pluralizable strings
        ///         TODO: Fix pluralizable strings getting 'split up' when sorting / filtering
        {
            if ([xml_childnamed(transUnit, @"source").objectValue containsString: @"%#@"]) { /// Detects the `%#@formatSstring@`
                if      (iscol(@"id"))       {}
                else if (iscol(@"source"))   uiString = @"(pluralizable)";
                else if (iscol(@"target")) { uiString = @"(pluralizable)"; targetCellShouldBeEditable = false; } /// We never want the `%#@formatSstring@` to be changed by the translators, so we override it. We don't hide it cause 1.  it holds the comment and 2. we like having a 1-to-1 relationship between transUnits and rows in the table.
                else if (iscol(@"state"))    { if ((0)) uiString = @"(pluralizable)"; }
                else if (iscol(@"note"))     {}
                else                         assert(false);
            }
            
            if ([xml_attr(transUnit, @"id").objectValue containsString: @"|==|"]) { /// This detects the pluralizable variants.
                
                if (iscol(@"id")) {
                    NSArray *a = [xml_attr(transUnit, @"id").objectValue componentsSeparatedByString: @"|==|"]; assert(a.count == 2);
                    NSString *baseKey = a[0];
                    NSString *substitutionPath = a[1];
                    assert([substitutionPath hasPrefix: @"substitutions.pluralizable.plural."]);
                    NSString *pluralVariant = [substitutionPath substringFromIndex: @"substitutions.pluralizable.plural.".length];
                    uiString = stringf(@"%@ (%@)", baseKey, pluralVariant);
                }
                else if (iscol(@"note")) uiString = @""; /// Delete the note cause the `%#@` string already has it. (We assume that the `%#@` always appears in the row right above [Oct 2025])
            }
        }
        
        /// Override raw state string with colorful symbols / badges
        
        NSAttributedString *uiStringAttributed  = [[NSAttributedString alloc] initWithString: (uiString ?: @"")];
        #define attributed(str) [[NSAttributedString alloc] initWithString: (str)]
        NSColor *stateCellBackgroundColor = nil;
        if (iscol(@"state")) {
            if ((0)) {}
                else if ([uiString isEqual: kMFTransUnitState_Translated]) {
                    uiStringAttributed = make_green_checkmark(uiString);
                    
                }
                else if ([uiString isEqual: kMFTransUnitState_DontTranslate]) {
                    uiStringAttributed = attributed(@"DON'T TRANSLATE");
                    stateCellBackgroundColor = [NSColor systemGrayColor];
                }
                else if ([uiString isEqual: kMFTransUnitState_New]) {
                    uiStringAttributed = attributed(@"NEW");
                    stateCellBackgroundColor = [NSColor systemBlueColor];
                }
                else if ([uiString isEqual: kMFTransUnitState_NeedsReview]) {
                    uiStringAttributed = attributed(@"NEEDS REVIEW");
                    stateCellBackgroundColor = [NSColor systemOrangeColor];
                }
                else if ([uiString isEqual: @"(pluralizable)"]) { /// Unused now [Oct 2025]
                    uiStringAttributed = attributed(@"");
                }
            else assert(false);
        }
        
        /// Turn off editing for `mf_dont_translate`
        if (iscol(@"target") && [rowModel_getCellModel(transUnit, @"state") isEqual: @"mf_dont_translate"])
            targetCellShouldBeEditable = false;
        
        /// Create cell
        NSTableCellView *cell;
        {
            if (stateCellBackgroundColor) {
                cell = [tableView makeViewWithIdentifier: @"theReusableCell_TableState" owner: self];
                { /// Style copies Xcode xcloc editor. Rest of the style defined in IB.
                    cell.nextKeyView.wantsLayer = YES;
                    cell.nextKeyView.layer.cornerRadius = 3;
                    cell.nextKeyView.layer.borderWidth  = 1;
                }
                
                cell.nextKeyView.layer.borderColor     = [stateCellBackgroundColor CGColor];
                cell.nextKeyView.layer.backgroundColor = [[stateCellBackgroundColor colorWithAlphaComponent: 0.15] CGColor];
            }
            else {
                
                if (iscol(@"id"))
                    cell = [tableView makeViewWithIdentifier: @"theReusableCell_TableID" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
                else if (iscol(@"target"))
                    cell = [tableView makeViewWithIdentifier: @"theReusableCell_TableTarget" owner: self]; /// This contains an `MFTextField`
                else
                    cell = [tableView makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                
                cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
                cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
                cell.textField.selectable = YES;
                
                if (iscol(@"target")) {
                    __block NSString *oldString = uiString;
                    auto editingCallback = ^void (NSString *newString) {
                        mflog(@"<target> edited: %@", newString);
                        rowModel_setCellModel(transUnit, @"target", newString);
                        if (![oldString isEqual: newString])
                            rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_Translated);
                        [getdoc(self) writeTranslationDataToFile];
                        [self /// Don't call `-[reloadData]` since that looses the current selection.
                            reloadDataForRowIndexes: [NSIndexSet indexSetWithIndex: row]
                            columnIndexes: [NSIndexSet indexSetWithIndex: [self indexOfColumnWithIdentifier: @"state"]]
                        ];
                        oldString = newString;
                        
                    };
                    [cell.textField mf_setAssociatedObject: editingCallback forKey: @"editingCallback"];
                    [cell.textField setEditable: targetCellShouldBeEditable]; /// FIxme: Editable disables the intrinsic height, causing content to be truncated. [Oct 2025]
                }
                else if (iscol(@"id")) {
                    auto matchingPlistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: transUnit];
                    if (!matchingPlistEntry) {
                        /// Remove the quicklook button from IB
                        cell = [tableView makeViewWithIdentifier: @"theReusableCell_Table" owner: self]; /// Go back to default cell (Fixme: refactor) (We don't modify cause that affects future calls to `makeViewWithIdentifier:`)
                    }
                    else {
                        NSButton *quickLookButton = firstmatch(cell.subviews, cell.subviews.count, nil, sv, [sv.identifier isEqual: @"quick-look-button"]);
                        [quickLookButton setAction: @selector(quickLookButtonPressed:)];
                        [quickLookButton setTarget: self];
                        [quickLookButton mf_setAssociatedObject: @(row) forKey: @"rowOfQuickLookButton"];
                        
                        /// Set up things ...
                    }
                    
                    
                    
                }
            }
            
            [cell.textField setAttributedStringValue: uiStringAttributed];
        }
        
        
        /// Return
        return cell;
        #undef iscol
    }

    #pragma mark - NSTableViewDelegate

    - (void) tableView:(NSTableView *) tableView didClickTableColumn:(NSTableColumn *) tableColumn {
        mflog(@"Table column '%@' clicked!", tableColumn.title);
    }
    
    #pragma mark - NSControlTextEditingDelegate (Callbacks for the NSTextField)
    
    - (void) controlTextDidEndEditing: (NSNotification *)notification {
        
        /// Call the editing callback with the new stringValue
        NSTextField *textField = notification.object;
        if (!textField.editable) return; /// This is also called for selectable textFields.
        ((void (^)(NSString *))[textField mf_associatedObjectForKey: @"editingCallback"])(textField.stringValue);
    }
    


@end

