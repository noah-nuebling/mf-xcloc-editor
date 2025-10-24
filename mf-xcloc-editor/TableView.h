//
//  TableView.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "QuickLookUI/QuickLookUI.h"

@interface TableView : NSOutlineView
    <
        NSOutlineViewDataSource,
        NSOutlineViewDelegate,
        NSControlTextEditingDelegate,
        NSMenuItemValidation,
        QLPreviewPanelDelegate,
        QLPreviewPanelDataSource
    >
    @property(nonatomic) NSArray <NSXMLElement *> *transUnits; /// Section of an XLIFF file that this table displays [Jun 2025]
    - (void) reloadWithNewData: (NSArray <NSXMLElement *> *)transUnits;
    - (void) updateFilter: (NSString *)newFilterString;
    - (IBAction)togglePreviewPanel:(id)previewPanel;
    - (void) returnFocus;
    - (void) toggleIsTranslatedState: (NSXMLElement *)transUnit;
    - (BOOL) rowIsTranslated: (NSXMLElement *)transUnit;
    - (NSXMLElement *) selectedItem;
@end
