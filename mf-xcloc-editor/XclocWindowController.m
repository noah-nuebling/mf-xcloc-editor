//
//  MainMenu.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import "Constants.h"
#import "XclocWindowController.h"
#import "Utility.h"
#import "Cocoa/Cocoa.h"
#import "MFUI.h"

#import "TableView.h"
#import "AppDelegate.h"

#import <Carbon/Carbon.h>

#import "XclocDocument.h"
#import "MFTextField.h"

#import "NSNotificationCenter+Additions.h"

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

@interface XclocWindow : NSWindow @end
@implementation XclocWindow

    {
        NSTextView *mfFieldEditor;
        BOOL isRestoringState;
        
    }
    
    #pragma mark - Field Editor
    
        - (NSText *) fieldEditor: (BOOL)createFlag forObject: (id)object {

                /// Install custom fieldEditor
                    ///  References:
                    ///     - https://stackoverflow.com/questions/12712288/making-invisible-characters-visible-in-nstextfield
                    ///     - https://stackoverflow.com/questions/300086/display-hidden-characters-in-nstextview

            if (isclass(object, MFTextField)) {
                
                if (!mfFieldEditor) {
                    
                    self->mfFieldEditor = [MFInvisiblesTextView new];
                    [self->mfFieldEditor setFieldEditor: YES];
                }

                return self->mfFieldEditor;
                
            }
            
            return [super fieldEditor: createFlag forObject: object];
        }
    
    #pragma mark - State restoration
    
        - (BOOL)makeFirstResponder:(NSResponder *)responder {
        
            mflog("makeFirstResponder: %@ with self->isRestoringState: %d", responder, self->isRestoringState);
            
            if (self->isRestoringState) /// See `restoreStateWithCoder:` [Oct 2025]
                return NO;
            else
                return [super makeFirstResponder: responder];
        }
        
        - (void) restoreStateWithCoder: (NSCoder *)coder {
            /// We don't want any state restoration except for windowFrames – the only other thing the super impl does is start editing random rows immediately but in a weird state where things break after (Worked around that with `@"MFSourceCellSister"`)[Oct 2025]
            ///     We if we don't call super, the entire window restoration fails though (Doesn't even open the window) So we set `self->isRestoringState` to customize behavior – hacky but should work. [Oct 2025]
            ///     This is called by the completionHandler passed to our `restoreWindowWithIdentifier:` override [Oct 2025]
            mflog(@"restoreStateWithCoder: %@", coder);
            self->isRestoringState = YES;
            [super restoreStateWithCoder: coder];
            self->isRestoringState = NO;
        }
        
        - (void)encodeWithCoder:(NSCoder *)coder {
        
            assert(false); /// Don't think this is called
            [super encodeWithCoder:coder];
        }

        - (void)encodeRestorableStateWithCoder:(NSCoder *)coder backgroundQueue:(NSOperationQueue *)queue {
        
            mflog(@"encodeRestorableStateWithCoder:backgroundQueue: %@", coder);
            [super encodeRestorableStateWithCoder: coder backgroundQueue: queue];
        }
        
        - (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
        
            mflog(@"encodeRestorableStateWithCoder: %@", coder);
            [super encodeRestorableStateWithCoder: coder];
        }

@end

@implementation XclocWindowController

    {
        XclocWindow *window; /// Without storing after creation in -loadWindow, this started crashing somewhere in AppKit on Tahoe  after adding `windowShouldClose:` [Oct 2025]
    }
    
    
    - (void) loadWindow { /// Replaces `- (Outlets) makeMainWindow` I think [Oct 2025]
        
        /// Set up window
        assert(!self.window);
        {
            
            /// TODO: Make default width on small laptop screen better
            /// TODO: Add "Show in 'filename'" to right-click menu.
            
            /// TODO: Don't automatically set state to 'translated' unless the user stops editing via return key. (DONE)
            /// TODO: (DONE)
            ///     Bug: `72q-sS-xMS.​title` -> Cycle through states changes comment
            
        
            /// Abandoned TODOs:
            
                /// (((((((TODO: (Maybe) add some tooltips (But I'm slow at writing and really don't wanna spend time on this))))))
                ///    Ideas:
                ///         - Click here or press space to see the translatable text in-context
                ///
                /// TODO: Maybe look into responsiveness of changing the sort / file
                ///     Overriding `heightOfRowByItem:` can improve things, but that's hard to do well – giving up. Performance is alright.
                /// TODO: Fix issue where double-clicking / triple-clicking /...  a row does nothing (instead of starting text-editing)
                ///     Tried to fix this but hard. Maybe just live with it.
                /// TODO: Undo is a bit unresponsive (cause saving the doc on every edit is slow)
                ///     Maybe we'll just live with that. (Do we even need undo? – All this NSDocument stuff may have been overkill. Things we so much simpler when we were just writing to disk directly. )
            
            window = [XclocWindow new];
            window.styleMask = 0
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskResizable
                | NSWindowStyleMaskTitled
                | NSWindowStyleMaskFullSizeContentView
                | NSWindowStyleMaskUnifiedTitleAndToolbar
            ;
            
            window.identifier = @"XclocWindowIdentifier"; /// Doesn't seem to make a difference (Thought it might improve some restorableState issues)
            
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
        
        /// Enable cascading, if we open multiple documents
        ///     Doesn't work on macOS 26 [Oct 2025]
        ///     Also tried overriding `cascadeTopLeftFromPoint:` but it's not called.
        self.shouldCascadeWindows = YES; /// Doesn't make a difference [Oct 2025]
        
        /// Define view hierarchy & get outlets
        NSSplitView *out_splitView = nil;
        #if 0
            mfui_insert(window.contentView, mfui_margins(0,0,0,0), mfui_outlet(&out_splitView, mfui_splitview(@[ /// Hack: Have to use autolayout around the NSSplitView to give the viewHierarchy a `_layoutEngine`. Otherwise `[NSSplitView setHoldingPriority:forSubviewAtIndex:]` doesn't work. HACKS ON HACKS ON HACK ON HACKS
                mfui_scrollview(mfui_outlet(&self->out_sourceList, [SourceList new])),
                mfui_scrollview(mfui_outlet(&self->out_tableView,  [TableView new]))
            ])));
        #else
            window.contentViewController = ({
                auto contentViewController = [NSSplitViewController new];
                if ((0)) {
                    contentViewController.splitView = ({
                        mfui_outlet(&out_splitView, mfui_splitview(@[]));
                    });
                }
                out_splitView = contentViewController.splitView;
                contentViewController.splitViewItems = @[
                    ({
                        auto sideBarItem = [NSSplitViewItem sidebarWithViewController: mfui_viewcontroller(({
                            auto v = mfui_scrollview(mfui_outlet(&self->out_sourceList, mfui_new(SourceList)));
                            v.drawsBackground = /*YES*/ NO; /// Turn off liquid glass - just make it sidebar white.
                            v;
                        }))];
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
                auto w = mfui_wrap(mfui_margins(5, 5, 5, 5), mfui_outlet(&self->out_filterField, ({
                    auto v = mfui_new(FilterField);
                    v.editable = YES;
                    v.placeholderString = kMFStr_FilterTranslations;
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
        [[NSNotificationCenter defaultCenter] mf_addObserverForName: NSControlTextDidChangeNotification object: self->out_filterField observee: self block: ^(NSNotification * _Nonnull notification, XclocWindowController *_Nullable observee) {
            mflog(@"filter fiellddd: %@", observee->out_filterField.stringValue);
            [observee->out_tableView updateFilter: observee->out_filterField.stringValue];
        }];
        
        /// Set window size/position
        { /// Default size/position
            [window setContentSize: NSMakeSize(1440 - 100, 900 - 100)];
            [window center];
        }
        if ((0)) /// This is unnecessary now since it's handled automatically by `restoreWindowWithIdentifier:`? [Oct 2025]
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
            v.placeholderString = kMFStr_FilterTranslations;
            self->out_filterField = v;
            v;
        });
        return result;
    }
    
    #pragma mark - Local MFUI Stuff
    
    NSSplitView *mfui_splitview(NSArray<NSView *> *arrangedSubviews) {
        
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

@end
