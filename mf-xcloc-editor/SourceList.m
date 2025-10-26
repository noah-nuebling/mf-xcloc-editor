//
//  SourceList.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

/// See:
///     https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/OutlineView/Articles/AboutOutlineViews.html#//apple_ref/doc/uid/20000107-111039

#import "SourceList.h"
#import "Utility.h"
#import "AppDelegate.h"
#import "XclocDocument.h"
#import "RowUtils.h"
#import "MFUI.h"
#import "NSObject+Additions.h"

@interface File : NSObject
    {
        @public
        NSArray<NSXMLElement *> *transUnits;
        NSString *path;
    }
@end
@implementation File @end
File *File_Make(NSArray<NSXMLElement *> *transUnits, NSString *path) {
    auto f = [File new];
    f->transUnits = transUnits;
    f->path = path;
    return f;
}

#define kMFPath_AllDocuments @"All Project Files"


@implementation SourceList
    {
    

        NSMutableArray <File *> *files;
        NSArray<NSXMLElement *> *_transUnitsFromAllFiles; /// Gives each transUnit a unique ID, which we need for undo/redo [Oct 2025]
    }

    #pragma mark - Lifecycle

    - (instancetype) initWithFrame: (NSRect)frameRect {
    
        self = [super initWithFrame: frameRect];
        if (!self) return nil;
        
        self.delegate   = self; /// See TableView.m for discussion [Jun 2025]
        self.dataSource = self;
        
        /// Configure style
        self.style = NSTableViewStyleSourceList;
        self.allowsColumnReordering = NO;
        self.headerView = nil;
        self.allowsEmptySelection = NO;
        self.rowSizeStyle = NSTableViewRowSizeStyleDefault;
        
        /// Layout
        self.usesAutomaticRowHeights = YES;
        
        /// Configure columns
        [self addTableColumn: ({
            auto col = [[NSTableColumn alloc] initWithIdentifier: @"thecolumn"];
            col.title = @"Col1";
            col;
        })];
        
        /// Register reusable views
        ///     It seems you need to use nib files to use the native mechanism for reusing views? (`makeViewWithIdentifier:owner:`)
        [self registerNib: [[NSNib alloc] initWithNibNamed: @"ReusableViews" bundle: nil] forIdentifier:@"theReusableCell_Outline"];
        
        return self;
    }

    #pragma mark - Data

    - (void) setXliffDoc: (NSXMLDocument *)xliffDoc {
        
        /// Validate doc
        
        assert( [xliffDoc.version           isEqual: @"1.0"] );
        assert( [xliffDoc.characterEncoding isEqual: @"UTF-8"] ); /// Not sure these things make any sense validating
        
        /// Validate xliff node
        
        NSXMLNode *xliff = [xliffDoc rootElement];
        
        assert( [xliff.name isEqual: @"xliff"] );
        assert( isclass(xliff, NSXMLElement) );
        auto attrs = xml_attrdict((NSXMLElement *)xliff);
        
        if ((0)) assert( [attrs[@"xmlns"].objectValue     isEqual: @"urn:oasis:names:tc:xliff:document:1.2"] );         /// Present in the xml text but not here
        if ((0)) assert( [attrs[@"xmlns:xsi"].objectValue isEqual: @"http://www.w3.org/2001/XMLSchema-instance"] ); /// Present in the xml text but not here
        assert( [attrs[@"version"].objectValue            isEqual: @"1.2" ] );
        assert( [attrs[@"xsi:schemaLocation"].objectValue isEqual: @"urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd"] );
        
        /// Validate & store xliff node children (files)
        assert( allsatisfy(xliff.children, xliff.childCount, x, isclass(x, NSXMLElement)) );
        assert( allsatisfy(xliff.children, xliff.childCount, x, [x.name isEqual: @"file"]) );
        
        /// Unwrap the transUnits
        auto transUnitsFromAllFiles = [NSMutableArray new];
        self->files = [NSMutableArray new];
        NSString *sourceLanguage = nil;
        NSString *targetLanguage = nil;
        for (NSXMLElement *file in xliff.children) {
        
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
            {
                NSDictionary<NSString *, NSXMLNode *> *attrs;
                
                /// Validate `<file>`
                
                assert(file != nil);
                assert([file.name isEqual: @"file"]);
                assert(file.childCount == 2);
                assert([[file childAtIndex: 0].name isEqual: @"header"]);
                assert([[file childAtIndex: 1].name isEqual: @"body"]);
                assert(isclass([file childAtIndex: 0], NSXMLElement));
                assert(isclass([file childAtIndex: 1], NSXMLElement));
                
                
                attrs = xml_attrdict(file);
                assert(attrs[@"original"].objectValue           );
                assert(attrs[@"source-language"].objectValue    );
                assert(attrs[@"target-language"].objectValue    );
                assert(attrs[@"datatype"].objectValue           );
                
                if (!sourceLanguage) sourceLanguage = attrs[@"source-language"].objectValue;
                else                 assert([sourceLanguage isEqual: attrs[@"source-language"].objectValue]);
                if (!targetLanguage) targetLanguage = attrs[@"target-language"].objectValue;
                else                 assert([targetLanguage isEqual: attrs[@"target-language"].objectValue]);
                
                mflog("Attributes: %@", attrs);
                
                /// Validate `<header>`
                
                NSXMLNode *header = [file childAtIndex:0];
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
            }
            
            NSArray<NSXMLElement *> *transUnits = (id)[xml_childnamed(file, @"body") children];
            
            NSMutableArray<NSXMLElement *> *filteredTransUnits = [NSMutableArray new]; /// Filter out transUnits with `kMFTransUnitState_DontTranslate` (Why does Xcode even export those?)  || Reimplements the logic in `rowModel_getCellModel` Maybe we should reuse that? [Oct 2025]
            {
                for (NSXMLElement *transUnit in transUnits) {
                    if ([xml_attr(transUnit, @"translate").objectValue isEqual: @"no"])
                        continue;
                    [filteredTransUnits addObject: transUnit];
                }
            }
            if (filteredTransUnits.count) {
                [self->files addObject: File_Make(filteredTransUnits, xml_attr(file, @"original").objectValue)];
                [transUnitsFromAllFiles addObjectsFromArray: filteredTransUnits];
            }
        }
        [self->files insertObject: (id)@"separator" atIndex: 0];
        [self->files insertObject: File_Make(transUnitsFromAllFiles, kMFPath_AllDocuments) atIndex: 0];
        self->_transUnitsFromAllFiles = transUnitsFromAllFiles;
        
        self->sourceLanguage = sourceLanguage;
        self->targetLanguage = targetLanguage;
        
    }
    
    - (void) showAllTransUnits {
    
        NSInteger row = 0; /// Hardcode to first row. [Oct 2025]
        [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
    }
    
    
    - (void) progressHasChanged {

        /// This seems to complicated for what we're doing - why two methods for this? [Oct 2025]
        for (NSInteger row = 0; row < self.numberOfRows; row++) {
            if ([files[row] isEqual: @"separator"]) continue;
            auto cell = [self viewAtColumn: 0 row: row makeIfNecessary: NO];
            [self updateProgressInCell: cell withFile: files[row]];
        }
    }
    
    - (void) updateProgressInCell: (NSTableCellView *)cell withFile: (File *)file {
    
        NSTextField *progressField = [cell mf_associatedObjectForKey: @"progress-field"];
        progressField.attributedStringValue = ({
            
            /// Determine progress percent
            double progress = -1;
            {
                NSInteger count_translated = 0;
                NSInteger count_all = 0;
                for  (NSXMLElement *transUnit in file->transUnits) {
                    if (rowModel_isParent(transUnit))
                        continue; /// Ignore the isTranslated state of parentRows see `stateOfRowModel:`
                    if ([rowModel_getCellModel(transUnit, @"state") isEqual: kMFTransUnitState_Translated])
                        count_translated += 1;
                    count_all += 1;
                }
                progress = (double)count_translated / count_all;
                
                if ((0)) mflog(@"locprogress: %@ (%@), translated: %@, all: %@", @(progress), @((int)(progress * 100)), @(count_translated), @(count_all));
            }
            
            /// Create string
            auto s =  [[NSMutableAttributedString alloc] initWithString: stringf(@"%d%%", (int)(progress * 100))];
            if (progress == 1.0) {
                s = make_green_checkmark(@"100%");
                [s
                    addAttribute: NSFontAttributeName
                    value: [NSFont systemFontOfSize: 12]
                    range: NSMakeRange(0, s.length)
                ];
            }
            else {
                [s
                    addAttribute: NSFontAttributeName
                    value: [NSFont systemFontOfSize: 12]
                    range: NSMakeRange(0, s.length)
                ];
            }
            s;
        });
    }
    
    #pragma mark - Keyboard Control
    
        - (void) keyDown: (NSEvent *)event {
            
            /// Select the tableView if the user hits space, enter, or rightArrow
            if (
                eventIsKey(event, ' ') ||
                eventIsKey(event, '\r') ||
                eventIsKey(event, NSRightArrowFunctionKey)
            ) {
                [getdoc(self)->ctrl->out_tableView returnFocus];
            }
            else
                [super keyDown: event];
            
        }

    #pragma mark - NSOutlineView

    #pragma mark - NSOutlineViewDataSource

    - (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (id)item {
        return !item ? ( self->files[index] ) : nil;
    }

    - (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (id)item {
        return NO;
    }

    - (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (id)item {
        return !item ? self->files.count : 0;
    }

    #pragma mark - NSOutlineViewDelegate
    
    - (NSString *) uiStringForFile: (File *)file {
        
        if ([file isEqual: @"separator"]) return @"";
        
        NSMutableArray *allUIStrings = [NSMutableArray new];
        for (File *f in self->files) {
            if ([f isEqual: @"separator"]) { [allUIStrings addObject: @""]; continue; }
            NSString *uiString =
                [[f->path lastPathComponent] stringByDeletingPathExtension]
                //[f->path lastPathComponent]
            ;
            for (int i = 1;; i++) {
                NSString *appendix = (i == 1) ? @"" : stringf(@" (%d)", i);
                NSString *uiStringgg = stringf(@"%@%@", uiString, appendix);
                if (![allUIStrings containsObject: uiStringgg]) {
                    [allUIStrings addObject: uiStringgg];
                    break;
                }
            }
        }
    
        return allUIStrings[[self->files indexOfObject: file]];
    }
    
    - (NSView *) outlineView: (NSOutlineView *)outlineView viewForTableColumn: (NSTableColumn *)tableColumn item: (File *)file {
        
        if ([file isEqual: @"separator"]) {
            
            if ((0))
            return mfui_wrap(mfui_margin(5, 5, 0, 0), ({
                auto v = mfui_new(NSBox);
                v.titlePosition = NSNoTitle;
                v.boxType = NSBoxSeparator;
                v;
            }));
            if ((1))
            return mfui_wrap(mfui_margin(15, 3, 2, 0),
                mfui_label(@"Project Files", 11, NSFontWeightSemibold, [NSColor secondaryLabelColor])
            );
            
        }
        
        auto mfui_hstack = ^NSStackView *(NSArray *arrangedSubviews) {

            auto v = mfui_new(NSStackView);
            v.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            
            for (NSView *w in arrangedSubviews) {
                [v addArrangedSubview: w];
            }
            if ((1)) {
                [v setContentHuggingPriority: 1000               forOrientation: NSLayoutConstraintOrientationHorizontal];
                [v setContentCompressionResistancePriority: 1000 forOrientation: NSLayoutConstraintOrientationHorizontal];
                [v setContentHuggingPriority: 1000               forOrientation: NSLayoutConstraintOrientationVertical];
                [v setContentCompressionResistancePriority: 1000 forOrientation: NSLayoutConstraintOrientationVertical];
            }
            
            return v;
        };
        
        NSTableCellView *cell;
        {
            if ((0)) {
            
                /// Caused weird autolayout crashes in the TableView I think? I edited state and then switched files and then resized the sidebar.
                ///     Update: Still happens after switching back. Here's the error message: [Oct 2025]
                ///         Thread 1: "Unable to activate constraint with anchors <NSLayoutXAxisAnchor:0xb2a45cb00 \"NSTableCellView:0xb2a143480.left\"> and <NSLayoutXAxisAnchor:0xb2a45c4c0 \"NSTableRowView:0xb2a171800.left\"> because they have no common ancestor.  Does the constraint or its anchors reference items in different view hierarchies?  That's illegal."
                ///
                
                cell = [NSTableCellView new];
                NSTextField *out_label = nil;
                NSTextField *out_progress = nil;
                auto content = mfui_wrap(mfui_margin(6, 6, 2, 2), mfui_hstack(@[
                    mfui_outlet(&out_label,    ({ auto v = mfui_label([self uiStringForFile: file], 12, NSFontWeightRegular, [NSColor labelColor]);
                        [v setContentCompressionResistancePriority: 1 forOrientation: NSLayoutConstraintOrientationHorizontal];
                        [v setLineBreakMode: NSLineBreakByTruncatingTail];
                    v; })),
                    mfui_spacer(),
                    mfui_outlet(&out_progress, ({ auto v = mfui_label(@"", 12, NSFontWeightRegular, [NSColor secondaryLabelColor]); /// Text filled in by updateProgressInCell
                        v.identifier = @"progess-field";
                    v; }))
                ]));
                mfui_insert(cell, mfui_margin(0, 0, 0, 0), content);
                
                cell.textField = out_label;
                [cell mf_setAssociatedObject: out_progress forKey: @"progress-field"];
            }
            
            if ((1)) {
                /// There's only one column so we can ignore it.
                cell = [self makeViewWithIdentifier: @"theReusableCell_Outline" owner: self]; /// Not sure if owner=self is right. Also see TableView.m
                assert(cell);
                cell.textField.stringValue = [self uiStringForFile: file];
                
                id progressField = firstmatch(cell.subviews, cell.subviews.count, nil, sv, [[sv identifier] isEqual: @"progess-field"]);
                [cell mf_setAssociatedObject: progressField forKey: @"progress-field"];
                
                auto indentConstraint = firstmatch(cell.constraints, cell.constraints.count, nil, c, [c.identifier isEqual: @"indentConstraint"]);
                indentConstraint.constant = ([self rowForItem: file] == 0) ? 2 : 5; /// Indent the project file's rows a bit under the `@"separator"` (Why am I doing this???)
                
            }
        }
        
        [self updateProgressInCell: cell withFile: file];
        
        return cell;
    }

    - (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
        if ([item isEqual: @"separator"]) return NO;
        return YES;
    }

    - (void) outlineViewSelectionDidChange: (NSNotification *)notification {
        File *file = self->files[self.selectedRow];
        [getdoc(self)->ctrl->out_tableView reloadWithNewData: file->transUnits];
    }
    
    
    - (id)copy {
        return [super copy];
    }
    
    - (id)mutableCopy {
        return [super mutableCopy];
    }
    
    
@end
