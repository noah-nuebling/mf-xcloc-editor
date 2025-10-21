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
        self.gridStyleMask = NSTableViewSolidVerticalGridLineMask | NSTableViewSolidHorizontalGridLineMask;
        self.style = NSTableViewStyleFullWidth;
        self.usesAutomaticRowHeights = YES;
        
        /// Register ReusableViews
        [self registerNib: [[NSNib alloc] initWithNibNamed: @"ReusableViews" bundle: nil]  forIdentifier: @"theReusableCell_Table"];
        
        /// Add columns
        {
            auto mfui_tablecol = ^NSTableColumn *(NSString *identifier, NSString *title) {
                auto v = [[NSTableColumn alloc] initWithIdentifier: identifier];
                v.title = title;
                return v;
            };
            [self addTableColumn: mfui_tablecol(@"id",     @"ID")];
            [self addTableColumn: mfui_tablecol(@"source", @"Source")];
            [self addTableColumn: mfui_tablecol(@"target", @"Target")];
            [self addTableColumn: mfui_tablecol(@"state",  @"State")];
            [self addTableColumn: mfui_tablecol(@"note",   @"Note")];
        }
        
        /// Add menu
        {
            auto mfui_menu = ^NSMenu * (NSArray<NSMenuItem *> *items) {
                auto v = [NSMenu new];
                for (id item in items) [v addItem: item];
                return v;
            };
            auto mfui_item = ^NSMenuItem *(NSString *identifier, NSString *title) {
                auto v = [NSMenuItem new];
                v.identifier = identifier;
                v.title = title;
                v.action = @selector(tableMenuItemClicked:);
                v.target = self;
                return v;
            };
            
            self.menu = mfui_menu(@[
                mfui_item(@"mark_as_reviewed", @"Mark as Reviewed"),
                mfui_item(@"mark_for_review",  @"Mark for Review"),
            ]);
        }
        
        /// Return
        return self;
    }

    #pragma mark - Menu Items
    
    - (void) tableMenuItemClicked: (NSMenuItem *)menuItem {
        
        mflog(@"menuItem clicked: %@ %ld", menuItem, self.clickedRow);
        
        NSXMLElement *transUnit = [self rowModel: self.clickedRow];
        
        if ((0)) {}
            else if ([menuItem.identifier isEqual: @"mark_as_reviewed"]) {
                getNode(transUnit, @"state").objectValue = @"translated";
            }
            else if ([menuItem.identifier isEqual: @"mark_for_review"]) {
                getNode(transUnit, @"state").objectValue = @"needs-review-l10n";
            }
        else assert(false);
        
        [self reloadData];
        [appdel writeTranslationDataToFile];
    }
    
    - (BOOL) validateMenuItem: (NSMenuItem *)menuItem {
        
        return YES;
    }

    #pragma mark - Data


     NSXMLNode *getNode(NSXMLElement */*rowModel*/transUnit, NSString *nodeid) {
            if ((0)) {}
                else if ([nodeid isEqual: @"id"])        return xml_attr(transUnit, @"id");
                else if ([nodeid isEqual: @"source"])    return xml_childnamed(transUnit, @"source");
                else if ([nodeid isEqual: @"target"])    return xml_childnamed(transUnit, @"target");
                else if ([nodeid isEqual: @"state"])     return xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state");
                else if ([nodeid isEqual: @"translate"]) return xml_attr(transUnit, @"translate");
                else if ([nodeid isEqual: @"note"])      return xml_childnamed(transUnit, @"note");
            else assert(false);
        };

    - (NSXMLElement *) rowModel: (NSInteger)row {
        NSXMLElement *body = (id)[self.data childAtIndex: 1]; /// This makes assumptions based on the tests we do in `setData:`
        NSXMLNode *transUnit = [body childAtIndex: row];
        assert(isclass(transUnit, NSXMLElement));
        return (NSXMLElement *)transUnit;
    }

    - (void)setData:(NSXMLElement *)data {
        
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
        
        /// Validate <file>
        
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
        
        /// Validate <header>
        
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
        _data = data;
    }

    #pragma mark - NSTableView

    #pragma mark - NSTableViewDataSource

    - (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
        NSXMLElement *body = (id)[self.data childAtIndex: 1]; /// This makes assumptions based on the tests we do in `setData:`
        auto result = [body childCount];
        return result;
    }
    
    - (NSView *) tableView: (NSTableView *)tableView viewForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row {
    
        #define iscol(colid) [[tableColumn identifier] isEqual: (colid)]
    
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"theReusableCell_Table" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
        cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
        cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textField.selectable = YES;
        
        NSXMLElement *transUnit = [self rowModel: row];
        
        assert(isclass(transUnit, NSXMLElement));
        assert([transUnit.name isEqual: @"trans-unit"]);
        
        /// Get uiString
        NSString *uiString = @"<Error in code>";
        if ((0)) {}
            else if (iscol(@"id"))     uiString = getNode(transUnit, @"id").objectValue;
            else if (iscol(@"source")) uiString = getNode(transUnit, @"source").objectValue;
            else if (iscol(@"target")) uiString = getNode(transUnit, @"target").objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
            else if (iscol(@"note"))   uiString = getNode(transUnit, @"note").objectValue;
            else if (iscol(@"state")) {
                if ([getNode(transUnit, @"translate").objectValue isEqual: @"no"])
                    uiString = @"mf_dont_translate";
                else
                    uiString = getNode(transUnit, @"state").objectValue ?: @""; /// `?:` cause `<target>` sometimes doesnt' exist [Oct 2025]
            }
        else assert(false);
        
        
        /// Special stuff for target column
        void (^editingCallback)(NSString *newString) = nil;
        if (iscol(@"target")) {
            editingCallback = ^void (NSString *newString) {
                mflog(@"<target> edited: %@", newString);
                [appdel writeTranslationDataToFile];
                
            };
            [cell.textField setEditable: iscol(@"target")]; /// FIxme: Editable disables the intrinsic height, causing content to be truncated. [Oct 2025]
        }
        
        /// Validate uiString
        if (iscol(@"state"))    assert(!uiString || isclass(uiString, NSString));
        else                    assert(isclass(uiString, NSString));
        
        /// Handle pluralizable strings
        {
            if ([xml_childnamed(transUnit, @"source").objectValue containsString: @"%#@"]) {
                if ((0)) {}
                    else if (iscol(@"id"))       ;
                    else if (iscol(@"source"))   uiString = @"(pluralizable)";
                    else if (iscol(@"target")) { uiString = @"(pluralizable)"; [cell.textField setEditable: NO]; }
                    else if (iscol(@"state"))    uiString = @"(pluralizable)";
                    else if (iscol(@"note"))     ;
                else assert(false);
            }
            
            if ([xml_attr(transUnit, @"id").objectValue containsString: @"|==|"]) {
                
                if (iscol(@"id")) {
                    NSArray *a = [xml_attr(transUnit, @"id").objectValue componentsSeparatedByString: @"|==|"]; assert(a.count == 2);
                    NSString *baseKey = a[0];
                    NSString *substitutionPath = a[1];
                    assert([substitutionPath hasPrefix: @"substitutions.pluralizable.plural."]);
                    NSString *pluralVariant = [substitutionPath substringFromIndex: @"substitutions.pluralizable.plural.".length];
                    uiString = stringf(@"%@ (%@)", baseKey, pluralVariant);
                }
                else if (iscol(@"note")) uiString = @"";
            }
        }
        
        /// Override raw string with colorful symbols / badges
        
        NSAttributedString *uiStringAttributed  = [[NSAttributedString alloc] initWithString: (uiString ?: @"")];
        
        #define attributed(str) [[NSAttributedString alloc] initWithString: (str)]
        
        if (iscol(@"state")) {
            if ((0)) {}
                else if ([uiString isEqual: @"translated"]) {
                    auto image = [NSImage imageWithSystemSymbolName: @"checkmark.circle" accessibilityDescription: uiString];
                
                    auto textAttachment = [NSTextAttachment new];
                    [textAttachment setImage: image];
                    
                    uiStringAttributed = [NSAttributedString attributedStringWithAttachment: textAttachment attributes: @{
                        NSForegroundColorAttributeName: [NSColor systemGreenColor]
                    }];
                }
                else if ([uiString isEqual: @"mf_dont_translate"]) {
                    uiStringAttributed = attributed(@"DONT TRANSLATE");
                }
                else if ([uiString isEqual: @"new"]) {
                    uiStringAttributed = attributed(@"Newwww");
                }
                else if ([uiString isEqual: @"needs-review-l10n"]) {
                    uiStringAttributed = attributed(@"Needs Reviewwww");
                }
                else if ([uiString isEqual: @"(pluralizable)"]) {
                    uiStringAttributed = attributed(@"");
                }
            else assert(false);
        }
        
        /// Configure cell
        [cell.textField setAttributedStringValue: uiStringAttributed];
        [cell.textField mf_setAssociatedObject: editingCallback forKey: @"editingCallback"];
        
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

