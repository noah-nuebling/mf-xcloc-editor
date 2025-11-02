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
#import "Constants.h"
#import "XclocDocument.h"
#import "RowUtils.h"
#import "MFTextField.h"
#import "MFUI.h"
#import "NSNotificationCenter+Additions.h"

#pragma mark - MFQLPreviewItem

@interface MFQLPreviewItem : NSObject<QLPreviewItem>

    @property NSURL * previewItemURL;
    @property NSString * previewItemTitle;
    //@property id previewItemDisplayState;

@end
@implementation MFQLPreviewItem @end

#pragma mark - TableRowView

auto reusableViewIDs = @[ /// Include any IDs that we call `makeViewWithIdentifier:` on. Otherwise the `makeViewWithIdentifier:` will randomly return nil when it 'runs out' of views or something. [Oct 2025]
    @"theReusableCell_Table",
    @"theReusableCell_TableState",
    @"theReusableCell_TableID",
    @"theReusableCell_TableTarget",
        
];

@interface TableRowView : NSTableRowView @end
@implementation TableRowView

    /// Give selected rows a light-blue background like Xcode, this is mostly so that selecting text in rows doesn't look weird (selected rows have *dark* blue background, which flips the text to white, but the selection is *light* blue)
    
    - (void) drawSelectionInRect: (NSRect)dirtyRect { /// Src: https://stackoverflow.com/a/9594543
        
        auto appearance = [[self effectiveAppearance] bestMatchFromAppearancesWithNames: @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        if (![self isEmphasized])
            [[NSColor unemphasizedSelectedContentBackgroundColor] setFill]; /// Exacly matches Xcode 26 xcloc editor (Looks a bit dark but oh well) [Oct 2025]
        else {
            if ([appearance isEqual: NSAppearanceNameDarkAqua])
                [[NSColor colorWithSRGBRed: 24/255.0 green: 48/255.0 blue: 75/255.0 alpha: 1.0] setFill]; /// Color copied from Xcode 26 [Oct 2025]
            else
                [[NSColor colorWithSRGBRed: 217/255.0 green: 237/255.0 blue: 255/255.0 alpha: 1.0] setFill]; /// Color copied from Xcode 26 [Oct 2025]
        }
            
        [[NSBezierPath bezierPathWithRoundedRect: self.bounds xRadius: 5 yRadius: 5] fill];
    }
    
    //- (BOOL)isEmphasized { return NO; } /// Prevent text from turning black
    - (NSBackgroundStyle)interiorBackgroundStyle {
        return NSBackgroundStyleNormal; /// Prevent text from turning black
    }


    - (void)drawSeparatorInRect: (NSRect)dirtyRect {
        if (self.isSelected) return;
        if (self.nextRowSelected) return;
        [super drawSeparatorInRect: dirtyRect];
    }

@end

#pragma mark - TableView

@implementation TableView
    {
        NSString *_filterString;
        NSMutableArray<NSXMLElement *> *_displayedTopLevelTransUnits; /// Main dataModel displayed by this table. Does not contain transUnits which are children || Terminology: We call these rowModels, OutlineView-Items, or transUnits – All these terms refer to the same thing [Oct 2025]
        NSMutableDictionary<NSXMLElement *, NSArray<NSXMLElement *> *> *_childrenMap; /// Maps topLevel transUnits to their pluralizable variant children
        id _lastQLPanelDisplayState;
        NSString *_lastTargetCellString;
    }

    #pragma mark - Lifecycle

    - (instancetype) initWithFrame: (NSRect)frame {
        
        self = [super initWithFrame: frame];
        if (!self) return nil;
        
        self.delegate   = self; /// [Jun 2025] Will this lead to retain cycles or other problems?
        self.dataSource = self;

        /// Listen for field editor notifications to reload source cell when editing begins/ends
        [[NSNotificationCenter defaultCenter]
            mf_addObserverForName: @"MFTextField_BecomeFirstResponder"
            object: nil
            observee: self
            block: ^(NSNotification *note, TableView *self) {
                
                /// Swap in MFInvisiblesTextView for @"source" column cell when the @"target" column cell is being edited
                ///     (To be able to display invisibles just like our fieldEditor does on the @"target" cell being edited.) [Oct 2025]
                /// Note: We used to reload the tableCells here to display the `MFTextField`, but reloading here seems to break our firstResponder tracking in MFTextField (See `MFTextField_BecomeFirstResponder`) – I hope it doesn't break due to other random stuff. (Now we're applying the overlay directly here instead of reloading the table)
                ///
                /// High-level:
                ///     We're trying to dynamically swap in invisibles-drawing NSTextVIew for the MFTextField for performance, while the MFTextField in the @"target" col is firstResponder (being edited) but both firstResponder tracking and retrieving the reference to the @"source" column views is brittle and doesn't work 100% reliably right now [Oct 2025]
                ///     Alternative: Just make everything NSTextViews all the time and take the performance hit. Or just give up on invisibles.
                
                MFTextField *textField__ = note.object;
                
                if (textField__.window != self.window) return; /// Since `object: nil` we receive this notification from *all* NSTextFields including ones in other windows.
                
                NSInteger row = [self rowForView: textField__];
                if (row == -1) { /// Randomly returns -1 sometimes. Can't reproduce. In lldb it consistently returns -1 IIRC, so there is some weird state causing this, not just sporadic. [Oct 2025] Update: This may be fixed by the `textField__.window != self.window` check above.
                    assert(false);
                    textField__.hidden = NO;
                    return;
                }
                
                NSTableCellView *cell = [self viewAtColumn: [self columnWithIdentifier: @"source"] row: row makeIfNecessary: NO];
                
                /// Show MFInvisiblesTextView with newline glyphs
                cell.textField.hidden = YES /*NO*/; /// Set to YES overlays the MFTextField and MFInvisiblesTextView, making text darker – useful as debugging tool (or to keep usable if there are bugs)

                NSTextView *textView = [cell.textField mf_associatedObjectForKey: @"MFInvisiblesTextView_Overlay"];
                if (!textView) {
                    textView = [MFInvisiblesTextView new];
                    {
                        textView.translatesAutoresizingMaskIntoConstraints = NO;
                        textView.font = cell.textField.font;
                        textView.textColor = cell.textField.textColor ?: [NSColor labelColor];
                        textView.editable = NO;
                        textView.selectable = YES;
                        textView.drawsBackground = NO;
                        textView.textContainer.lineFragmentPadding = 0;
                        
                    }

                    [cell addSubview: textView];
                    mfui_setmargins(cell, mfui_margins(8,8,2,2), textView); /// Margins match constraints on cell.textField in IB [Oct 2025]
                    [cell.textField mf_setAssociatedObject: textView forKey: @"MFInvisiblesTextView_Overlay"];
                    [textField__ mf_setAssociatedObject: cell.textField forKey: @"MFSourceCellSister"];
                }

                textView.hidden = NO;
                textView.string = cell.textField.stringValue;
            }
        ];

        [[NSNotificationCenter defaultCenter]
            mf_addObserverForName: @"MFTextField_ResignFirstResponder"
            object: nil
            observee: self
            block: ^(NSNotification *note, TableView *self) {
                
                /// Note:
                ///     Using "MFSourceCellSister" associatedObject because `[self rowForView: textField__]` always returns zero in the `MFTextField_ResignFirstResponder` callback, when the firstResponder state was produced by `[XclocWindow -restoreStateWithCoder:]` [Oct 2025]
                
                MFTextField *textField__ = note.object;
                if (textField__.window != self.window) return;
                
                MFTextField *sisterTextField = [textField__ mf_associatedObjectForKey: @"MFSourceCellSister"];
                NSTextView *textView = [sisterTextField mf_associatedObjectForKey: @"MFInvisiblesTextView_Overlay"];
                
                if (sisterTextField) sisterTextField.hidden = NO;
                if (textView)        textView.hidden = YES;
            }
        ];
        
        /// Configure style
        self.gridStyleMask = 0
            | NSTableViewSolidVerticalGridLineMask
            | NSTableViewSolidHorizontalGridLineMask
        ;
        self.style = NSTableViewStyleFullWidth;
        self.usesAutomaticRowHeights = YES;
        self.indentationPerLevel = 20.0;
        self.autoresizesOutlineColumn = NO; /// This makes the column-width be auto-resized according to Claude - we don't want that I think
        
        /// Register ReusableViews
        auto nib = [[NSNib alloc] initWithNibNamed: @"ReusableViews" bundle: nil];
        for (NSString *viewID in reusableViewIDs)
            [self registerNib: nib forIdentifier: viewID];
        
        /// Add columns
        {
            auto mfui_tablecol = ^NSTableColumn *(NSString *identifier, NSString *title, NSInteger minWidth, NSInteger defaultWidth, NSInteger maxWidth, BOOL autoresizes) {
                auto v = [[NSTableColumn alloc] initWithIdentifier: identifier];
                [v setSortDescriptorPrototype: [NSSortDescriptor sortDescriptorWithKey: v.identifier ascending: YES]];
                v.title = title;
                v.minWidth = minWidth;
                v.maxWidth = maxWidth;
                v.width = defaultWidth;
                
                if (autoresizes) {
                    v.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
                }
                else {
                    v.resizingMask = NSTableColumnUserResizingMask;
                }
                
                return v;
            };
            
            [self addTableColumn: mfui_tablecol(@"id",     @"Key",     75,  150, 999999, NO)];
            [self addTableColumn: mfui_tablecol(@"source", @"",        100, 300, 999999, NO)]; /// UIString set in `reloadWithNewData:` [Oct 2025]
            [self addTableColumn: mfui_tablecol(@"target", @"",        100, 300, 999999, NO)];
            [self addTableColumn: mfui_tablecol(@"note",   @"Comment", 100, 150, 999999, YES)];
            [self addTableColumn: mfui_tablecol(@"state",  @"State",   77,  77,  77, NO)]; /// Fit 'NEEDS REVIEW' badge perfectly

            /// Set the ID column as the outline column (shows disclosure triangles)
            [self setOutlineTableColumn: [self tableColumnWithIdentifier: @"id"]];
            
            /// Column sizing
            [self setColumnAutoresizingStyle: NSTableViewUniformColumnAutoresizingStyle];
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
                mfui_item(@"mark_as_translated", kMFStr_MarkAsTranslated_Symbol, kMFStr_MarkAsTranslated),
                mfui_item(@"mark_for_review",    kMFStr_MarkForReview_Symbol, kMFStr_MarkForReview),
            ]);
        }
        
        
        /// Return
        return self;
    }
    
    #pragma mark - Drawing
    
    - (void) drawGridInClipRect: (NSRect)clipRect {
        /// Src: https://stackoverflow.com/a/6844340
        ///     Only affects horizontal grid
        
        NSRect lastRowRect = [self rectOfRow:[self numberOfRows]-1];
        NSRect myClipRect = NSMakeRect(0, 0, lastRowRect.size.width, NSMaxY(lastRowRect));
        NSRect finalClipRect = NSIntersectionRect(clipRect, myClipRect);
        [super drawGridInClipRect:finalClipRect];
    }
    
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
        [self toggleIsTranslatedState: [self itemAtRow: [self clickedRow]]]; /// All our menuItems are for toggling and `validateMenuItem:` makes it so we can only toggle [Oct 2025]
    }
    
    - (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
        
        NSXMLElement *transUnit = [self itemAtRow: [self clickedRow]]; /// This is a right-click menu so we use `clickedRow` instead of `selectedItem`
        
        if ([[self stateOfRowModel: transUnit] isEqual: @"mf_dont_translate"])
            return NO;
        if (rowModel_isParent(transUnit))
            return NO;
        if (
            [[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated] &&
            [menuItem.identifier isEqual: @"mark_as_translated"]
        ) {
            return NO;
        }
        if (
            ![[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated] && /// `tableMenuItemClicked:` expects us to only allow toggling (only one of the two items may be active) [Oct 2025]. (This may be stupid)
            [menuItem.identifier isEqual: @"mark_for_review"]
        ) {
            return NO;
        }
        
        return YES;
    }
    
    #pragma mark - Mouse Control
        
        /// When you click a non-selected row, you have to way to click again to start editing. Otherwise the 'double click' will do nothing.
        ///     ... Seems this is hard to turn off ... maybe I'll just leave it. [Oct 2025]
        
        #if 0
            - (void) mf_doubleClicked: (id)sender {
            
                //mflog(@"doubleCliceedd: %@", sender);
                //[self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: [self selectedRow] withEvent: nil select: YES];
            }
        #endif
        
        #if 0 /// Messes up stuff. `controlTextDidBeginEditing` is not called (I think due to this)
        - (void) mouseDown: (NSEvent *)event {
            NSInteger clickedRow = [self rowAtPoint: [self convertPoint: event.locationInWindow fromView: nil]];
            if (clickedRow == -1) { assert(false); return; }
            if ([self selectedRow] == clickedRow) {
                [self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: clickedRow withEvent: event select: NO];
                
            }
            else {
                [self selectRowIndexes: indexset(clickedRow) byExtendingSelection: NO];
            }
        }
        #endif
    
    #pragma mark - Keyboard control
    
        - (void) returnFocus {
            
            /// After another UIElement has had keyboardFocus, it can use this method to give it back to the `TableView`
            
            [self.window makeFirstResponder: self];
            
            NSInteger rowToSelect = -1;
            NSRange visibleRows = [self rowsInRect: [self visibleRect]]; /// Just using visibleRect includes area rendered behind titlebar / columnHeaders. Src: https://stackoverflow.com/a/39920483
            if (NSLocationInRange(self.selectedRow, visibleRows))   rowToSelect = self.selectedRow;     /// Use currently selected row
            if (rowToSelect == -1)                                  rowToSelect = visibleRows.location; /// Select first visible row
            
            if (rowToSelect != -1) {
                [self selectRowIndexes: [NSIndexSet indexSetWithIndex: rowToSelect] byExtendingSelection: NO];
            }
            else assert(false);
            
            runOnMain(0.0, ^{ /// See other uses of `scrollRowToVisible:` || I'm not sure it helps here since we don't call this after reloading the data [Oct 2025] ... No I think it does help
                [self scrollRowToVisible: rowToSelect];
            });
            
            
        }
        
        - (void) editNextRow {
        
            if (self.selectedRow == -1) return;
            auto nextRow = self.selectedRow + 1;
            if (rowModel_isParent([self itemAtRow: nextRow])) nextRow += 1; /// Skip over parents
            if ([self numberOfRows] <= nextRow) return;
            [self selectRowIndexes: indexset(nextRow) byExtendingSelection: NO];
            
            [self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: nextRow withEvent: nil select: YES];
        }
        - (void) editPreviousRow {
        
            if (self.selectedRow == -1) return;
            auto nextRow = self.selectedRow - 1;
            if (rowModel_isParent([self itemAtRow: nextRow])) nextRow -= 1; /// Skip over parents
            if (0 > nextRow) return;
            [self selectRowIndexes: indexset(nextRow) byExtendingSelection: NO];
            
            [self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: nextRow withEvent: nil select: YES];
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
                else if (eventIsKey(theEvent, ' '))	/// Space key opens the preview panel. Also supports Command-Y (using Menu Item)
                    [self togglePreviewPanel: self];
                else
                    [super keyDown: theEvent]; /// Handling of UpArrow and DownArrow is built-in to `NSTableView` [Oct 2025]
            }
        }
        - (void) cancelOperation: (id)sender {
            
            
            if (isclass([self.window firstResponder], NSTextView)) { /// If the user is editing a translation, cancel editing
                
                NSTextView *textView = (id)[self.window firstResponder];
                MFTextField *textField = (id)[textView delegate];
                
                [super cancelOperation: sender];
                
                [textField textDidEndEditing: [NSNotification notificationWithName: @"MFHACK" object: textView]]; /// HACK: Make `textDidEndEditing:` be called in MFTextField when the user hits escape
                
                return;
            }
            
            [getdoc(self)->ctrl->out_sourceList.window makeFirstResponder: getdoc(self)->ctrl->out_sourceList]; /// Return focus to sidebar when user hits escape while editing transUnits. Also see other `cancelOperation:` overrides. [Oct 2025]
        }
    
        - (BOOL) control: (NSControl*)control textView: (NSTextView*)textView doCommandBySelector: (SEL)commandSelector {
            
            mflog(@"commandBySelector: %s", sel_getName(commandSelector));
            
            BOOL didHandle = NO;
         
            if (isclass(control, MFTextField)) {
                
                /// Let users enter newlines in the `@"target"` cells' (without holding Option – which may not be discoverable)
                ///     Src: https://developer.apple.com/library/archive/qa/qa1454/_index.html
                ///     Implementing this in TableView cause TableView is the delegate of `MFTextField`. Not sure if that's good. [Oct 2025]
                ///     Idea: Could also instead add shift-return for newline to make it more discoverable for LLM users.
                
                {
                    
                    BOOL kreturn    = commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:);
                    BOOL koption    = commandSelector == @selector(insertNewlineIgnoringFieldEditor:);
                    BOOL kshift     = (NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift);
                    
                    if ((0)) {}
                    else if (kreturn && (koption ^ kshift))               goto newline;
                    else if (kreturn)                       goto end_editing;
                    
                    goto end;
                    newline: {
                        [textView insertNewlineIgnoringFieldEditor: self];
                        didHandle = YES;
                    }
                    goto end;
                    end_editing: {
                        [textView insertNewline: self];
                        didHandle = YES;
                        
                        if (koption && kshift)
                            [self editPreviousRow];
                        else
                            [self editNextRow];
                    }
                    end: {}
                    
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
        
    #pragma mark - NSControlTextEditingDelegate (Callbacks for the MFTextField)
    
    - (void) controlTextDidBeginEditing: (NSNotification *)notification {
        /// CAUTION: This is not called
        ///     See:
        ///     - https://developer.apple.com/documentation/objectivec/nsobject/1428847-controltextdidendediting?language=objc
        ///     ... Update: We stopped relying on this [Oct 2025]
        NSTextField *textField = notification.object;
        _lastTargetCellString = textField.stringValue; /// Track whether textField content was actually changed inside `controlTextDidEndEditing:`. Would be nicer if we could use callbacks instead of ivars. [Oct 2025]
        mflog(@"controlTextDidBeginEditing: %@", _lastTargetCellString);
    }
    - (void) controlTextDidEndEditing: (NSNotification *)notification {
        
        
        mflog(@"controlTextDidEndEditing: %@", [[notification object] stringValue]);
        
        NSTextField *textField = notification.object;
        if (!textField.editable) return;  /// This is also called for selectable textFields.
        assert(isclass(textField, MFTextField));
        auto selectedItem = [self selectedItem];
        if (!selectedItem) { [self reloadData]; return; } /// This happens when macOS restores the user interface after a crash while a row was being edited. [reloadData] to make sure the user is editing up-to-date data.
        assert(selectedItem);
        if (![_lastTargetCellString isEqual: textField.stringValue])
            [self setTranslation: textField.stringValue andIsTranslated: YES onRowModel: [self selectedItem]]; /// We also save if the user cancels editing by pressing escape – but they can always Command-Z to undo. [Oct 2025]
    }
    
    #pragma mark - Sorting

    - (void) outlineView: (NSOutlineView *)outlineView sortDescriptorsDidChange: (NSArray<NSSortDescriptor *> *)oldDescriptors { /// This is called when the user clicks the column headers to sort them.
        
        auto previouslySelectedItem = [self selectedItem];
        
        [self update_rowModelSorting];
        [self reloadData];
        
        [self restoreSelectionWithPreviouslySelectedItem: previouslySelectedItem];
    }

    #pragma mark - Filtering
    - (void) updateFilter: (NSString *)filterString {
        
        _filterString = filterString;
        [self bigUpdateAndStuff];
    }

    #pragma mark - Data
    
    
    - (NSXMLElement *) selectedItem {
        return [self itemAtRow: self.selectedRow];
    }

    - (void) update_rowModels {

        /// Build parent-child map for pluralizable strings
        _childrenMap = [NSMutableDictionary new];
        NSMutableSet<NSXMLElement *> *allChildTransUnits = [NSMutableSet new];

        for (NSXMLElement *transUnit in self->transUnits) {
            NSString *idStr = xml_attr(transUnit, @"id").objectValue;
            if ([idStr containsString: @"|==|"]) {
                /// This is a child variant
                NSArray *parts = [idStr componentsSeparatedByString: @"|==|"];
                NSString *baseKey = parts[0];

                /// Find parent with matching baseKey
                for (NSXMLElement *potentialParent in self->transUnits) {
                    NSString *parentId = xml_attr(potentialParent, @"id").objectValue;
                    if ([parentId isEqual: baseKey]) { /// Found parent
                    
                        assert(rowModel_isParent(potentialParent)); /// Make sure our utility function works.
                        
                        NSMutableArray *children = (NSMutableArray *)_childrenMap[potentialParent];
                        if (!children) {
                             children = [NSMutableArray new];
                             _childrenMap[potentialParent] = children;
                        }
                        [children addObject: transUnit];
                        [allChildTransUnits addObject: transUnit];
                        break;
                    }
                }
            }
        }

        /// Filter
        _displayedTopLevelTransUnits = [NSMutableArray new];
        for (NSXMLElement *transUnit in self->transUnits) {

            { /// Validate
                assert(isclass(transUnit, NSXMLElement));
                assert([transUnit.name isEqual: @"trans-unit"]);
            }

            if ([allChildTransUnits containsObject: transUnit])
                continue; /// Skip child variants - they'll be shown as children of their parent

            if (![_filterString length])
                [_displayedTopLevelTransUnits addObject: transUnit];
            else {
                #define combinedRowString(transUnit) stringf(@"%@\n%@\n%@\n%@", /** Note that we're searching cellModel strings which are a bit different than uiStrings. But this works fine. */\
                    rowModel_getCellModel(transUnit, @"id"), \
                    rowModel_getCellModel(transUnit, @"source"), \
                    rowModel_getCellModel(transUnit, @"target"), \
                    rowModel_getCellModel(transUnit, @"note") /** Note how we're omitting @"state" */\
                )
                
                auto combinedTransUnitString = [NSMutableString new];
                [combinedTransUnitString appendString: combinedRowString(transUnit)];
                for (NSXMLElement *childTransUnit in _childrenMap[transUnit]) {
                    [combinedTransUnitString appendString: @"\n"];
                    [combinedTransUnitString appendString: combinedRowString(childTransUnit)];
                }
                
                if (
                    [combinedTransUnitString
                        rangeOfString: _filterString
                        options: (/*NSRegularExpressionSearch |*/ NSCaseInsensitiveSearch)
                    ]
                    .location != NSNotFound
                ) {
                    [(NSMutableArray *)_displayedTopLevelTransUnits addObject: transUnit];
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
        
        #if 0
            NSInteger rowCount = [self numberOfRowsInTableView: self]; /// -[numberOfRows] gives wrong results while swtiching files not sure what's going on [Oct 2025]
        #endif
        
        [_displayedTopLevelTransUnits sortUsingComparator: ^NSComparisonResult(NSXMLElement *i, NSXMLElement *j) {
            NSComparisonResult comp;
            if ([desc.key isEqual: @"state"]) {
                comp = (
                    [_stateOrder indexOfObject: [self stateOfRowModel: i]] -
                    [_stateOrder indexOfObject: [self stateOfRowModel: j]]
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

    - (NSXMLElement *) topLevelItemContainingItem: (NSXMLElement *)searchedItem {
        if ((0))
            return [self parentForItem: searchedItem] ?: searchedItem; /// This would probably also work. But maybe `self->_displayedTopLevelTransUnits` works better in some edge-cases where the table hasn't loaded the items, yet? Not sure that's relevant. [Oct 2025]
        
        for (NSXMLElement *u in self->_displayedTopLevelTransUnits) { /// Returns the searchedItem if it is topLevel itself
            if ([u isEqual: searchedItem])
                return u;
            if ([self->_childrenMap[u] containsObject: searchedItem])
                return u;
        }
        return nil;
    };

    - (void) restoreSelectionWithPreviouslySelectedItem: (NSXMLElement *)previouslySelectedItem {
        
        /// Restore the selection after reloadData resets it.
        
        [self expandItem: [self parentForItem: previouslySelectedItem]]; /// Not sure if necessary [Oct 2025]
        
        NSInteger newIndex = [self rowForItem: previouslySelectedItem];
        if (newIndex != -1) {
            [self selectRowIndexes: [NSIndexSet indexSetWithIndex: newIndex] byExtendingSelection: NO];
            runOnMain(0.0, ^{ /// Delay helps with reliability [Oct 2025]
                [self scrollRowToVisible: newIndex]; /// Tried to do a better job of keeping the row in the same position than `scrollRowToVisible:` but can't get it to work. Coordinates flip and `rectOfRow:` result seems inconsistent. [Oct 2025] || ... update: This still fails sometimes, though rarely. Maybe the APIs are broken? How do they even know how tall all the rows are? || Update: After switching to NSOutlineView, it seems to fail almost always. ... using NSTimer helps [Oct 2025]
            });
        }
    }

    - (void) bigUpdateAndStuff {
        
        /// Fully update the table with new rows, but try to preserve the selection.
        ///     Not sure this is a good abstraction to have, I don't really understand it [Oct 2025]
        
        auto previouslySelectedItem = [self selectedItem];
        
        [self update_rowModels];;
        [self reloadData];
        
        [self restoreSelectionWithPreviouslySelectedItem:  previouslySelectedItem];
    }

    - (void) reloadWithNewData: (NSArray <NSXMLElement *> *)transUnits {
        
        self->transUnits = transUnits;
        [self bigUpdateAndStuff];
            
        /// Update column names (weird place to do this) [Oct 2025]
        {
            auto srcCol = [self tableColumnWithIdentifier: @"source"];
            if (!srcCol.title.length)
                //srcCol.title = stringf(@"Original (%@)",    getdoc(self)->ctrl->out_sourceList->sourceLanguage);
                srcCol.title = stringf(@"Original");
        
            auto targetCol = [self tableColumnWithIdentifier: @"target"];
            if (!targetCol.title.length)
                targetCol.title = stringf(@"Translation (%@)",    getdoc(self)->ctrl->out_sourceList->targetLanguage);
        }

    }
    
    - (NSString *) stateOfRowModel: (NSXMLElement *)transUnit {
        
        /// Define parent node state in terms of their children
        ///     don't call `rowModel_getCellModel(..., @"state")`, directly
        
        if (_childrenMap[transUnit].count) {
            for (NSXMLElement *ch in _childrenMap[transUnit]) {
                if (![rowModel_getCellModel(ch, @"state") isEqual: kMFTransUnitState_Translated])
                    return kMFTransUnitState_NeedsReview;
            }
            return kMFTransUnitState_Translated;
        }
        else {
            return rowModel_getCellModel(transUnit, @"state");
        }
    }
    
    #pragma mark - Editing
    
    - (void) toggleIsTranslatedState: (NSXMLElement *)transUnit {
        [self setIsTranslatedState: ![self rowIsTranslated: transUnit] onRowModel: transUnit];
    }
    
    - (BOOL) rowIsTranslated: (NSXMLElement *)transUnit {
        auto state = [self stateOfRowModel: transUnit];
        return [state isEqual: kMFTransUnitState_Translated];
    }
    
    - (void) setIsTranslatedState: (BOOL)newIsTranslatedState onRowModel:(NSXMLElement *)transUnit {
        
        /// Register undo / redo
        {
            auto undoManager = [getdoc(self) undoManager];
            [[undoManager prepareWithInvocationTarget: self] setIsTranslatedState: !newIsTranslatedState onRowModel: transUnit];
            [undoManager setActionName: (!newIsTranslatedState ^ [undoManager isUndoing]) ? kMFStr_MarkForReview : kMFStr_MarkAsTranslated];
        }
        
        /// Update datamodel
        if (newIsTranslatedState)
            _rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_Translated);
        else
            _rowModel_setCellModel(transUnit, @"state", kMFTransUnitState_NeedsReview);
        
        /// Save to disk
        [getdoc(self) writeTranslationDataToFile];
        
        /// Update progress UI
        [getdoc(self)->ctrl->out_sourceList progressHasChanged]; /// Update the progress percentage indicators
        
        /// Show edited row to user
        [self _revealTransUnit: transUnit];
        
        /// Reload state cell
        ///     - (Don't think this is necessary if we called `updateFilter:` or `showAllTransUnits` in `_revealTransUnit:`, cause those will already have reloaded the whole table [Oct 2025]
        ///     - Used to use `reloadDataForRowIndexes:` instead of `reloadItem:` but that caused weird crashes in the layout system when toggling state and then resizing the table. [Oct 2025] [macOS 26 Tahoe]
        ///         Another detail: IIRC, the exception said something about trying to activate a constraint between a  tableRowView an the tableCellView that don't have a common ancestor.
        ///         Fix idea: The crash might be related to us passing different IDs to `makeViewWithIdentifier:` depending on the state – that may confuse the layout system.
        ///         Explanation idea: Also note that `reloadDataForRowIndexes:` is an NSTableView method not an NSOutlineView one - so maybe we're not supposed to call that.
        ///         Problem: with `reloadItem:`: When toggling state via Command-R while editing the @"target" col textField, editing ends and it always sets the state to 'translated'. That's because `reloadItem:` reloads the entire row.
        {
            [self reloadItem: [self selectedItem] reloadChildren: NO]; /// `_revealTransUnit:` selects the desired row [Oct 2025]
            [self reloadItem: [self parentForItem: [self selectedItem]] reloadChildren: NO]; /// Update the parent as well – the state it displays depends on its children.
        }
        
    }
    - (void) setTranslation: (NSString *)newString andIsTranslated: (BOOL)isTranslated onRowModel: (NSXMLElement *)transUnit {
        
        /// Log
        mflog(@"setTranslation: %@", newString);
        
        /// Guard no edit
        if ([rowModel_getCellModel(transUnit, @"target") isEqual: newString])
            return; /// `controlTextDidBeginEditing:` doesn't work so we do this here. [Oct 2025]
        
        /// Prepare undo
        {
            auto undoManager = [getdoc(self) undoManager];
            auto oldString = rowModel_getCellModel(transUnit, @"target");
            auto oldIsTranslated = [[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated];
            [[undoManager prepareWithInvocationTarget: self] setTranslation: oldString andIsTranslated: oldIsTranslated onRowModel: transUnit];
            [undoManager setActionName: @"Edit Translation"];
        }
        
        /// Update datamodel
        _rowModel_setCellModel(transUnit, @"target", newString);
        _rowModel_setCellModel(transUnit, @"state", isTranslated ? kMFTransUnitState_Translated : kMFTransUnitState_NeedsReview);
        
        /// Save to disk
        [getdoc(self) writeTranslationDataToFile];
        
        /// Update progress UI
        [getdoc(self)->ctrl->out_sourceList progressHasChanged]; /// Only necessary if the state actually changed [Oct 2025]
        
        /// Show edited row to user
         [self _revealTransUnit: transUnit];
             
        /// Reload cells
        {
            [self reloadItem: [self selectedItem] reloadChildren: NO];
            [self reloadItem: [self parentForItem: [self selectedItem]] reloadChildren: NO]; /// See `setIsTranslatedState:`
        }
    }
    
    - (void) _revealTransUnit: (NSXMLElement *)transUnit {
    
        /// Helper made for when our editing methods are called by undoManager [Oct 2025]
    
        /// `Navigate UI` to make transUnit displayed by the TableView
        ///     I think this is only necessary if we're undoing. Otherwise the transUnit we're manipulating will already be on-screen and selected
        NSXMLElement *topLevel;
        {
        
            topLevel = [self topLevelItemContainingItem: transUnit];
            if (!topLevel) {
                /// Remove the filter
                [getdoc(self)->ctrl->out_filterField setStringValue: @""];
                [self updateFilter: @""]; /// Maybe unnecessary - Updating `out_filterField` may call this automatically
                /// Try again
                topLevel = [self topLevelItemContainingItem: transUnit];
            }
            if (!topLevel) {
                /// Navigate to AllDocuments
                [getdoc(self)->ctrl->out_sourceList showAllTransUnits];
                /// Try again
                topLevel = [self topLevelItemContainingItem: transUnit];
            }
            if (!topLevel) {
                assert(false); /// Give up - don't think this can happen.
            }
        }
        
        /// Expand the parent in case the row we wanna reveal is a child (not sure if necessary)
        [self expandItem: topLevel];
        
        /// HACK: Remove editing state
        ///     Otherwise bug: If the current row's @"target" textfield is being edited, macOS will transfer editing to the @"target" textField on the row we're going to select, (not sure why, may be bug? – macOS 26.0) but then, when we reload the @"target" cell in `setTranslation:` (caller of this method), that immediately removes the editing state and that invokes `controlTextDidEndEditing:`, which then invokes the undoManger writes to our data model (Calls `setTranslation:`) but with the *current* content of the textField insteadof the value we want to restore via undo. So this cancels the undo.
        ///         Note: Even with this fix, this whole thing is brittle: If this is triggered by an undo while editing a @"target" textField, this line will trigger `controlTextDidEndEditing:` on the currently selected row which then calls `setTranslation:` but this works because `setTranslation:` should always do nothing in this case because the undoManager should only try to undo edits from another row, if the currently selected row's textField has no edits that can be undone, which will cause `setTranslation:` to immediately return [Oct 2025]
        ///         Update: Had to pass `self` instead of `nil` so we don't break keyboard-interaction
        [[NSApp mainWindow] makeFirstResponder: self];
        
        /// Show transUnit row
        ///     Should only be necessary if we're undoing. See `Navigate UI` above [Oct 2025]
        [self
            selectRowIndexes: indexset([self rowForItem: transUnit])
            byExtendingSelection: NO
        ];
        runOnMain(0.0, ^{ /// See other uses of `scrollRowToVisible:` [Oct 2025]
            [self scrollRowToVisible: [self rowForItem: transUnit]];
        });
        
        { /// Idea: Also scroll the state-column into-view when toggling it. [Oct 2025]
            NSString *col = nil;
            if (col)
                [self scrollColumnToVisible: [self columnWithIdentifier: col]];
        }

    }
    
    #pragma mark - Selection
    
    #if 0
        - (NSTableViewSelectionHighlightStyle)selectionHighlightStyle {
            return NSTableViewSelectionHighlightStyleNone;
        }
    #endif

    #pragma mark - NSOutlineViewDataSource

    - (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item {
        if (!item) return [_displayedTopLevelTransUnits count]; /// Root level
        else       return [_childrenMap[item] count];           /// Child level
    }

    - (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item {
        if (!item)  return _displayedTopLevelTransUnits[index]; /// Root level
        else        return _childrenMap[item][index];           /// Child level
    }

    - (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item {
        return [_childrenMap[item] count];
    }

    - (NSView *) outlineView: (NSOutlineView *)outlineView viewForTableColumn: (NSTableColumn *)tableColumn item: (id)item {

        #define iscol(colid) [[tableColumn identifier] isEqual: (colid)]

        NSXMLElement *transUnit = item;
        
        /// Get model value
        NSString *uiString = rowModel_getCellModel(transUnit, [tableColumn identifier]);
        
        /// Get propery model value for @"state"
        ///     This is a bit hacky
        if (iscol(@"state"))
            uiString = [self stateOfRowModel: transUnit];
        
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
        {
            if (rowModel_isParent(transUnit)) {
                if      (iscol(@"id"))       {}
                else if (iscol(@"source"))   uiString = @"(pluralizable)";
                else if (iscol(@"target")) { uiString = @"(pluralizable)"; targetCellShouldBeEditable = false; } /// We never want the `%#@formatSstring@` to be changed by the translators, so we override it.
                else if (iscol(@"state"))    { if ((0)) uiString = @"(pluralizable)"; }
                else if (iscol(@"note"))     {}
                else                         assert(false);
            }

            if ([xml_attr(transUnit, @"id").objectValue containsString: @"|==|"]) { /// This detects the pluralizable variants (child rows).

                if (iscol(@"id")) {
                    NSArray *a = [xml_attr(transUnit, @"id").objectValue componentsSeparatedByString: @"|==|"];
                    assert(a.count == 2);
                    NSString *substitutionPath = a[1];
                    assert([substitutionPath hasPrefix: @"substitutions.pluralizable.plural."]);
                    NSString *pluralVariant = [substitutionPath substringFromIndex: @"substitutions.pluralizable.plural.".length];
                    uiString = pluralVariant; /// Just show the variant name (e.g. "one", "other") since it's a child row
                }
                else if (iscol(@"note")) uiString = @""; /// Delete the note cause the parent row already has it.
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
                    stateCellBackgroundColor = nil;
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
            else {
                uiStringAttributed = attributed(stringf(@"Error: unknown state: %@", uiString));
                assert(false);
            }
        }
        
        /// Create cell
        NSTableCellView *cell;
        {
            if (stateCellBackgroundColor) {
                assert([reusableViewIDs containsObject: @"theReusableCell_TableState"]);
                cell = [outlineView makeViewWithIdentifier: @"theReusableCell_TableState" owner: self];
                { /// Style copies Xcode xcloc editor. Rest of the style defined in IB.
                    cell.nextKeyView.wantsLayer = YES;
                    cell.nextKeyView.layer.cornerRadius = 3;
                    cell.nextKeyView.layer.borderWidth  = 1;
                }

                cell.nextKeyView.layer.borderColor     = [stateCellBackgroundColor CGColor];
                cell.nextKeyView.layer.backgroundColor = [[stateCellBackgroundColor colorWithAlphaComponent: 0.15] CGColor];
                
            }
            else {
                auto matchingScreenshotPlistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: transUnit];

                if (iscol(@"id")) {
                    if (matchingScreenshotPlistEntry) {
                        assert([reusableViewIDs containsObject: @"theReusableCell_TableID"]);
                        cell = [outlineView makeViewWithIdentifier: @"theReusableCell_TableID" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
                    }
                    else {
                        /// Use default text cell if there is no quickLook button
                        assert([reusableViewIDs containsObject: @"theReusableCell_Table"]);
                        cell = [outlineView makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                    }

                }
                else if (iscol(@"target")) {
                    assert([reusableViewIDs containsObject: @"theReusableCell_TableTarget"]);
                    cell = [outlineView makeViewWithIdentifier: @"theReusableCell_TableTarget" owner: self]; /// This contains an `MFTextField`
                }
                else {
                    assert([reusableViewIDs containsObject: @"theReusableCell_Table"]);
                    cell = [outlineView makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                }

                /// Special config
                {
                    if (iscol(@"target")) {
                        [cell.textField setEditable: targetCellShouldBeEditable];
                    }
                    else if (iscol(@"id")) {
                        if (matchingScreenshotPlistEntry) {
                            NSButton *quickLookButton = firstmatch(cell.subviews, cell.subviews.count, nil, sv, [sv.identifier isEqual: @"quick-look-button"]);
                            [quickLookButton setAction: @selector(quickLookButtonPressed:)];
                            [quickLookButton setTarget: self];
                            [quickLookButton mf_setAssociatedObject: @([outlineView rowForItem: item]) forKey: @"rowOfQuickLookButton"];
                        }
                    }
                    else {
                        
                    }
                }
            }
            /// Common config
            cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
            cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textField.selectable = YES;
            
            /// Special override config
            if (iscol(@"state") && !stateCellBackgroundColor) { /// This is only called for the `green_checkmark` (Other state cells are handled by `stateCellBackgroundColor`).
                cell.textField.selectable = NO;                 /// The `green_checkmark` disappears when selected, so we disable selection. [Oct 2025]
            }

            [cell.textField setAttributedStringValue: uiStringAttributed];
        }
        
        /// Validate
        if (cell == nil) {
            assert(false);
            mflog(@"nill cell %@", transUnit);
        }
        
        /// Return
        return cell;
        #undef iscol
    }

    #pragma mark - NSOutlineView subclass
    
    - (void) reloadData {
        [super reloadData];
        [self expandItem: nil expandChildren: YES]; /// mfunexpand – Expand all items by default. || We're also using `reloadDataForRowIndexes:` additionally to `reloadData`, but overriding that doesn't seem necessary to keep the items expanded [Oct 2025]
    }
    
    - (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes {
        mflog(@"ReloadData with indexes: %@ %@", rowIndexes, columnIndexes);
        [super reloadDataForRowIndexes: rowIndexes columnIndexes: columnIndexes];
    }

    #pragma mark - NSOutlineViewDelegate

    - (void) outlineViewSelectionDidChange: (NSNotification *)notification {
        [QLPreviewPanel.sharedPreviewPanel reloadData];
    }
    
    - (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item {
        return [TableRowView new];
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
            for (NSDictionary *entry in getdoc(self)->_localizedStringsDataPlist) {
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
                
                [self returnFocus];
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
                _lastQLPanelDisplayState = [panel displayState];
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
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self selectedItem]];
                return [plistEntry[@"screenshots"] count];
            };

            - (id <QLPreviewItem>) previewPanel: (QLPreviewPanel *)panel previewItemAtIndex: (NSInteger)index {
                
                mflog(@"previewItemAtIndex: called with index: %ld", index);
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self selectedItem]];
                NSDictionary *screenshotEntry = plistEntry[@"screenshots"][index];
                
                NSRect frame = NSRectFromString(screenshotEntry[@"frame"]);
                NSString *name = screenshotEntry[@"name"];
                
                NSString *imagePath = findPaths(0, [stringf(@"%@%@", [getdoc(self).fileURL path], @"/Notes/Screenshots/") stringByStandardizingPath], ^BOOL(NSString *path) {
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
                ///     Idea: Claude suggests this may be because the image is compressed? We did choose compressed jpegs to reduce file size IIRC, due to the Xcode bug that forced us to duplicate the images. Compression may no longer be beneficial when switching from Xcode -> mf-xcloc-editor. [Oct 2025]
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


@end

