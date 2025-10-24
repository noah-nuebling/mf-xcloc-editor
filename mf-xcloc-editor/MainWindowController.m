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
        
        auto splitView = mfview(NSSplitView);
        
        splitView.vertical = YES;
        splitView.dividerStyle = NSSplitViewDividerStyleThin;
        
        for (NSView *subview in arrangedSubviews) {
            [splitView addArrangedSubview: subview];
        }
        
        return splitView;
    }
    
    
    
    - (void) loadWindow { /// Replaces `- (Outlets) makeMainWindow` I think [Oct 2025]
        
        /// Set up window
        assert(!self.window);
        {
            
            /// TODO: Get it to show standard right-clickable document title
            /// TODO: Make sidebar pretty
            /// TODO: Improve table row header UI strings
            /// TODO: Fix layout jank on @"id" and @"state" cells (sometimes disappear)
            /// TODO: Make filterField pretty
            /// TODO: Disable lines behind empty rows
            /// TODO: Update App Name
            /// TODO: Update App Icon (?)
            /// TODO: Remove fat underline under TableColumns
            /// TODO: Better default column-widths
            /// TODO: Make text-selection in cells less ugly
            
            window = [NSWindow new];
            window.styleMask = 0
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
                | NSWindowStyleMaskTitled
            ;
            if ((0)) window.title = @"Xcloc Editor";
            
            window.delegate = self;
            window.windowController = self; /// Used by `getdoc()` [Oct 2025]
            
            if ((0)) window.toolbar = [NSToolbar new]; /// Adding to change titlebar height
            
        };
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        mfinsert(window.contentView, mfmargin(0,0,0,0), mfoutlet(&out_splitView, mfsplitview(@[ /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
            mfscrollview(mfoutlet(&self->out_sourceList, [SourceList new])),
            mfscrollview(mfoutlet(&self->out_tableView,  [TableView new]))
        ])));
        
        /// Add accessory view
        [window addTitlebarAccessoryViewController: ({
            
            auto viewController = [TitlbarAccessoryViewController new];
            viewController->_theView = ({
                auto w = mfwrap(mfmargin(5, 5, 5, 5), mfoutlet(&self->out_filterField, ({
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
    }
    
    - (void) windowWillClose: (NSNotification *)notification { /// Note: We force this to be called in `applicationShouldTerminate:` [Oct 2025]
        
        [notification.object saveFrameUsingName: @"TheeeEditor"];
    }

@end
