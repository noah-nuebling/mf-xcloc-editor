//
//  main.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

/// Framework imports for the entire program
///     Build-time notes: #include is a little faster than #import and @import (I think) [Dec 2025]

#include <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <objc/runtime.h>
#include <QuickLookUI/QuickLookUI.h>

/// Main

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

/// Imports of local files

#include "Constants.h"

#include "Copied from MMF/NSAttributedString+Additions.m"

#include "Utility/Utility.h"
#include "Utility/MFUI.m"
#include "Utility/NSObject+Additions.m"
#include "Utility/ToString.m"
#include "Utility/NSNotificationCenter+Additions.m"
#include "Utility/NSView+Additions.m"
#include "Utility/RowUtils.h"

/// Forward declares
#include "SourceList.h"            /// XclocWindowController.h depends on @class SourceList [Dec 2025]
#include "TableView.h"             /// XclocWindowController.h depends on @class TableView  [Dec 2025]
#include "XclocWindowController.h" /// XclocDocument.m Depends on           @class XclocWindowController [Dec 2025]
#include "XclocDocument.h"         /// SourceList.m depends on getdoc()     [Dec 2025]

/// More imports of local files.
#include "MFTextField.m"
#include "SourceList.m"
#include "TableView.m"

#include "XclocDocument.m"
#include "XclocWindowController.m"
#include "XclocDocumentController.m"

#include "AppDelegate.m"
