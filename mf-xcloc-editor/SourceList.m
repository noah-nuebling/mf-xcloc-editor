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

@implementation SourceList
    {
        NSArray <NSXMLElement *> *files;
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

        self->files = (NSArray<NSXMLElement *> *) xliff.children;
        
        /// Store xliff doc
        self->_xliffDoc = xliffDoc;
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

    - (NSView *) outlineView: (NSOutlineView *)outlineView viewForTableColumn: (NSTableColumn *)tableColumn item: (NSXMLElement *)fileEl {
        
        /// There's only one column so we can ignore it.
        NSTableCellView *cell = [self makeViewWithIdentifier: @"theReusableCell_Outline" owner: self]; /// Not sure if owner=self is right. Also see TableView.m
        NSString *path = xml_attr(fileEl, @"original").objectValue;
        cell.textField.stringValue = [path lastPathComponent];
        return cell;
    }

    - (void) outlineViewSelectionDidChange: (NSNotification *)notification {
        
        NSXMLElement *file = self->files[self.selectedRow];
        
        appdel->tableView.data = file;
        [appdel->tableView reloadData];
    }

@end
