//
//  SourceList.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <Cocoa/Cocoa.h>

@interface SourceList : NSOutlineView <NSOutlineViewDataSource, NSOutlineViewDelegate>

    {
        @public
        NSString *sourceLanguage;
        NSString *targetLanguage;
    }


    - (void) setXliffDoc: (NSXMLDocument *)xliffDoc;

    - (void) progressHasChanged;
    - (void) showAllTransUnits;
    - (BOOL) allTransUnitsShown;
    - (NSString *) filenameForTransUnit: (NSXMLElement *)transUnit;

@end
