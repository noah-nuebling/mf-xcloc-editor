//
//  TableView.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface TableView : NSTableView <NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate, NSMenuItemValidation>
    @property(strong, nonatomic) NSXMLElement *data; /// Section of an XLIFF file that this table displays [Jun 2025]
    - (void) reloadWithNewData: (NSXMLElement *)data;
@end
