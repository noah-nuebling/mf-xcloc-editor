//
//  MainMenu.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import "MainWindowController.h"
#import "Utility.h"
#import "Cocoa/Cocoa.h"
#import "MFUI.h"

#import "TableView.h"

@implementation MainWindowController
    
    NSSplitView *mfsplitview(NSArray<NSView *> *arrangedSubviews) {
        
        auto splitView = mfview(NSSplitView);
        
        splitView.vertical = YES;
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        
        for (NSView *subview in arrangedSubviews) {
            [splitView addArrangedSubview: subview];
        }
        
        return splitView;
    }
    
    - (Outlets) makeMainWindow {
        
        /// Init result
        Outlets result = {0};
        
        /// Set up window
        auto window = [NSWindow new];
        window.styleMask = 0
            | NSWindowStyleMaskClosable
            | NSWindowStyleMaskResizable
            | NSWindowStyleMaskTitled
        ;
        window.title = @"Xcloc Editor";
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        mfinsert(window.contentView, mfmargin(0,0,0,0), mfoutlet(&out_splitView, mfsplitview(@[ /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
            mfscrollview(mfoutlet(&result.sourceList, [SourceList new])),
            mfscrollview(mfoutlet(&result.tableView,  [TableView new]))
        ])));
        
        /// Configure views
        {
            /// Make SourceList keep its size on window resize
            [out_splitView setHoldingPriority: 400 forSubviewAtIndex: 0];
            [out_splitView setHoldingPriority: 100 forSubviewAtIndex: 1];
            
            /// Give the SourceList a minWidth
            ///     Otherwise the NSSplitView crushes it to width 0
            [result.sourceList.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
            
            /// Also give TableView a minWidth
            [result.tableView.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
        }
        
        /// Open window
        [window makeKeyAndOrderFront: nil];
        
        /// Return
        return result;
    }

@end
