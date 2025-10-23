//
//  XclocDocument.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

#import <Cocoa/Cocoa.h>
#import "TableView.h"
#import "SourceList.h"
#import "MainWindowController.h"
#import "Utility.h"

@interface XclocDocument : NSDocument

    {
        @public
        MainWindowController *ctrl;
        NSString *xclocPath;
    }
    @property(nonatomic) NSXMLDocument *xliffDoc;
    @property(nonatomic) NSArray *localizedStringsDataPlist; /// Plist mapping localizedStrings to screenshots [Oct 2025]
    
    - (void) writeTranslationDataToFile;

@end

#pragma mark - getdoc

    /// Use this to access global state around the app

    static XclocDocument *getdoc(id item) {
        
        XclocDocument *result = nil;
        
        if      (isclass(item, MainWindowController))   result = [item document];
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

    static XclocDocument *getdoc_frontmost(void) { /// Heuristic for accessing the document state from code that isn't specific to a window (mainMenu code) [Oct 2025]

        /// `-[NSDocumentController currentDocument]` does the same but docs say it's unreliable, not sure that matters here. [Oct 2025]

        __block XclocDocument *result = nil;
        
        [NSApp enumerateWindowsWithOptions: NSWindowListOrderedFrontToBack usingBlock:^(NSWindow * _Nonnull w, BOOL * _Nonnull stop) {
            if (isclass(w.windowController, MainWindowController)) {
                result = getdoc(w);
                *stop = YES;
            }
        }];
        
        assert(result != nil);
        return result;
    }
