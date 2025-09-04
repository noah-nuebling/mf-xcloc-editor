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
            auto mftablecol = ^NSTableColumn *(NSString *identifier, NSString *title) {
                auto v = [[NSTableColumn alloc] initWithIdentifier: identifier];
                v.title = title;
                return v;
            };
            [self addTableColumn: mftablecol(@"id",     @"ID")];
            [self addTableColumn: mftablecol(@"source", @"Source")];
            [self addTableColumn: mftablecol(@"target", @"Target")];
            [self addTableColumn: mftablecol(@"state",  @"State")];
            [self addTableColumn: mftablecol(@"note",   @"Note")];
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
        
        Log("Attributes: %@", attrs);
        
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
    
    - (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"theReusableCell_Table" owner:self]; /// [Jun 2025] What to pass as owner here? Will this lead to retain cycle?
        
        NSXMLElement *body = (id)[self.data childAtIndex: 1]; /// This makes assumptions based on the tests we do in `setData:`
        NSXMLNode *transUnit = [body childAtIndex: row];
        
        assert( isclass(transUnit, NSXMLElement) );
        assert( [transUnit.name isEqual: @"trans-unit"] );
        
        NSDictionary *attrs = xml_attrdict((NSXMLElement *)transUnit);
        NSArray <NSXMLNode *> * childs = [transUnit children];
        
        #define col(colid) \
            else if ([[tableColumn identifier] isEqual: (@colid)])
        
        #define ret(val) ({ result = (val); goto end; })
        
        NSString *result = @"<Error in code>";
        
        if ((0)) {}
        col("id")     {
            id val = attrs[@"id"];                                      assert(isclass(val, NSString));
            ret(val);
        }
        col("source") {
            NSXMLNode *source =  xml_childnamed(transUnit, @"source");
            id val = source.objectValue;                                assert(isclass(val, NSString));
            ret(val);
        }
        col("target") {
            NSXMLNode *target = xml_childnamed(transUnit, @"target");  if (!target) ret(@"");                      /// <target> sometimes doesnt' exist.
            id val = target.objectValue;                               assert(isclass(val, NSString));
            ret(val);
        }
        col("state")  {
            NSXMLNode *target = xml_childnamed(transUnit, @"target");  if (!target) ret(@""); assert(isclass(target, NSXMLElement));
            id val =  xml_attr((NSXMLElement *)target, "state");       assert(!val || isclass(val, NSString));
            ret(val);
        }
        col("note")   {
            NSXMLNode *note = xml_childnamed(transUnit, @"note");
            id val = note.objectValue;                                  assert(isclass(val, NSString));
            ret(val);
        
        }
        else assert(false);
        
        #undef col
        #undef ret
        
        end:
        
        [cell.textField setStringValue: result ?: @""];
        
        return cell;
    }

    #pragma mark - NSTableViewDelegate

    - (void) tableView:(NSTableView *) tableView didClickTableColumn:(NSTableColumn *) tableColumn {
        Log(@"Table column '%@' clicked!", tableColumn.title);
    }


@end

