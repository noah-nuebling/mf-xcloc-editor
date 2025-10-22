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

#define kMFTransUnitState_Translated      @"translated"
#define kMFTransUnitState_DontTranslate   @"mf_dont_translate"
#define kMFTransUnitState_New             @"new"
#define kMFTransUnitState_NeedsReview     @"needs-review-l10n"
static auto _stateOrder = @[ /// Order of the states to be used for sorting [Oct 2025]
    kMFTransUnitState_New,
    kMFTransUnitState_NeedsReview,
    kMFTransUnitState_Translated,
    kMFTransUnitState_DontTranslate
];

/// Column-ids
///     ... Actually feels fine just using the strings directly [Oct 2025]
#define kColID_ID       @"id"
#define kColID_State    @"state"
#define kColID_Source   @"source"
#define kColID_Target   @"target"
#define kColID_Note     @"note"

@implementation TableView
    {
        
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
                mfui_item(@"mark_as_translated", @"checkmark.circle", @"Mark as Translated"),
                mfui_item(@"mark_for_review",    @"x.circle", @"Mark for Review"),
            ]);
        }
        
        
        /// Return
        return self;
    }
    
    #pragma mark - Keyboard control
    
        - (void) keyDown: (NSEvent *)theEvent {
            
            auto key = [theEvent charactersIgnoringModifiers];
            
            if (QLPreviewPanel.sharedPreviewPanel.visible) {
                if ([key isEqual: stringf(@"%C", (unichar)NSLeftArrowFunctionKey)]) /// Flip through different screenshots containing the currently selected string. Could also implement this in `previewPanel:handleEvent:` [Oct 2025]
                    [self _incrementCurrentPreviewItem: -1];
                else if ([key isEqual: stringf(@"%C", (unichar)NSRightArrowFunctionKey)])
                    [self _incrementCurrentPreviewItem: +1];
            }
            else {
                if ([key isEqual: stringf(@"%C", (unichar)NSLeftArrowFunctionKey)]) /// Select the sourceList
                    [appdel->sourceList.window makeFirstResponder: appdel->sourceList];
            }
            
            if ([key isEqual:@" "])	/// Space key opens the preview panel. || TODO: Also support Command-Y (using Menu Item)
                [self togglePreviewPanel: self];
            else
                [super keyDown: theEvent];
        }
        - (void) cancelOperation: (id)sender {
            
            if ([[self.window firstResponder] isKindOfClass: [NSTextView class]]) { /// If the user is editing a translation, cancel editing
                [super cancelOperation: sender];
                return;
            }
            
            [appdel->sourceList.window makeFirstResponder: appdel->sourceList]; /// Return focus to sidebar when user hits escape while editing transUnits. Also see other `cancelOperation:` overrides. [Oct 2025]
        }
    
    #pragma mark - Sorting
    
    - (void) tableView: (NSTableView *)tableView sortDescriptorsDidChange: (NSArray<NSSortDescriptor *> *)oldDescriptors { /// This is called when the user clicks the column headers to sort them.
        
        auto previouslySelectedRowID = rowModel_getCellModel([self rowModel: [self selectedRow]], @"id");
        
        [self update_rowModelSorting];
        [self reloadData];
        
        [self restoreSelectionWithPreviouslySelectedRowID: previouslySelectedRowID];
    }

    #pragma mark - Filtering
    
    static NSString *_filterString = nil;
    - (void) updateFilter: (NSString *)filterString {
        
        _filterString = filterString;
        [self bigUpdateAndStuff];
    }

    #pragma mark - Data

    static NSMutableArray<NSXMLElement *> *_displayedTransUnits = nil; /// Main dataModel displayed by this table.
    
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
                
            if ([rowModel_getCellModel(transUnit, @"state") isEqual: kMFTransUnitState_DontTranslate])
                continue; /// Always filter dontTranslate rows (Why does Xcode even export those?)
            
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

     NSString *rowModel_getCellModel(NSXMLElement *transUnit, NSString *columnID) {
        if ((0)) {}
            else if ([columnID isEqual: @"id"])        return xml_attr(transUnit, @"id")           .objectValue;
            else if ([columnID isEqual: @"source"])    return xml_childnamed(transUnit, @"source") .objectValue;
            else if ([columnID isEqual: @"target"])    return xml_childnamed(transUnit, @"target") .objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
            else if ([columnID isEqual: @"note"])      return xml_childnamed(transUnit, @"note")   .objectValue;
            else if ([columnID isEqual: @"state"]) {
                if ([xml_attr(transUnit, @"translate").objectValue isEqual: @"no"])
                    return kMFTransUnitState_DontTranslate;
                else
                    return xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
            }
        else assert(false);
        return nil;
    }
     void rowModel_setCellModel(NSXMLElement *transUnit, NSString *columnID, NSString *newValue) {
        if ((0)) {}
            else if ([columnID isEqual: @"id"])        xml_attr(transUnit, @"id")          .objectValue = newValue;
            else if ([columnID isEqual: @"source"])    xml_childnamed(transUnit, @"source").objectValue = newValue;
            else if ([columnID isEqual: @"target"])    xml_childnamed(transUnit, @"target").objectValue = newValue;
            else if ([columnID isEqual: @"note"])      xml_childnamed(transUnit, @"note")  .objectValue = newValue;
            else if ([columnID isEqual: @"state"]) {
                if ([newValue isEqual: kMFTransUnitState_DontTranslate])
                    xml_attr(transUnit, @"translate").objectValue = @"no";
                else
                    xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue = newValue;
            }
        else assert(false);
    };


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
            for (NSDictionary *entry in self->_localizedStringsDataPlist) {
                if ([entry[@"stringKey"] isEqual: rowModel_getCellModel(transUnit, @"id")]) {
                    if (matchingPlistEntry) assert(false); /// Multiple entries for this key
                    matchingPlistEntry = entry;
                }
            }
            if ((0)) assert([matchingPlistEntry[@"tableName"] isEqual: rowModel_getCellModel(transUnit, @"fileName")]); /// Our `rowModel` doesn't actually have a `@"fileName"`, but if it did, this should be true. [Oct 2025]
            
            return matchingPlistEntry;
        };
        
        static id _lastQLPanelDisplayState = nil;
        
        - (IBAction) quickLookButtonPressed: (id)quickLookButton {
            NSInteger row = [[quickLookButton mf_associatedObjectForKey: @"rowOfQuickLookButton"] integerValue];
            [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
            [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: nil];
        }
        
        - (IBAction)togglePreviewPanel:(id)previewPanel {
            if (
                [QLPreviewPanel sharedPreviewPanelExists] &&
                [[QLPreviewPanel sharedPreviewPanel] isVisible]
            ) {
                [[QLPreviewPanel sharedPreviewPanel] orderOut: nil];
            }
            else
                [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: nil];
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
                if (_lastQLPanelDisplayState) [panel setDisplayState: _lastQLPanelDisplayState];
                return;
            }
            - (void) endPreviewPanelControl: (QLPreviewPanel *)panel {
                _lastQLPanelDisplayState = [panel displayState]; /// This is always nil. || TODO: Make QLPanel window default sizes better & implement size restoration
                return;
            }

        #pragma mark QLPreviewPanelDelegate
        
            - (NSRect) previewPanel: (QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem: (id <QLPreviewItem>)item {
                /// TODO: Implement this for nice zoom-transition
                return NSMakeRect(0, 0, 0, 0);
            }
            - (BOOL) previewPanel: (QLPreviewPanel *)panel handleEvent: (NSEvent *)event {
                /// redirect all key down events from the QLPanel to the table view (So you can flip through rows) [Oct 2025]
                if ([event type] == NSEventTypeKeyDown) {
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
                
                NSString *imagePath = findPaths([stringf(@"%@%@", appdel->xclocPath, @"/Notes/Screenshots/") stringByStandardizingPath], ^BOOL(NSString *path) {
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
                    auto jpegData = [[NSBitmapImageRep imageRepWithData: [annotatedImage TIFFRepresentation]] representationUsingType: NSBitmapImageFileTypeJPEG properties: @{}];
                    [jpegData writeToFile: annotatedImagePath options: NSDataWritingAtomic error: &err];
                    if (err) assert(false);
                }
                
                auto item = [MFQLPreviewItem new];
                {
                    item.previewItemTitle = [imagePath lastPathComponent];
                    item.previewItemURL   = [NSURL fileURLWithPath: annotatedImagePath];
                    item.previewItemDisplayState = nil; /// Do we need this? [Oct 2025]
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
        
        mflog(@"menuItem clicked: %@ %ld", menuItem, self.clickedRow);
        
        NSXMLElement *transUnit = [self rowModel: self.clickedRow];
        
        if ((0)) {}
            else if ([menuItem.identifier isEqual: @"mark_as_translated"]) {
                rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_Translated);
            }
            else if ([menuItem.identifier isEqual: @"mark_for_review"]) {
                rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_NeedsReview);
            }
        else assert(false);
        
        [self /// Specifying rows and colums  to updatefor speedup, but I think the delay is just built in to NSMenu  (macOS Tahoe, [Oct 2025])
            reloadDataForRowIndexes:    [NSIndexSet indexSetWithIndex: self.clickedRow]
            columnIndexes:              [NSIndexSet indexSetWithIndex: [self indexOfColumnWithIdentifier: @"state"]]
        ];
        [appdel writeTranslationDataToFile];
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
            [rowModel_getCellModel(transUnit, @"state") isEqual: kMFTransUnitState_NeedsReview] &&
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
        
        /// Special stuff for `<target>` column
        bool targetCellShouldBeEditable = true;
        
        /// Handle pluralizable strings
        {
            if ([xml_childnamed(transUnit, @"source").objectValue containsString: @"%#@"]) { /// Detects the `%#@formatSstring@`
                if      (iscol(@"id"))       {}
                else if (iscol(@"source"))   uiString = @"(pluralizable)";
                else if (iscol(@"target")) { uiString = @"(pluralizable)"; targetCellShouldBeEditable = false; } /// We never want the `%#@formatSstring@` to be changed by the translators, so we override it. We don't hide it cause 1.  it holds the comment and 2. we like having a 1-to-1 relationship between transUnits and rows in the table.
                else if (iscol(@"state"))    uiString = @"(pluralizable)";
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
                    auto image = [NSImage imageWithSystemSymbolName: @"checkmark.circle" accessibilityDescription: uiString]; /// Fixme: This disappears when you double-click it.
                    auto textAttachment = [NSTextAttachment new]; {
                        [textAttachment setImage: image];
                    }
                    uiStringAttributed = [NSAttributedString attributedStringWithAttachment: textAttachment attributes: @{
                        NSForegroundColorAttributeName: [NSColor systemGreenColor]
                    }];
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
                else if ([uiString isEqual: @"(pluralizable)"]) {
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
                else
                    cell = [tableView makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                
                cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
                cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
                cell.textField.selectable = YES;
                
                if (iscol(@"target")) {
                    auto editingCallback = ^void (NSString *newString) {
                        mflog(@"<target> edited: %@", newString);
                        rowModel_setCellModel(transUnit, @"target", newString);
                        rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_Translated);
                        [appdel writeTranslationDataToFile];
                        [self /// Don't call `-[reloadData]` since that looses the current selection.
                            reloadDataForRowIndexes: [NSIndexSet indexSetWithIndex: row]
                            columnIndexes: [NSIndexSet indexSetWithIndex: [self indexOfColumnWithIdentifier: @"state"]]
                        ];
                        
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
                        
                        NSButton *quickLookButton = (id)[cell nextKeyView];
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

