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
#import "AppDelegate.h"

#import <Carbon/Carbon.h>

#import "XclocDocument.h"

@interface TitlbarAccessoryViewController : NSTitlebarAccessoryViewController @end
@implementation TitlbarAccessoryViewController { @public NSView *_theView; }
    - (void)loadView { self.view = _theView; }
@end

@interface FilterField : NSSearchField <NSSearchFieldDelegate, NSControlTextEditingDelegate> @end
@implementation FilterField

    - (instancetype) initWithFrame: (NSRect)frame {
        self = [super initWithFrame:frame];
        if (self) {
            self.delegate = self;
        }
        return self;
    }

    - (void) cancelOperation: (id)sender { /// escape
        [self setStringValue: @""];
        [getdoc(self)->ctrl->out_tableView updateFilter: @""];  /// Can't get our `NSControlTextDidChangeNotification` callback to trigger 'naturally' [Oct 2025]
        [getdoc(self)->ctrl->out_tableView returnFocus];        /// Return focus to the TableView when the user hits escape.
    }
    
    - (BOOL) control: (NSControl *)control textView: (NSTextView *)textView doCommandBySelector: (SEL)commandSelector {
        
        if      (commandSelector == @selector(moveUp:)) { /// upArrow || Disabling upArrow and downArrow since it can be error prone when you're browsing the rows and hitting enter and then changing the filter instead of opening quickLook [Oct 2025]
            [getdoc(self)->ctrl->out_tableView returnFocus];
            [getdoc(self)->ctrl->out_tableView keyDown: makeKeyDown(NSUpArrowFunctionKey, kVK_UpArrow)];
        }
        else if (commandSelector == @selector(moveDown:)) { /// downArrow
            [getdoc(self)->ctrl->out_tableView returnFocus];
            [getdoc(self)->ctrl->out_tableView keyDown: makeKeyDown(NSDownArrowFunctionKey, kVK_DownArrow)];
        }
        else if (commandSelector == @selector(insertNewline:)) /// return
            [getdoc(self)->ctrl->out_tableView returnFocus];
        else
            return NO;
        
        return YES;
    }

@end

@implementation MainWindowController

    {
        NSWindow *window; /// Without storing after creation in -loadWindow, this started crashing somewhere in AppKit on Tahoe  after adding `windowShouldClose:` [Oct 2025]
    }
    
    NSSplitView *mfsplitview(NSArray<NSView *> *arrangedSubviews) {
        
        auto splitView = mfui_new(NSSplitView);
        
        splitView.vertical = YES;
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        
        for (NSView *subview in arrangedSubviews) {
            [splitView addArrangedSubview: subview];
        }
        
        return splitView;
    }
    
    NSViewController *mfui_viewcontroller(NSView *view) {
        auto c = [NSViewController new];
        c.view = view;
        return c;
    }
    

    
    - (void) loadWindow { /// Replaces `- (Outlets) makeMainWindow` I think [Oct 2025]
        
        /// Set up window
        assert(!self.window);
        {
            
            /// TODO: Fix layout jank on @"id" and @"state" cells (sometimes disappear)
            /// TODO: Better default column-widths
            /// TODO: checkmark.circle cells disappear when you double-click it.
            /// TODO: Fix issue where double-clicking / triple-clicking /...  a row does nothing (instead of starting text-editing)
            ///     Tried to fix this but hard. Maybe just live with it.
            
            
            window = [NSWindow new];
            window.styleMask = 0
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
                | NSWindowStyleMaskTitled
                | NSWindowStyleMaskFullSizeContentView
                | NSWindowStyleMaskUnifiedTitleAndToolbar
            ;
            
            window.delegate = self;
            if ((0)) window.windowController = self; /// Used by `getdoc()` [Oct 2025]
            
            window.toolbar = [NSToolbar new]; /// Adding to change titlebar height
            {
                window.toolbar.allowsUserCustomization = NO;
                window.toolbar.delegate = self;
                [window.toolbar insertItemWithItemIdentifier: @"SearchField" atIndex: 0]; /// Gotta do this in addition to `toolbarDefaultItemIdentifiers:` – why is this so complicated.
                window.toolbar.displayMode = NSToolbarDisplayModeIconOnly;
                window.toolbar.allowsDisplayModeCustomization = NO;
            }
            if ((0)) window.toolbarStyle = NSWindowToolbarStyleUnifiedCompact;
            
        };
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        #if 0
            mfui_insert(window.contentView, mfui_margin(0,0,0,0), mfui_outlet(&out_splitView, mfsplitview(@[ /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
                mfui_scrollview(mfui_outlet(&self->out_sourceList, [SourceList new])),
                mfui_scrollview(mfui_outlet(&self->out_tableView,  [TableView new]))
            ])));
        #else
            window.contentViewController = ({
                auto contentViewController = [NSSplitViewController new];
                if ((0)) {
                    contentViewController.splitView = ({
                        mfui_outlet(&out_splitView, mfsplitview(@[]));
                    });
                }
                out_splitView = contentViewController.splitView;
                contentViewController.splitViewItems = @[
                    ({
                        auto sideBarItem = [NSSplitViewItem sidebarWithViewController: mfui_viewcontroller(
                            ({ auto v = mfui_scrollview(mfui_outlet(&self->out_sourceList, mfui_new(SourceList)));
                            v.drawsBackground = YES; /// Turn off liquid glass - just make it sidebar white.
                            v; })
                        )];
                        sideBarItem.canCollapse = NO;
                        sideBarItem;
                    }),
                    [NSSplitViewItem splitViewItemWithViewController: mfui_viewcontroller(
                        mfui_scrollview(mfui_outlet(&self->out_tableView,  mfui_new(TableView)))
                    )]
                ];
                
                contentViewController;
            });
        
        
        #endif
        
        
        /// Add accessory view
        if ((0))
        [window addTitlebarAccessoryViewController: ({
            
            auto viewController = [TitlbarAccessoryViewController new];
            viewController->_theView = ({
                auto w = mfui_wrap(mfui_margin(5, 5, 5, 5), mfui_outlet(&self->out_filterField, ({
                    auto v = mfui_new(FilterField);
                    v.editable = YES;
                    v.placeholderString = @"Filter Translations";
                    if ((0)) {
                        v.drawsBackground = YES;
                        v.backgroundColor = [NSColor systemOrangeColor];
                    }
                    if ((0)) { /// Adjusting  autolayout doesn't seem to do anything. But frame works. Not sure why [Oct 2025]
                        [v.widthAnchor  constraintGreaterThanOrEqualToConstant: 500].active = YES;
                        [v.heightAnchor constraintGreaterThanOrEqualToConstant: 100].active = YES;
                    }
                    
                    v.frame = (NSRect){{0, 0}, {500, 0}}; /// Height doens't do anything, but width does. [Oct 2025] || Update: not that we added a wrapper we gotta add the frame there.
                    v;
                })));
                w.frame = (NSRect){{0, 0}, {300, 0}};
                w;
            });
            if ((1)) viewController.layoutAttribute = NSLayoutAttributeTrailing;
            else     viewController.layoutAttribute = NSLayoutAttributeBottom;
            
            viewController;
        })];
        
        /// Configure views
        {
            /// Make SourceList keep its size on window resize
            if ((0)) { /// Not necessary after using NSSplitViewController
                [out_splitView setHoldingPriority: 400 forSubviewAtIndex: 0];
                [out_splitView setHoldingPriority: 100 forSubviewAtIndex: 1];
            }
            
            /// Give the SourceList a minWidth
            ///     Otherwise the NSSplitView crushes it to width 0
            [self->out_sourceList.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
            
            /// Also give TableView a minWidth
            [self->out_tableView.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
        }
        
        /// Set up `result.filterField` callback
        [[NSNotificationCenter defaultCenter] addObserverForName: NSControlTextDidChangeNotification object: self->out_filterField queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
            mflog(@"filter fiellddd: %@", self->out_filterField.stringValue);
            [self->out_tableView updateFilter: self->out_filterField.stringValue];
        }];
        
        /// Set window size/position
        { /// Default size/position
            [window setContentSize: NSMakeSize(800, 600)];
            [window center];
        }
        [window setFrameUsingName: @"TheeeEditor"]; /// Override with last saved size / position
        
        /// Open window
        [window makeKeyAndOrderFront: nil];
        
        /// Store window
        [self setWindow: window];
    }
    
    - (void) windowWillClose: (NSNotification *)notification { /// Note: We force this to be called in `applicationShouldTerminate:` [Oct 2025]
        
        [notification.object saveFrameUsingName: @"TheeeEditor"];
    }

    #pragma mark - NSToolBarDelegate
    
    static NSArray <NSToolbarItemIdentifier> *toolbarItemIdentifers = @[
        @"SearchField",
    ];
    
    - (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
        return toolbarItemIdentifers;
    }
    - (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
        return toolbarItemIdentifers;
    }
    
    - (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
        auto result = [[NSSearchToolbarItem alloc] initWithItemIdentifier: @"SearchField"];
        result.searchField.delegate = self;
        result.searchField = ({
            auto v = mfui_new(FilterField);
            v.placeholderString = @"Filter Translations";
            self->out_filterField = v;
            v;
        });
        return result;
    }
    

@end
