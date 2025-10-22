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

@interface TitlbarAccessoryViewController : NSTitlebarAccessoryViewController @end
@implementation TitlbarAccessoryViewController { @public NSView *_theView; }
    - (void)loadView { self.view = _theView; }
@end

@interface FilterField : NSTextField <NSTextFieldDelegate, NSControlTextEditingDelegate> @end
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
        [appdel->tableView updateFilter: @""];  /// Can't get our `NSControlTextDidChangeNotification` callback to trigger 'naturally' [Oct 2025]
        [appdel->tableView returnFocus];        /// Return focus to the TableView when the user hits escape.
    }
    
    - (BOOL) control: (NSControl *)control textView: (NSTextView *)textView doCommandBySelector: (SEL)commandSelector {
        
        if      (commandSelector == @selector(moveUp:)) { /// upArrow || Disabling upArrow and downArrow since it can be error prone when you're browsing the rows and hitting enter and then changing the filter instead of opening quickLook [Oct 2025]
            [appdel->tableView keyDown: makeKeyDown(NSUpArrowFunctionKey, kVK_UpArrow)];
            [appdel->tableView returnFocus];
        }
        else if (commandSelector == @selector(moveDown:)) { /// downArrow
            [appdel->tableView keyDown: makeKeyDown(NSDownArrowFunctionKey, kVK_DownArrow)];
            [appdel->tableView returnFocus];
        }
        else if (commandSelector == @selector(insertNewline:)) /// return
            [appdel->tableView returnFocus];
        else
            return NO;
        
        return YES;
    }

@end

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
        
        static NSWindow *window; /// Without making static, this started crashing somewhere in AppKit on Tahoe  after adding `windowShouldClose:` [Oct 2025]
        mfonce(mfoncet, ^{
            
            window = [NSWindow new];
            window.styleMask = 0
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
                | NSWindowStyleMaskTitled
            ;
            window.title = @"Xcloc Editor";
            
            window.delegate = self;
            
            if ((0)) window.toolbar = [NSToolbar new]; /// Adding to change titlebar height
            
        });
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        mfinsert(window.contentView, mfmargin(0,0,0,0), mfoutlet(&out_splitView, mfsplitview(@[ /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
            mfscrollview(mfoutlet(&result.sourceList, [SourceList new])),
            mfscrollview(mfoutlet(&result.tableView,  [TableView new]))
        ])));
        
        /// Add accessory view
        [window addTitlebarAccessoryViewController: ({
            
            auto viewController = [TitlbarAccessoryViewController new];
            viewController->_theView = ({
                auto w = mfwrap(mfmargin(5, 5, 5, 5), mfoutlet(&result.filterField, ({
                    auto v = mfview(FilterField);
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
            [out_splitView setHoldingPriority: 400 forSubviewAtIndex: 0];
            [out_splitView setHoldingPriority: 100 forSubviewAtIndex: 1];
            
            /// Give the SourceList a minWidth
            ///     Otherwise the NSSplitView crushes it to width 0
            [result.sourceList.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
            
            /// Also give TableView a minWidth
            [result.tableView.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant: 200].active = YES;
        }
        
        /// Set up `result.filterField` callback
        [[NSNotificationCenter defaultCenter] addObserverForName: NSControlTextDidChangeNotification object: result.filterField queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
            mflog(@"filter fiellddd: %@", result.filterField.stringValue);
            [appdel->tableView updateFilter: result.filterField.stringValue];
        }];
        
        /// Set window size/position
        { /// Default size/position
            [window setContentSize: NSMakeSize(800, 600)];
            [window center];
        }
        [window setFrameUsingName: @"TheeeEditor"]; /// Override with last saved size / position
        
        /// Open window
        [window makeKeyAndOrderFront: nil];
        
        /// Return
        return result;
    }
    
    - (void) windowWillClose: (NSNotification *)notification { /// TODO: This is not called when the window is closed due to application termination [Oct 2025]
        
        [notification.object saveFrameUsingName: @"TheeeEditor"];
    }

@end
