//
//  TableView.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "QuickLookUI/QuickLookUI.h"

@interface TableView : NSTableView
    <
        NSTableViewDataSource,
        NSTableViewDelegate,
        NSControlTextEditingDelegate,
        NSMenuItemValidation,
        QLPreviewPanelDelegate,
        QLPreviewPanelDataSource
    >
    @property(nonatomic) NSArray *localizedStringsDataPlist; /// Plist mapping localizedStrings to screenshots [Oct 2025]
    @property(nonatomic) NSArray <NSXMLElement *> *transUnits; /// Section of an XLIFF file that this table displays [Jun 2025]
    - (void) reloadWithNewData: (NSArray <NSXMLElement *> *)transUnits;
    - (void) updateFilter: (NSString *)newFilterString;
    - (IBAction)togglePreviewPanel:(id)previewPanel;
@end
