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
        
        return self;
    }

    #pragma mark - Data

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
        
        NSDictionary *attrs;
        
        /// Validate <file>
        
        assert(data != nil);
        assert([data.name isEqual: @"file"]);
        assert(data.childCount == 2);
        assert([[data childAtIndex: 0].name isEqual: @"header"]);
        assert([[data childAtIndex: 1].name isEqual: @"body"]);
        assert(isclass([data childAtIndex: 0], NSXMLElement));
        assert(isclass([data childAtIndex: 1], NSXMLElement));
        
        
        attrs = xml_attrdict(data);
        assert(attrs[@"original"]           );
        assert(attrs[@"source-language"]    );
        assert(attrs[@"target-language"]    );
        assert(attrs[@"datatype"]           );
        
        mflog("Attributes: %@", attrs);
        
        /// Validate <header>
        
        NSXMLNode *header = [data childAtIndex:0];
        assert(header.childCount == 1);
        NSXMLNode *tool = [header childAtIndex:0];
        assert([tool.name isEqual: @"tool"]);
        assert( isclass(tool, NSXMLElement) );
        attrs = xml_attrdict((NSXMLElement *)tool);
        assert([attrs[@"tool-id"]       isEqual: @"com.apple.dt.xcode"] );
        assert([attrs[@"tool-name"]     isEqual: @"Xcode"]              );
        if ((0)) { /// We hope our code can support other versions, too?
            assert([attrs[@"tool-version"]  isEqual: @"16.1"]               );
            assert([attrs[@"build-num"]     isEqual: @"16B5001e"]           );
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
    
        #define iscol(colid) [[tableColumn identifier] isEqual: (@"" colid)]
    
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"theReusableCell_Table" owner: self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
        cell.textField.delegate = (id)self; /// Optimization: Could prolly set this once in IB [Oct 2025]
        cell.textField.lineBreakMode = NSLineBreakByWordWrapping;
        
        NSXMLElement *body = (id)[self.data childAtIndex: 1]; /// This makes assumptions based on the tests we do in `setData:`
        NSXMLNode *transUnit = [body childAtIndex: row];
        
        assert(isclass(transUnit, NSXMLElement));
        assert([transUnit.name isEqual: @"trans-unit"]);
        
        NSDictionary<NSString *, id> *attrs = xml_attrdict((NSXMLElement *)transUnit);
        
        NSString *uiString = @"<Error in code>";
        
        void (^editingCallback)(NSString *newString) = nil;
        
        if ((0)) {}
            else if (iscol("id")) {
                uiString = attrs[@"id"];
            }
            else if (iscol("source")) {
                NSXMLNode *ch =  xml_childnamed(transUnit, @"source");
                uiString = ch.objectValue;
            }
            else if (iscol("target")) {
                NSXMLNode *ch = xml_childnamed(transUnit, @"target");
                uiString = ch.objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
                editingCallback = ^void (NSString *newString) {
                    ch.objectValue = newString;
                    mflog(@"<target> edited: %@", newString);
                    [appdel writeTranslationDataToFile];
                    
                };
                [cell.textField setEditable: iscol(@"target")];
            }
            else if (iscol("state")) {
                NSXMLNode *ch = xml_childnamed(transUnit, @"target");
                uiString =  xml_attr((NSXMLElement *)ch, "state") ?: @""; /// ?: cause `<target>` sometimes doesnt' exist [Oct 2025]
            }
            else if (iscol("note")) {
                NSXMLNode *ch = xml_childnamed(transUnit, @"note");
                uiString = ch.objectValue;
            
            }
        else assert(false);
        
        /// Validate uiString
        if (iscol("state")) assert(!uiString || isclass(uiString, NSString));
        else                assert(isclass(uiString, NSString));
        
        /// Handle pluralizable strings
        {
            if ([xml_childnamed(transUnit, @"source").objectValue containsString: @"%#@"]) {
                if ((0)) {}
                    else if (iscol("id"))       ;
                    else if (iscol("source"))   uiString = @"(pluralizable)";
                    else if (iscol("target")) { uiString = @"(pluralizable)"; [cell.textField setEditable: NO]; }
                    else if (iscol("state"))    uiString = @"";
                    else if (iscol("note"))     ;
                else assert(false);
            }
            
            if ([attrs[@"id"] containsString: @"|==|"]) {
                
                if (iscol("id")) {
                    NSArray *a = [attrs[@"id"] componentsSeparatedByString: @"|==|"]; assert(a.count == 2);
                    NSString *baseKey = a[0];
                    NSString *substitutionPath = a[1];
                    assert([substitutionPath hasPrefix: @"substitutions.pluralizable.plural."]);
                    NSString *pluralVariant = [substitutionPath substringFromIndex: @"substitutions.pluralizable.plural.".length];
                    uiString = stringf(@"%@ (%@)", baseKey, pluralVariant);
                }
                else if (iscol("note")) uiString = @"";
            }
        }
        
        
        /// Configure cell
        [cell.textField setStringValue: uiString ?: @""];
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
        ((void (^)(NSString *))[textField mf_associatedObjectForKey: @"editingCallback"])(textField.stringValue);
    }
    


@end

