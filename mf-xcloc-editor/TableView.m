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

#define kTransUnitState_Translated      @"translated"
#define kTransUnitState_DontTranslate   @"mf_dont_translate"
#define kTransUnitState_New             @"new"
#define kTransUnitState_NeedsReview     @"needs-review-l10n"
static auto _stateOrder = @[ /// Order of the states to be used for sorting [Oct 2025]
    kTransUnitState_New,
    kTransUnitState_NeedsReview,
    kTransUnitState_Translated,
    kTransUnitState_DontTranslate
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
    
    #pragma mark - Sorting
    
    - (void) tableView: (NSTableView *)tableView sortDescriptorsDidChange: (NSArray<NSSortDescriptor *> *)oldDescriptors { /// This is called when the user clicks the column headers to sort them.
        [self update_rowModelSorting];
        [self reloadData];
    }

    #pragma mark - Filtering
    
    static NSString *_filterString = nil;
    - (void) updateFilter: (NSString *)filterString {
        _filterString = filterString;
        [self update_rowModels];
        [self reloadData];
    }

    #pragma mark - Data



    static NSMutableArray<NSXMLElement *> *_transUnits = nil; /// Main dataModel displayed by this table.
    
    - (NSXMLElement *) rowModel: (NSInteger)row {
        return _transUnits[row];
    }

    - (void) update_rowModels {
        
        /// Filter
        NSXMLElement *body = (id)[self.data childAtIndex: 1]; /// This makes assumptions based on the tests we do in `reloadWithNewData:`
        if (![_filterString length]) _transUnits = [[body children] mutableCopy];
        else {
            _transUnits = [NSMutableArray new];
            for (NSXMLElement *transUnit in body.children) {
                {
                    assert(isclass(transUnit, NSXMLElement));
                    assert([transUnit.name isEqual: @"trans-unit"]);
                }
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
                    [(NSMutableArray *)_transUnits addObject: transUnit];
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
        
        [_transUnits sortUsingComparator: ^NSComparisonResult(NSXMLElement *i, NSXMLElement *j) {
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
                    return kTransUnitState_DontTranslate;
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
                if ([newValue isEqual: kTransUnitState_DontTranslate])
                    xml_attr(transUnit, @"translate").objectValue = @"no";
                else
                    xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue = newValue;
            }
        else assert(false);
    };

    - (void) reloadWithNewData: (NSXMLElement *)data {
        
        /** Validate data
            Should look like this:
            ```
            <file original="App/UI/Main/Base.lproj/Main.storyboard" source-language="en" target-language="de" datatype="plaintext">
                <header>
                  <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="16.1" build-num="16B5001e"/>
                </header>
                <body>...
            ```
        */
        
        NSDictionary<NSString *, NSXMLNode *> *attrs;
        
        /// Validate `<file>`
        
        assert(data != nil);
        assert([data.name isEqual: @"file"]);
        assert(data.childCount == 2);
        assert([[data childAtIndex: 0].name isEqual: @"header"]);
        assert([[data childAtIndex: 1].name isEqual: @"body"]);
        assert(isclass([data childAtIndex: 0], NSXMLElement));
        assert(isclass([data childAtIndex: 1], NSXMLElement));
        
        
        attrs = xml_attrdict(data);
        assert(attrs[@"original"].objectValue           );
        assert(attrs[@"source-language"].objectValue    );
        assert(attrs[@"target-language"].objectValue    );
        assert(attrs[@"datatype"].objectValue           );
        
        mflog("Attributes: %@", attrs);
        
        /// Validate `<header>`
        
        NSXMLNode *header = [data childAtIndex:0];
        assert(header.childCount == 1);
        NSXMLNode *tool = [header childAtIndex:0];
        assert([tool.name isEqual: @"tool"]);
        assert( isclass(tool, NSXMLElement) );
        attrs = xml_attrdict((NSXMLElement *)tool);
        assert([attrs[@"tool-id"].objectValue       isEqual: @"com.apple.dt.xcode"] );
        assert([attrs[@"tool-name"].objectValue     isEqual: @"Xcode"]              );
        if ((0)) { /// We hope our code can support other versions, too?
            assert([attrs[@"tool-version"].objectValue  isEqual: @"16.1"]               );
            assert([attrs[@"build-num"].objectValue     isEqual: @"16B5001e"]           );
        }
        
        /// Store data
        self->_data = data;
        
        /// Transform to datamodel
        [self update_rowModels];
        
        /// Reload
        [self reloadData];
    }
    
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
                rowModel_setCellModel(transUnit, @"state", kTransUnitState_Translated);
            }
            else if ([menuItem.identifier isEqual: @"mark_for_review"]) {
                rowModel_setCellModel(transUnit, @"state", kTransUnitState_NeedsReview);
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
            [rowModel_getCellModel(transUnit, @"state") isEqual: kTransUnitState_Translated] &&
            [menuItem.identifier isEqual: @"mark_as_translated"]
        ) {
            return NO;
        }
        if (
            [rowModel_getCellModel(transUnit, @"state") isEqual: kTransUnitState_NeedsReview] &&
            [menuItem.identifier isEqual: @"mark_for_review"]
        ) {
            return NO;
        }
        
        return YES;
    }

    #pragma mark - NSTableView

    #pragma mark - NSTableViewDataSource

    - (NSInteger) numberOfRowsInTableView: (NSTableView *)tableView {
        return [_transUnits count];
    }
    
    - (NSView *) tableView: (NSTableView *)tableView viewForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row {
    
        #define iscol(colid) [[tableColumn identifier] isEqual: (colid)]
        
        NSXMLElement *transUnit = [self rowModel: row];
        
        /// Get model value
        NSString *uiString = rowModel_getCellModel(transUnit, [tableColumn identifier]);
        
        /// Special stuff for `<target>` column
        void (^editingCallback)(NSString *newString) = nil;
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
                else if ([uiString isEqual: kTransUnitState_Translated]) {
                    auto image = [NSImage imageWithSystemSymbolName: @"checkmark.circle" accessibilityDescription: uiString]; /// Fixme: This disappears when you double-click it.
                    auto textAttachment = [NSTextAttachment new]; {
                        [textAttachment setImage: image];
                    }
                    uiStringAttributed = [NSAttributedString attributedStringWithAttachment: textAttachment attributes: @{
                        NSForegroundColorAttributeName: [NSColor systemGreenColor]
                    }];
                }
                else if ([uiString isEqual: kTransUnitState_DontTranslate]) {
                    uiStringAttributed = attributed(@"DON'T TRANSLATE");
                    stateCellBackgroundColor = [NSColor systemGrayColor];
                }
                else if ([uiString isEqual: kTransUnitState_New]) {
                    uiStringAttributed = attributed(@"NEW");
                    stateCellBackgroundColor = [NSColor systemBlueColor];
                }
                else if ([uiString isEqual: kTransUnitState_NeedsReview]) {
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
                cell = [tableView makeViewWithIdentifier: @"theReusableCell_Table" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
                cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
                cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
                cell.textField.selectable = YES;
                
                if (iscol(@"target")) {
                    editingCallback = ^void (NSString *newString) {
                        mflog(@"<target> edited: %@", newString);
                        rowModel_setCellModel(transUnit, @"target", newString);
                        [appdel writeTranslationDataToFile];
                        
                    };
                    [cell.textField setEditable: targetCellShouldBeEditable]; /// FIxme: Editable disables the intrinsic height, causing content to be truncated. [Oct 2025]
                }
            }
            
            [cell.textField setAttributedStringValue: uiStringAttributed];
            [cell.textField mf_setAssociatedObject: editingCallback forKey: @"editingCallback"];
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

