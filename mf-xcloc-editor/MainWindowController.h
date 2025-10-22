//
//  MainWindowController.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import <Foundation/Foundation.h>
#import "SourceList.h"
#import "TableView.h"

@interface MainWindowController : NSObject <NSWindowDelegate>

    typedef struct {
        SourceList *sourceList;
        TableView *tableView;
        NSTextField *filterField;
    } Outlets;
    
    - (Outlets) makeMainWindow;

@end
