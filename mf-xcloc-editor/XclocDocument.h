//
//  XclocDocument.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

#import <Cocoa/Cocoa.h>
#import "TableView.h"
#import "SourceList.h"
#import "XclocWindowController.h"
#import "Utility.h"

@interface NSDocument (PrivateStuff)
    - (void)_setShowAutosaveButton: (BOOL)flag;
@end

@interface XclocDocument : NSDocument

    {
        @public
        XclocWindowController *ctrl;
        NSXMLDocument *_xliffDoc;
        NSArray *_localizedStringsDataPlist; /// Plist mapping localizedStrings to screenshots [Oct 2025]
    }
    
    - (void) writeTranslationDataToFile;

@end

#pragma mark - getdoc

    /// Use this to access global state around the app

    static XclocDocument *getdoc(id item) {
        
        XclocDocument *result = nil;
        
        if      (isclass(item, XclocWindowController))   result = [item document];
        else if (isclass(item, NSWindow))               result = [[item windowController] document];
        else if (isclass(item, NSView))                 result = [[[item window] windowController] document];
        else if (isclass(item, NSMenuItem))             result = [[[[item view] window] windowController] document];
        else {
            assert(false);
            return nil;
        }
        
        assert(result != nil);
        return result;
    }

    static XclocDocument *_Nullable getdoc_frontmost(void) { /// Heuristic for accessing the document state from code that isn't specific to a window (mainMenu code) [Oct 2025]

        /// `-[NSDocumentController currentDocument]` does the same but docs say it's unreliable, not sure that matters here. [Oct 2025]
        ///     Returns nil if no document is open at all (See NSOpenPanel)
        
        __block XclocDocument *result = nil;
        
        [NSApp enumerateWindowsWithOptions: NSWindowListOrderedFrontToBack usingBlock:^(NSWindow * _Nonnull w, BOOL * _Nonnull stop) {
            if (isclass(w.windowController, XclocWindowController)) {
                result = getdoc(w);
                *stop = YES;
            }
        }];
        
        return result;
    }
