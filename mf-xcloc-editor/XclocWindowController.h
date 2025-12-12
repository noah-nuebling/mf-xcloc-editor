//
//  XclocWindowController.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

    @interface XclocWindowController : NSWindowController <NSWindowDelegate, NSToolbarDelegate, NSSearchFieldDelegate>
        {
            /// Outlets
            ///     Get filled by -loadWindow [Oct 2025]
            @public
            SourceList  *out_sourceList;
            TableView   *out_tableView;
            NSTextField *out_filterField;
        }
    @end
