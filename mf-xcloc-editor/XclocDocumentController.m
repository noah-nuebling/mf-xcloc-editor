//
//  XclocDocumentController.m
//  MMF Xcloc Editor
//
//  Created by Noah Nübling on 10/27/25.
//

#import "Utility.h"
#import "XclocDocumentController.h"
#import "Utility.h"

@implementation XclocDocumentController

    static int _restoringWindows = 0;
    
    #if 1
        - (void)openDocument:(id)sender {
            
            /// Invoked by Command-O but we're also redirecting `applicationOpenUntitledFile:` to this [Oct 2025]
            
            /// Log
            mflog(@"openDocument: (sender: %@)", sender);
            
            /// Don't open while winds are still restoring
            ///     Otherwise NSOpenPanel opens on (almost) every app-launch (Sometimes it randomly doesn't). I think this may be due to `makeWindowControllers` being called late, probably due to `readFromFileWrapper:` being slow and/or `canConcurrentlyReadDocumentsOfType:` making reads async. [Oct 2025]
            if (_restoringWindows) {
                mflog(@"Not opening NSOpenPanel while restoring windows");
                return;
            }
            
            /// Don't open multiple NSOpenPanels
            for (id w in [NSApp windows])
                if (isclass(w, NSOpenPanel)) {
                    mflog(@"Not creating NSOpenPanel – one already exists");
                    [w makeKeyAndOrderFront: nil];
                    return;
                }
            
            /// Default impl also opens NSOpenPanel, but we wanna customize the location and stuff
            auto openPanel = [NSOpenPanel new];
            [openPanel setRestorable: NO]; /// Desparate 
            openPanel.allowsMultipleSelection = NO;
            [openPanel setRequiredFileType: @"com.apple.xcode.xcloc"];
            {
                /// The NSOpenPanel.directory defaults to the dir that the user last opened if they navigated somewhere in the open-panel – perhaps we should preserve the selection if the NSOpenPanel.directory contains .xcloc files [Oct 2025]
                ///     (But this is not necessary for MMF, since we know we'll ship the .xcloc files next to this app bundle.) [Oct 2025]
                auto _searchResults = findPaths(100, [[NSBundle.mainBundle bundlePath] stringByDeletingLastPathComponent], ^BOOL (NSString *p) {
                    return [p hasSuffix: @".xcloc"];
                });
                if (_searchResults.count)
                    [openPanel setDirectory: [_searchResults[0] stringByDeletingLastPathComponent]];
            }
            [openPanel beginWithCompletionHandler:^(NSModalResponse result) {
                if (openPanel.URL && result == NSModalResponseOK) {
                    [self openDocumentWithContentsOfURL: openPanel.URL display: YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
                        mflog(@"Document opened %@, atPath: %@, was open: %@, error: %@", document, openPanel.URL, @(documentWasAlreadyOpen), error);
                        [document showWindows];
                    }];
                }
            }];
        }
    #endif

    + (void) restoreWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler {
        
        /// Observations:
        ///     - When is this called?
        ///         - When `close windows when quitting an application` is turned *on* in system settings: (default)
        ///             - This is only called when
        ///                 - You leave the app running until `encodeRestorableStateWithCoder:` is called. (Seemingly at random)
        ///                 - You then kill the app via the stop button in Xcode and re-open (Quitting normally doesn't work)
        ///         - Otherwise
        ///             - This is called whenever you quit the app with a document open and then re-open it.
        ///             - This is not called when you close the window before quitting the app and then re-open it.
        ///     - Super calls restoration methods on XclocDocument (`restoreDocumentWindowWithIdentifier:`)
        ///     - When this is not called the application opens and nothing happens (no windows open), which is weird.
        ///
        /// Behavior we want:
        ///     - Ideally we always want some window to open after opening the app. Options (by preference)
        ///         - Open whatever window was opened last
        ///         - Open a special 'recent files picker' window
        ///
        /// References:
        ///     Example of using `restoreWindowWithIdentifier:` https://stackoverflow.com/a/13978934
        ///     Apple's `PackagedDocument` sample project - to test what is the default behavior.
        ///     On  `close windows when quitting an application` option: https://stackoverflow.com/a/12894388)
        
        mflog(@"restoreWindowWithIdentifier: %@", identifier);
        _restoringWindows++;
        [super restoreWindowWithIdentifier: identifier state: state completionHandler: ^void (NSWindow * _Nullable window, NSError * _Nullable error) {
            
            mflog(@"restoreWindowWithIdentifier completion: %@, error: %@", window, error);
            completionHandler(window, error);
            assert(_restoringWindows >= 1);
            _restoringWindows--;
        }];
        
    }
    
    #if 1
        - (__kindof NSDocument *)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError *__autoreleasing  _Nullable *)outError {
            
            /// Observations:
            ///     - This is called when opening the app when there are no windows to restore
            ///     - Default impl calls `[XclocDocument makeWindowControllers]` without calling `[XclocDocument readFromFileWrapper:]`) first
            ///         ->>> Can turn this off using `applicationShouldOpenUntitledFile:`
            
            
            mflog(@"openUntitledDocumentAndDisplay:");
            
            if ((0)) return [super openUntitledDocumentAndDisplay: displayDocument error: outError];

            
            if (outError) *outError = nil;
            return nil;
        }
    #endif

@end
