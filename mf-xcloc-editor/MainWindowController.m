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
#import "NibLessViewController.h"

@implementation MainWindowController
    
    NSGlassEffectView *mfglass(NSView *v) {
        auto glass = [NSGlassEffectView new];
        glass.contentView = v;
        return glass;
    }
    
    NSSplitViewController *mfsplitviewcontroller(NSView *sidebarView, NSView *contentView) {
        
        auto splitView = mfview(NSSplitView);
        
        splitView.vertical = YES;
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        
        NSSplitViewController *controller = [[NSSplitViewController alloc] init];
        [controller setSplitView: splitView];
        
        if ((0)) { /// Causes weird exceptions [Sep 5 2025]
            auto bgView = [NSBackgroundExtensionView new];
            bgView.contentView = contentView;
            contentView = bgView;
        }
        if ((0)) { /// Sidebar already creates  its own glass but it's not tinting for some reason
            sidebarView = mfglass(sidebarView);
        }

        auto item1 = [NSSplitViewItem sidebarWithViewController: [NibLessViewController newWithView: sidebarView]];
        auto item2 = [NSSplitViewItem splitViewItemWithViewController: [NibLessViewController newWithView: contentView]];
        item1.minimumThickness = 80; /// TESTING
        item2.minimumThickness = 80; /// TESTING
        [controller addSplitViewItem: item1];
        [controller addSplitViewItem: item2];
        
        item1.allowsFullHeightLayout = YES;
        item1.automaticallyAdjustsSafeAreaInsets = YES;
        item1.canCollapseFromWindowResize = NO;
        
        item2.allowsFullHeightLayout = NO;
        item2.automaticallyAdjustsSafeAreaInsets = YES;
        item2.titlebarSeparatorStyle = NSTitlebarSeparatorStyleLine;

        
        {
            /// Make SourceList keep its size on window resize
            item1.holdingPriority = 400;
            item2.holdingPriority = 100;
            
            /// Give the SourceList a minWidth
            ///     Otherwise the NSSplitView crushes it to width 0
            [item1.viewController.view.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
            
            /// Also give TableView a minWidth
            [item2.viewController.view.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
            
            /// Min height
            [item1.viewController.view.heightAnchor constraintGreaterThanOrEqualToConstant: 400].active = YES;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [controller loadView];
        });
        
        return controller;
    }
    
    - (Outlets) makeMainWindow {
        
        /// Init result
        Outlets result = {0};
        
        /// Set up window
        ///     Src: For most of the styling: https://medium.com/@bancarel.paul/macos-full-height-sidebar-window-62a214309a80
        auto window = [NSWindow new];
        window.styleMask = 0
            | NSWindowStyleMaskClosable
            | NSWindowStyleMaskResizable
            | NSWindowStyleMaskTitled
            | NSWindowStyleMaskFullSizeContentView
            /*| NSWindowStyleMaskUnifiedTitleAndToolbar*/
        ;
        window.title = @"Xcloc Editor";
        window.titlebarAppearsTransparent = NO;
        
        if ((1)) {
            window.toolbar = ({ /// You have to create a toolbar (+ NSWindowStyleMaskFullSizeContentView) to make the sidebar full-height for some reason [Sep 2025, Tahoe Beta 9]
               auto toolbar = [[NSToolbar alloc] initWithIdentifier:@"my-cool-toolbar"];
               toolbar.delegate = nil;
               toolbar.allowsUserCustomization = NO;
               toolbar.displayMode = NSToolbarDisplayModeIconOnly;
               toolbar;
            });
        }
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        window.contentViewController = mfsplitviewcontroller( /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
            mfscrollview(mfoutlet(&result.sourceList, [SourceList new])),
            mfscrollview(mfoutlet(&result.tableView, [TableView new]))
        );
        
        /// Open window
        [window makeKeyAndOrderFront: nil];
        
        /// Return
        return result;
    }

@end
