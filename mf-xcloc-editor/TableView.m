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
#import "NSView+Additions.h"
#import "Utility/ToString.m"

static int __invocations = 0; /// Performance testing
static int __invocation_rowheight = 0;
static CGFloat _defaultRowHeight = 75 /*100*/; /// We return this in `heightOfRowByItem:`  || Tradeoff: higher -> faster load times, too-high -> 'fights you' when scrolling up (not just jitter), 100 'fights you' 75 is fine. [NOv 2025]

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
    
    - (void) setFrame: (NSRect)frame {
        
        
        /// HACK to fix jitter when scroling up.
        /// Purpose:
        ///     adjust scrollPosition when system loads 'real' height of a row to prevent shifting of the rows below which is perceived as jitter.
        /// Context:
        ///     See `heightOfRowByItem:` and `_defaultRowHeight`
        /// Observations: [Nov 2025, macOS Tahoe]
        ///     I observed that the table already adjusts the scroll position when it initially loads and the view. It seems to use the `_defaultRowHeight` value we give to it often but sometimes
        ///     it uses different values, perhaps trying to predict based on previously loaded views or something like that. It then however calls setFrame: again with the final, actual size of the view, but it *doesn't* adjust the scroll position for that second resizing.
        ///     Once the final actual size of the row has been determined once, it always immediately uses that size when the view comes into the viewport again. reloadData: seems to reset everything.
        ///     -> This code tries to catch the 'second resizing' case and adjust the scroll-position.
        /// Caveats:
        ///     - This is a workaround for what seems to be a bug in NSTableView, which is possibly triggered by our override of `heightByRowItem:` to return a constant `_defaultRowHeight` which makes loading dramatically faster for some reason (probably also due to bugs / suboptimal code in the framework)
        ///         -> On macOS versions where these bugs aren't present, these workarounds could cause issues. But on macOS 26 Tahoe, they seem to work very well.
        ///     - There are still sometimes small scroll-position jumps with this [Nov 2025] but it's much better than without, and am too lazy to investigate further.

        if (
            self.frame.size.height == _defaultRowHeight && frame.size.height != _defaultRowHeight &&
            NSEqualRects(NSRectFromRect(self.frame, .height = 0), NSRectFromRect(frame, .height = 0)) /// Not sure this check is necessary, but matches what I've observed [Nov 2025]
        ) {
        
            auto clipView = [[self enclosingScrollView] contentView];
            
            if (clipView.bounds.origin.y > self.frame.origin.y) { /// Row loaded at the top of the viewport (scrolling up)
                auto boundsOrigin = [clipView bounds].origin;
                boundsOrigin.y += frame.size.height - _defaultRowHeight;
                [clipView setBoundsOrigin: boundsOrigin];
            }
            else ; /// Row loaded at the bottom of the viewport (scrolling down)
        }
            
        [super setFrame: frame];
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
        BOOL didJustEndEditingWithReturnKey;
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
                
                /// Former content of `controlTextDidBeginEditing:`
                if ((0)) /// Disable cause we assume this would never be called when it was still in `controlTextDidBeginEditing:`
                {
                    
                    /// CAUTION: This is not called
                    ///     See:
                    ///     - https://developer.apple.com/documentation/objectivec/nsobject/1428847-controltextdidendediting?language=objc
                    ///     ... Update: We stopped relying on this [Oct 2025]
                    
                    NSTextField *textField = note.object;
                    self->_lastTargetCellString = textField.stringValue; /// Track whether textField content was actually changed inside `controlTextDidEndEditing:`. Would be nicer if we could use callbacks instead of ivars. [Oct 2025]
                    mflog(@"controlTextDidBeginEditing: %@", self->_lastTargetCellString);
                }
                
                /// Swap in `MFInvisiblesTextView_Overlay`
                {
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
                    [textField__ mf_setAssociatedObject: cell.textField forKey: @"MFSourceCellSister"]; /// Do this every time cause cells get swapped out by the tableView[Nov 2025]
                    
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
                    }

                    textView.hidden = NO;
                    textView.string = cell.textField.stringValue;
                    
                    mflog(@"MFInvisiblesTextView_Overlay Showing for row %ld (views: %p|%p)", row, textField__, textView);
                }
            }
        ];

        [[NSNotificationCenter defaultCenter]
            mf_addObserverForName: @"MFTextField_ResignFirstResponder"
            object: nil
            observee: self
            block: ^(NSNotification *note, TableView *self) {
    
    
                /// Cleanup `MFInvisiblesTextView_Overlay`
                /// Note:
                ///     Using "MFSourceCellSister" associatedObject because `[self rowForView: textField__]` always returns zero in the `MFTextField_ResignFirstResponder` callback, when the firstResponder state was produced by `[XclocWindow -restoreStateWithCoder:]` [Oct 2025]
                {
                    
                    MFTextField *textField__ = note.object;
                    if (textField__.window != self.window) return;
                    
                    MFTextField *sisterTextField = [textField__ mf_associatedObjectForKey: @"MFSourceCellSister"];
                    NSTextView *textView = [sisterTextField mf_associatedObjectForKey: @"MFInvisiblesTextView_Overlay"];
                    
                    if (sisterTextField) sisterTextField.hidden = NO;
                    if (textView)        textView.hidden = YES;
                    
                    mflog(@"MFInvisiblesTextView_Overlay Hiding  for row %ld (views: %p|%p)", [self rowForView: sisterTextField], textField__, textView);
                }
    
                /// Former content of `controlTextDidEndEditing:`
                ///     (Several comments elsewhere talk about `controlTextDidEndEditing:`, so don't delete this. [Nov 2025])
                {
                    mflog(@"controlTextDidEndEditing: %@, self->didJustEndEditingWithReturnKey: %d",
                        [[note object] stringValue], self->didJustEndEditingWithReturnKey);
                    
                    NSTextField *textField = note.object;
                    
                    {
                        if (!textField.editable) return;  /// This is also called for selectable textFields.
                        assert(isclass(textField, MFTextField));
                    }
                    
                    if (![self selectedItem]) { /// This happens when macOS restores the user interface after a crash while a row was being edited. [reloadData] to make sure the user is editing up-to-date data. Update: [Nov 2025] This might not apply anymore after fixing bug where XclocWindow wasn't released after being closed.
                        [self reloadData];
                        return;
                    }
                    
                    if (![self->_lastTargetCellString isEqual: textField.stringValue]) /// `_lastTargetCellString` is never set [Nov 2025]
                        [self                                               /// We also save if the user cancels editing by pressing escape – but they can always Command-Z to undo. [Oct 2025]
                            setTranslation:         textField.stringValue   /// Saving can reload tableCells so we wanna cleanup the `MFInvisiblesTextView_Overlay` before this [Nov 2025]
                            alsoModifyIsTranslated: self->didJustEndEditingWithReturnKey
                            isTranslated:           self->didJustEndEditingWithReturnKey
                            onRowModel:             [self selectedItem]
                        ];
                }
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
            
            /// Sort by the table by @"id" column by default
            [self setSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"id" ascending: YES]]];
            
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
            auto mfui_sepitem = ^{
                return [NSMenuItem separatorItem];
            };
            
            
            self.menu = mfui_menu(@[
                mfui_item(@"mark_for_review",    @"", @""),
                mfui_sepitem(),
                mfui_item(@"reveal_in_file",     @"", @""),                                         /// UIStrings now generated in `validateMenuItem:`
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
        
        if ([menuItem.identifier isEqual: @"mark_for_review"]) {
            [self toggleIsTranslatedState: [self itemAtRow: [self clickedRow]]]; /// All our menuItems are for toggling and `validateMenuItem:` makes it so we can only toggle [Oct 2025]
        }
        
        else if ([menuItem.identifier isEqual: @"reveal_in_file"]) {
        
            NSXMLElement *transUnit = [self itemAtRow: [self clickedRow]];
            [self selectRowIndexes: indexset([self rowForItem: transUnit]) byExtendingSelection: NO]; /// When you switch files with a visible row selected, our code will automatically try to reveal that row after the file-switch. [Nov 2025]
            
            if ([getdoc(self)->ctrl->out_sourceList allTransUnitsShown]) {
                [getdoc(self)->ctrl->out_sourceList showFileOfTransUnit: transUnit];
            } else {
                [getdoc(self)->ctrl->out_sourceList showAllTransUnits];
            }
        }
        else {
            assert(false);
        }
    }
    
    - (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
        
        NSXMLElement *transUnit = [self itemAtRow: [self clickedRow]]; /// This is a right-click menu so we use `clickedRow` instead of `selectedItem`
        
        if ([[self stateOfRowModel: transUnit] isEqual: @"mf_dont_translate"]) return NO;
        
        /// Handle review-items
        
        if ([menuItem.identifier isEqual: @"mark_for_review"]) {
            
            if ([[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated]) {
                menuItem.title = kMFStr_MarkForReview;
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkForReview_Symbol accessibilityDescription:kMFStr_MarkForReview];
            }
            else {
                menuItem.title = kMFStr_MarkAsTranslated;
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_MarkAsTranslated_Symbol accessibilityDescription: kMFStr_MarkAsTranslated];
            }
            
            if (rowModel_isPluralParent(transUnit)) return NO;
            else                                    return YES;
        }
        /// Handle reveal-items
        if ([menuItem.identifier isEqual: @"reveal_in_file"]) {
        
            if ([getdoc(self)->ctrl->out_sourceList allTransUnitsShown]) {
                menuItem.title = kMFStr_RevealInFile(getdoc(self), transUnit);
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_RevealInFile_Symbol accessibilityDescription: kMFStr_RevealInFile(getdoc(self), transUnit)];
            }
            else {
                menuItem.title = kMFStr_RevealInAll;
                menuItem.image = [NSImage imageWithSystemSymbolName: kMFStr_RevealInAll_Symbol accessibilityDescription: kMFStr_RevealInAll];
            }
            
            return YES;
        }
        
        return [super validateMenuItem: menuItem];
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
            if (rowModel_isPluralParent([self itemAtRow: nextRow])) nextRow += 1; /// Skip over parents
            if ([self numberOfRows] <= nextRow) return;
            [self selectRowIndexes: indexset(nextRow) byExtendingSelection: NO];
            
            [self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: nextRow withEvent: nil select: YES];
        }
        - (void) editPreviousRow {
        
            if (self.selectedRow == -1) return;
            auto nextRow = self.selectedRow - 1;
            if (rowModel_isPluralParent([self itemAtRow: nextRow])) nextRow -= 1; /// Skip over parents
            if (0 > nextRow) return;
            [self selectRowIndexes: indexset(nextRow) byExtendingSelection: NO];
            
            [self editColumn: [self indexOfColumnWithIdentifier: @"target"] row: nextRow withEvent: nil select: YES];
        }
        
    
        - (void) keyDown: (NSEvent *)theEvent {
            
            if (
                (1) && /// Disable keyboard controls for previewItems, cause it's not that useful and currently produces a bit of weird behavior (I think. Can't remember what [Oct 2025]) || Update: [Nov 2025] Re-enabled. No weird behavior. 
                [QLPreviewPanel sharedPreviewPanelExists] &&
                [[QLPreviewPanel sharedPreviewPanel] isVisible]
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
                    BOOL kshift     = !!(NSApp.currentEvent.modifierFlags & NSEventModifierFlagShift);
                    
                    if      (kreturn && (koption ^ kshift))     goto newline;
                    else if (kreturn)                           goto end_editing;
                    
                    goto end;
                    newline: {
                        [textView insertNewlineIgnoringFieldEditor: self];
                        didHandle = YES;
                    }
                    goto end;
                    end_editing: {
                        
                        if (koption && kshift) {
                            [textView insertNewline: self];
                            [self editPreviousRow];
                        }
                        else {
                        
                            self->didJustEndEditingWithReturnKey = YES;
                            
                            [textView insertNewline: self]; /// Calls `controlTextDidEndEditing:`, where we use `didJustEndEditingWithReturnKey`
                            [self editNextRow];

                            self->didJustEndEditingWithReturnKey = NO;
                        }
                        didHandle = YES;
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
    
    #pragma mark - Sorting

    - (void) outlineView: (NSOutlineView *)outlineView sortDescriptorsDidChange: (NSArray<NSSortDescriptor *> *)oldDescriptors { /// This is called when the user clicks the column headers to sort them.
        
        [self bigUpdateAndStuff_OnlyUpdateSorting: YES];
    }

    #pragma mark - Filtering
    - (void) updateFilter: (NSString *)filterString {
        if ([_filterString isEqual: filterString]) return; /// mouseDown: in SourceList.m relies on this to not change the scrollPosition randomly. [Nov 2025]
        _filterString = filterString;
        
        mfdebounce(0.2, @"updateFilter", ^{ /// Keep typing in filterField responsive
            mflog(@"Debouncedd");
            [self bigUpdateAndStuff_OnlyUpdateSorting: NO];
        });
    }

    #pragma mark - Data
    
    
    - (NSXMLElement *) selectedItem {
        return [self itemAtRow: self.selectedRow];
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
    
    - (void) bigUpdateAndStuff_OnlyUpdateSorting: (BOOL)onlyUpdateSorting {
        
        /// Fully update the table in a way that requires calling `reloadData`, but try to preserve the selection.
        
        mflog(@"onlySorting %d", onlyUpdateSorting);
        
        /// Stop editing before the reload
        ///     We do this so that `MFTextField_ResignFirstResponder` is called which saves the edits that the user made, otherwise they are lost. [Nov 2025]
        ///     This happens when you edit a row and then hit Command-J (`Show in 'All Project Files'`) or click a column header to change the sorting [Nov 2025]
        if (isclass([[self window] firstResponder], MFInvisiblesTextView)) { /// Use `MFInvisiblesTextView` instead of `NSTextView` cause the filter field also uses an NSTextView under macOS Sequoia.
            [[self window] makeFirstResponder: self];
        
        }
        
        /// Save the currently selected item and its position on-screen.
        auto previouslySelectedItem = [self selectedItem];
        CGFloat previousMidYViewportOffset = 0.0;
        BOOL shouldRestore = NO;
        {
            auto rectOfRowInViewport = ^ NSRect (TableView *self, NSInteger row) {
                
                /// Rect of the row relative to the visible area of the tableView
                ///     See: https://stackoverflow.com/questions/11767557/scroll-an-nstableview-so-that-a-row-is-centered
                ///     Not sure why this is different from: `[self convertRect: [self rectOfRow: row] toView: [[self enclosingScrollView] contentView]];`, but it works for `bigUpdateAndStuff_OnlyUpdateSorting`
            
                NSRect result   = [self rectOfRow: row];
                NSRect viewport = [self visibleRect]; /// Bounds of the enclosing clipView.
                
                if (!NSIntersectsRect(viewport, result)) return NSZeroRect; /// row is completely off-screen.
                
                result.origin.x -= viewport.origin.x;
                result.origin.y -= viewport.origin.y;
                
                return result;
            };
        
            NSRect r = rectOfRowInViewport(self, [self selectedRow]);
            if (!NSEqualRects(r, NSZeroRect)) {
                shouldRestore = YES;
                previousMidYViewportOffset = NSMidY(r);
            }
        }
        /// Do the actual updates
        {
            /// `update_rowModels`
            if (!onlyUpdateSorting)
            {
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
                            
                                assert(rowModel_isPluralParent(potentialParent)); /// Make sure our utility function works.
                                
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
                    
                        #define combinedRowString(transUnit) stringf(@"%@\n%@\n%@\n%@", /** Using `rowModel_getUIString` instead of `rowModel_getCellModel` cause of the filtering we do on the IB-generated @"note"-column strings [Nov 2025] */\
                            rowModel_getUIString(self, transUnit, @"id"), \
                            rowModel_getUIString(self, transUnit, @"source"), \
                            rowModel_getUIString(self, transUnit, @"target"), \
                            rowModel_getUIString(self, transUnit, @"note") /** Note how we're omitting @"state" */\
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
            }
            
            /// `update_rowModelSorting`
            {
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
                            rowModel_getUIString(self, i, desc.key) compare:
                            rowModel_getUIString(self, j, desc.key)
                        ];
                    }
                    return desc.ascending ? comp : -comp;
                }];
            }
            
            /// Do the reaload!!
            [self reloadData];
        }
        
        /// Helper block
        auto restoreAlpha = ^{
            mfanimate(mfanimate_args(.duration = 0.25), ^{
                self.animator.alphaValue = 1.0;
            }, nil);
        };
        
        /// Restore the previous selection
        if (shouldRestore) {
            
            if ((0))
                [self expandItem: [self parentForItem: previouslySelectedItem]]; /// Not sure if necessary [Oct 2025]
            
            NSInteger newIndex = [self rowForItem: previouslySelectedItem];
            
            mflog(@"restoring selection of item: %@ | newIndex: %ld ...", previouslySelectedItem, newIndex);
            
            if (newIndex != -1) {
                
                /// Select
                [self selectRowIndexes: indexset(newIndex) byExtendingSelection: NO];
                
                /// Fade out to hide jank
                self.alphaValue = 0.0;
                
                /// Restore position
                ///     This is unreliable due to row-height being lazily computed and the table height changing as new rows get on-screen. As workaround, we use recursive `__restorePosition` function that tries a few times.
                ///         Currently not overriding `noteHeightOfRowsWithIndexesChanged:` and using `self.usesAutomaticRowHeights = YES` [Nov 2025]
                ///     Very old notes: Update: After switching from NSTableView to NSOutlineView, it seems to fail almost always [Oct 2025]
                __restorePosition(0, self, previousMidYViewportOffset, newIndex, ^{
                    mflog(@"restored selection of item: %@ | newIndex: %ld", previouslySelectedItem, newIndex);
                    restoreAlpha();
                });
            }
            else {
                [self scrollToBeginningOfDocument: nil]; /// Is this really good? Not native macOS behavior
                restoreAlpha(); /// This this is necessary here I think, not sure why [Nov 2025]
            }
        }
        else {
            [self scrollToBeginningOfDocument: nil]; /// Is this really good? Not native macOS behavior
            restoreAlpha(); /// This this is necessary here I think, not sure why [Nov 2025]
        }
    }
    
    static void __restorePosition (int iteration, TableView *self, CGFloat previousMidYViewportOffset, NSInteger newIndex, void (^completionCallback)(void)) {
        
        /// Helper for `bigUpdateAndStuff_OnlyUpdateSorting`.
        ///     Define here since recursive blocks are annoying and clang doesn't support local functions. [Nov 2025]
        ///         Also see how to do recursive blocks: http://blog.hyperjeff.net/code?id=335
    
        if (iteration > 5) {
            completionCallback();
            return;
        }
        [self scrollPoint: (CGPoint) { .y = NSMidY([self rectOfRow: newIndex]) - previousMidYViewportOffset }]; /// `scrollPoint:` moves bounds of the enclosing clipView
        runOnMain(0.0, ^{
            if (5 > fabs(
                [self visibleRect].origin.y -
                (NSMidY([self rectOfRow: newIndex]) - previousMidYViewportOffset)
            )) {
                completionCallback();
                return;
            }
           __restorePosition(iteration+1, self, previousMidYViewportOffset, newIndex, completionCallback);
        });
    };

    - (void) reloadWithNewData: (NSArray <NSXMLElement *> *)transUnits {
        
        /// Called by SourceList, when switching files
        
        self->transUnits = transUnits;
        [self bigUpdateAndStuff_OnlyUpdateSorting: NO];
            
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
        
        {
            auto oldIsTranslated = [[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated];
            if (oldIsTranslated == newIsTranslatedState) {
                assert(false); /// We only use this for toggling currently [Nov 2025]
                return;
            }
        }
        
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
        
        /*runOnMain(0.0, ^{*/ /// Breaks enter to start editing next line [Nov 2025]| (Forgot why I wanted to do this in the first place)
        
        /// Show edited row to user
        [self _revealTransUnit: transUnit columns: @[@"state"]];
        
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
    - (void) setTranslation: (NSString *)newString alsoModifyIsTranslated: (BOOL)modifyIsTranslated isTranslated: (BOOL)isTranslated onRowModel: (NSXMLElement *)transUnit {
        
        /// Log
        mflog(@"setTranslation: %@", newString);
        
        /// Guard no edit
        if ([rowModel_getCellModel(transUnit, @"target") isEqual: newString])
            return; /// `controlTextDidBeginEditing:` doesn't work so we do this here. [Oct 2025]
        
        /// Get current state
        auto oldIsTranslated = [[self stateOfRowModel: transUnit] isEqual: kMFTransUnitState_Translated];
        auto oldString = rowModel_getCellModel(transUnit, @"target");
        
        /// Get thing
        auto reallyModifyIsTranslated = modifyIsTranslated && (isTranslated != oldIsTranslated);
        
        /// Prepare undo
        {
            auto undoManager = [getdoc(self) undoManager];
            [[undoManager prepareWithInvocationTarget: self]
                setTranslation: oldString
                alsoModifyIsTranslated: modifyIsTranslated
                isTranslated: oldIsTranslated
                onRowModel: transUnit
            ];
            [undoManager setActionName: @"Edit Translation"];
        }
        
        /// Update datamodel
        _rowModel_setCellModel(transUnit, @"target", newString);
        if (modifyIsTranslated)
            _rowModel_setCellModel(transUnit, @"state", isTranslated ? kMFTransUnitState_Translated : kMFTransUnitState_NeedsReview);
        
        /// Save to disk
        [getdoc(self) writeTranslationDataToFile];
        
        /// Update progress UI
        [getdoc(self)->ctrl->out_sourceList progressHasChanged]; /// Only necessary if the state actually changed [Oct 2025]
        
        /// Show edited row to user
         [self _revealTransUnit: transUnit columns: @[reallyModifyIsTranslated ? @"state" : @"", @"target"]]; /// Order is important. Last takes precedence (I think) [Nov 2025]
             
        /// Reload cells
        {
            [self reloadItem: [self selectedItem] reloadChildren: NO];
            [self reloadItem: [self parentForItem: [self selectedItem]] reloadChildren: NO]; /// See `setIsTranslatedState:`
        }
    }
    
    - (void) _revealTransUnit: (NSXMLElement *)transUnit columns: (NSArray *)colids {
    
        /// Helper made for when our editing methods are called by undoManager [Oct 2025]
    
        /// `Navigate UI` to make transUnit displayed by the TableView
        ///     I think this is only necessary if we're undoing. Otherwise the transUnit we're manipulating will already be on-screen and selected
        NSXMLElement *topLevel;
        {
        
            topLevel = [self topLevelItemContainingItem: transUnit];
            if (!topLevel) {
                /// Remove the filter
                [getdoc(self)->ctrl->out_filterField setStringValue: @""];
                [self updateFilter: @""]; /// Updating `out_filterField` should maybe call this automatically [Nov 2025]
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
            { /// Idea: Also scroll the state-column into-view when toggling it. [Oct 2025]
                for (NSString *colid in colids)
                    if (colid.length)
                        [self scrollColumnToVisible: [self columnWithIdentifier: colid]];
            }
        });
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


    NSString *rowModel_getUIString(TableView *self, NSXMLElement *transUnit, NSString *columnID) {
    
        #define iscol(colid) [columnID isEqual: (colid)]
        
        /// Get model value
        NSString *uiString = rowModel_getCellModel(transUnit, columnID);
        
        /// Get proper model value for @"state"
        ///     This is a bit hacky
        if (iscol(@"state"))
            uiString = [self stateOfRowModel: transUnit]; /// This is the only use of `self` in `rowModel_getUIString` [Nov 2025]
        
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
                    uiString = notesDict[@"Note"] ?: @""; /// Remove everything except @"Note" ... Actually the @"Class" values (e.g. NSMenuItem) may give somewhat useful context, too. Even the uiString-keys (e.g. `placeholderString`) is somewhat useful – Maybe we should add them back? .. But shouldn't be necessary for MMF since we have lots of comments and screenshots.[Nov 2025]
                }
                else
                    assert(false);
            }
        }
        
        /// Add zero-width spaces after periods in the string-key to make NSTextField wrap the lines there.
        if (iscol(@"id"))
            uiString = [uiString stringByReplacingOccurrencesOfString: @"." withString: @".\u200B"];
        
        /// Handle pluralizable strings
        {
            if (rowModel_isPluralParent(transUnit)) {
                if ((0)) {}
                else if (iscol(@"id"))       {}
                else if (iscol(@"source"))   uiString = @"(pluralizable)";
                else if (iscol(@"target")) { uiString = @"(pluralizable)"; } /// We never want the `%#@formatSstring@` to be changed by the translators, so we override it.
                else if (iscol(@"state"))    { if ((0)) uiString = @"(pluralizable)"; }
                else if (iscol(@"note"))     {}
                else                         assert(false);
            }

            if (rowModel_isPluralChild(transUnit)) {

                if (iscol(@"id")) {
                    
                    NSArray *a = [xml_attr(transUnit, @"id").objectValue componentsSeparatedByString: @"|==|"];
                    assert(a.count == 2);
                    
                    NSString *substitutionPath = a[1];
                    assert([substitutionPath hasPrefix: @"substitutions.pluralizable.plural."]);
                    
                    NSString *pluralVariant = [substitutionPath substringFromIndex: @"substitutions.pluralizable.plural.".length];
                    
                    uiString = pluralVariant; /// Just show the variant name (e.g. "one", "other") since it's a child row
                }
                else if (iscol(@"note"))
                    uiString = @""; /// Delete the note cause the parent row already has it.
            }
        }
        
        return uiString;
        #undef iscol
    }


    NSTableCellView *_getCellView(TableView *self, NSTableColumn *tableColumn, id item) {
            
    
        #define iscol(colid) [[tableColumn identifier] isEqual: (colid)]
        
        NSXMLElement *transUnit = item;
            
        /// Measure how many times this is invoked.
        ///     `makeViewWithIdentifier:` is the biggest bottleneck to responsive switching between sidebar items. [Nov 2025]
        if ((0)) mflog(@"viewForTableColumn: (%d)", __invocations++);
            
        NSString *uiString = rowModel_getUIString(self, item, tableColumn.identifier);
        
        /// Override raw state string with colorful symbols / badges
        NSAttributedString *uiStringAttributed  = [[NSAttributedString alloc] initWithString: (uiString ?: @"")];
        NSColor *stateCellBackgroundColor = nil;
        {
            if (iscol(@"state")) {
                if ((0)) {}
                else if ([uiString isEqual: kMFTransUnitState_Translated])      uiStringAttributed = make_green_checkmark(uiString);
                else if ([uiString isEqual: kMFTransUnitState_DontTranslate])   uiStringAttributed = attributed(@"DON'T TRANSLATE");
                else if ([uiString isEqual: kMFTransUnitState_New])             uiStringAttributed = attributed(@"NEW");
                else if ([uiString isEqual: kMFTransUnitState_NeedsReview])     uiStringAttributed = attributed(@"NEEDS REVIEW");
                else {
                    uiStringAttributed = attributed(stringf(@"Error: unknown state: %@", uiString));
                    assert(false);
                }
            }
            
            if (iscol(@"state")) {
                if ((0)) {}
                else if ([uiString isEqual: kMFTransUnitState_Translated])     stateCellBackgroundColor = nil;
                else if ([uiString isEqual: kMFTransUnitState_DontTranslate])  stateCellBackgroundColor = [NSColor systemGrayColor];
                else if ([uiString isEqual: kMFTransUnitState_New])            stateCellBackgroundColor = [NSColor systemBlueColor];
                else if ([uiString isEqual: kMFTransUnitState_NeedsReview])    stateCellBackgroundColor = [NSColor systemOrangeColor];
                else {
                    uiString = stringf(@"Error: unknown state: %@", uiString);
                    assert(false);
                }
            }
        }
        
        /// Create cell
        NSTableCellView *cell = nil;
        {
            
            bool makeSelectable = YES;
            
            if (iscol(@"id")) {
                
                assert([reusableViewIDs containsObject: @"theReusableCell_TableID"]);
                cell = [self makeViewWithIdentifier: @"theReusableCell_TableID" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
                
                /// Configure filename-field
                {
                    NSTextField *filenameField = (id)[cell searchSubviewWithIdentifier: @"filename-field"];
                    if ( /// shouldShowFilename
                        [getdoc(self)->ctrl->out_sourceList allTransUnitsShown] &&
                        !rowModel_isPluralChild(transUnit)
                    ) {
                        filenameField.hidden = NO;
                        NSString *filename = [getdoc(self)->ctrl->out_sourceList filenameForTransUnit: transUnit];
                        [filenameField setStringValue: filename];
                    }
                    else {
                        filenameField.hidden = YES;
                    }
                }

                /// Configure quicklook
                {
                    auto matchingScreenshotPlistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: transUnit];
                
                    NSButton *quickLookButton = (id)[cell searchSubviewWithIdentifier: @"quick-look-button"];
                    mflog(@"quick-look-button base config: %p (row: %ld)", quickLookButton, [self rowForItem: transUnit]);
                    
                    quickLookButton.hidden = !matchingScreenshotPlistEntry;

                    if (matchingScreenshotPlistEntry) {
                        NSButton *quickLookButton = (id)[cell searchSubviewWithIdentifier: @"quick-look-button"];
                        mflog(@"quick-look-button special config: %p (row: %ld)", quickLookButton, [self rowForItem: transUnit]);
                        [quickLookButton setAction: @selector(quickLookButtonPressed:)];
                        [quickLookButton setTarget: self];
                        [quickLookButton mf_setAssociatedObject: @([self rowForItem: item]) forKey: @"rowOfQuickLookButton"];
                    }
                }
            }
            else if (iscol(@"target")) {

                assert([reusableViewIDs containsObject: @"theReusableCell_TableTarget"]);
                cell = [self makeViewWithIdentifier: @"theReusableCell_TableTarget" owner: self]; /// This contains an `MFTextField`
            
                [cell.textField setEditable: !rowModel_isPluralParent(transUnit)];
            }
            else if (iscol(@"state")) {
                
                if (!stateCellBackgroundColor) { /// This is for the `green_checkmark` (Other state cells are handled by `stateCellBackgroundColor`).
                    
                    assert([reusableViewIDs containsObject: @"theReusableCell_Table"]);
                    cell = [self makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                    
                    makeSelectable = false;                 /// The `green_checkmark` disappears when selected, so we disable selection. [Oct 2025]
                }

                else {
                    
                    assert([reusableViewIDs containsObject: @"theReusableCell_TableState"]);
                    cell = [self makeViewWithIdentifier: @"theReusableCell_TableState" owner: self];
                    
                    { /// Style copies Xcode xcloc editor. Rest of the style defined in IB.
                        cell.nextKeyView.wantsLayer = YES;
                        cell.nextKeyView.layer.cornerRadius = 3;
                        cell.nextKeyView.layer.borderWidth  = 1;
                    }

                    cell.nextKeyView.layer.borderColor     = [stateCellBackgroundColor CGColor];
                    cell.nextKeyView.layer.backgroundColor = [[stateCellBackgroundColor colorWithAlphaComponent: 0.15] CGColor];
                }
            }
            
            else {
                
                assert(iscol(@"source") || iscol(@"note"));
            
                assert([reusableViewIDs containsObject: @"theReusableCell_Table"]);
                cell = [self makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                
                [cell.textField setLineBreakStrategy: NSLineBreakStrategyNone]; /// disable `NSLineBreakStrategyPushOut` since the `MFInvisiblesTextView_Overlay` doesn't do that. (maybe we could enable it there but whatever. [Nov 2025])
                
                /// Clean up `@"MFInvisiblesTextView_Overlay"`
                MFInvisiblesTextView *overlay = [cell.textField mf_associatedObjectForKey: @"MFInvisiblesTextView_Overlay"];
                if ((overlay && !overlay.hidden) || cell.textField.hidden) {
                    assert(false); /// Shouldn't happen if our code works correctly.
                    [overlay setHidden: YES];
                    [cell.textField setHidden: NO];
                }
                
            }
            
            /// Common config
            cell.textField.delegate      = (id)self;
            cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textField.selectable    = makeSelectable;
            
            /// SEt da string!!
            [cell.textField setAttributedStringValue: uiStringAttributed];
        }
        
        /// Validate
        if (!cell) {
            assert(false);
            mflog(@"nill cell %@", transUnit);
        }
        
        /// Return
        return cell;
        #undef iscol
    }

    - (NSView *) outlineView: (NSOutlineView *)outlineView viewForTableColumn: (NSTableColumn *)tableColumn item: (id)item {
        return _getCellView(self, tableColumn, item); /// Factored out `_getCellView()` to implement `heightOfRowByItem:`, but gave up on that [Nov 2025]
    }

    #pragma mark - NSOutlineView subclass
    
    - (void) reloadData {
        [super reloadData];
        [self expandItem: nil expandChildren: YES]; /// mfunexpand – Expand all items by default. || We're also using `reloadDataForRowIndexes:` additionally to `reloadData`, but overriding that doesn't seem necessary to keep the items expanded [Oct 2025]
        __invocations = 1;
        __invocation_rowheight = 1;
    }
    
    - (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes {
        mflog(@"ReloadData with indexes: %@ %@", rowIndexes, columnIndexes);
        [super reloadDataForRowIndexes: rowIndexes columnIndexes: columnIndexes];
    }

    #pragma mark - NSOutlineViewDelegate
    
    - (BOOL)outlineView:(NSOutlineView *)outlineView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString {
    
        return NO; /// Turn off type-to-select. Not useful here I think and sometimes trigger it accidentally [Nov 2025]
    
    }

    #if 1
        /// Returning 50 here makes `viewForTableColumn:` be called much less after switching files, which makes the sidebar more responsive. Not sure why it causes `viewForTableColumn:` to be called so much less. We are using `self.usesAutomaticRowHeights = YES` [Nov 2025, macOS 26 Tahoe]
        /// Downside:
        ///   Scrolling *up* into unloaded rows is jittery when you do this.
        /// Also see: https://christiantietze.de/posts/2022/11/nstableview-variable-row-heights-broken-macos-ventura-13-0/
        ///   This says to use `noteHeightOfRowsWithIndexesChanged:` , but it won't do anything according to my testing and the heightOfRowByItem: docs.
        /// I also tried `prepareContentInRect:`, but This is only called while scrolling, not immediately after switching files. [Nov 2025]
        /// Tried actually calculating real rowHeights here to make things more responsive without creating too much jitter.
        ///     Conclusion – giving up on this:
        ///         - The tableView calls this for *all* rows before it displays, so this needs to be either very fast or you have to do lazy-loading yourself somehow.
        ///         - The slowest part in the current impl [Nov 2025] is `layoutSubtreeIfNeeded`. If we calculated the textSizes directly it looks like we could make it a lot faster. (But not sure if fast enough to significantly improve UX) (And this would be annoying to do and maintain)
        ///             -> Just turning this off and letting things be a little slow
        ///     UPDATE:
        ///         Actually the jitter is also really bad if we don't implement this [macOS Tahoe, Nov 2025], so maybe we should just return a constant to at least make it faster to load? ... ah I'll just keep the default behavior and hope Apple improves it in the future.
        ///     UPDATE 2: Could fix the jitter by overriding `[TableRowView setFrame:]` [Nov 2025]
        
        - (CGFloat) outlineView: (NSOutlineView *)outlineView heightOfRowByItem: (id)item {
            
            return _defaultRowHeight;
            
            #if 0
                if ((0))
                {
                __invocation_rowheight++;
                
                static NSMutableDictionary *storage = nil;
                if (!storage) {
                    storage = [NSMutableDictionary new];
                    {
                        storage[@"id"]      = [self makeViewWithIdentifier: @"theReusableCell_TableID" owner: self];
                        storage[@"source"]  = [self makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                        storage[@"target"]  = [self makeViewWithIdentifier: @"theReusableCell_TableTarget" owner: self];
                        storage[@"note"]    = [self makeViewWithIdentifier: @"theReusableCell_Table" owner: self];
                    }
                    /// We ignore the `@"state"` column, since that should never affect the height of the row [Nov 2025]
                }
                
                CGFloat rowHeight = 0;
                
                auto colids = @[@"id", @"source", @"target", @"note"];
                for (NSString *colid in colids) {
                
                    NSTableCellView *cellView = _getCellView(self, [self tableColumnWithIdentifier: colid], item, storage[colid]);
                    
                    { /// Not sure if necessary
                        [cellView setNeedsLayout: YES];
                        [cellView layoutSubtreeIfNeeded];
                    }
                    
                    rowHeight = MAX(rowHeight, cellView.frame.size.height);
                    
                }
                
                mflog(@"Calculated rowHeight: %f (row: %ld) (%d)", rowHeight, [self rowForItem: item], __invocation_rowheight);
                
                return rowHeight;
                }
            #endif
        }
        
    #endif

    - (void) outlineViewSelectionDidChange: (NSNotification *)notification {
        if ( /// Works without this if-statement but shows "this will raise soon" warning (macOS Sequoia)
            [QLPreviewPanel sharedPreviewPanelExists] &&
            [[QLPreviewPanel sharedPreviewPanel] isVisible]
        ) {
            [QLPreviewPanel.sharedPreviewPanel reloadData];
        }
    }
    
    - (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item {
        return [TableRowView new];
    }

    #pragma mark - Quick Look
    
        /// See Apple `QuickLookDownloader` sample project: https://developer.apple.com/library/archive/samplecode/QuickLookDownloader/Introduction/Intro.html
        
        - (id) ql_selectedItem {
            /// Use this instead of `[self selected...` for the quickLook logic. [Nov 2025]
            return [self parentForItem: [self selectedItem]] ?: [self selectedItem];
        }
        - (NSInteger) ql_selectedRow {
            return [self rowForItem: [self ql_selectedItem]];
        }
        
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
                    NSRect rowRect = [self rectOfRow: [self ql_selectedRow]];
                    NSRect sourceRect = NSIntersectionRect(colRect, rowRect);
                    sourceFrame_Window = [self convertRect: sourceRect toView: nil];
                }
                else {
                    auto selectedRow = [self ql_selectedRow];
                    if (selectedRow == -1) return NSZeroRect; /// Happens when no row is selected and then you click the x button on the QL panel. [Nov 2025]
                    NSTableCellView *cellView = [self viewAtColumn: [self columnWithIdentifier: @"id"] row: selectedRow makeIfNecessary: NO];
                    NSButton *quickLookButton = (id)[cellView searchSubviewWithIdentifier: @"quick-look-button"]; /// We previously used `[cell nextKeyView];`. I thought it worked but here it didn't [Oct 2025]
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
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self ql_selectedItem]];
                return [plistEntry[@"screenshots"] count];
            };

            - (id <QLPreviewItem>) previewPanel: (QLPreviewPanel *)panel previewItemAtIndex: (NSInteger)index {
                
                mflog(@"previewItemAtIndex: called with index: %ld", index);
                
                NSDictionary *plistEntry = [self _localizedStringsDataPlist_GetEntryForRowModel: [self ql_selectedItem]];
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
                ///         If the `annotatedImagePath` is a unique identifier for the annotated image, we can  use it to cache the annotatedImage. [Oct 2025]
                
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

