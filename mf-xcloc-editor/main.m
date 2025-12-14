//
//  main.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 08.06.25.
//

/// Unity Build Notes:
///     - Added in commit            699d089c9744fc67e938c012569f432b91d5b621
///     - Pre-unity-build commit: 0039deeef2c57d6523b7c245d161a102dc24eef4
///     - Kinda did this out of curiosity.
///     - Cost-benfit analysis: (Right after adding this, so don't have much experience, yet.)
///         - Pro:
///             - It's nice for quickly adding shared utility functions.
///                 - You could achieve the same with a normal build by using a header with static functions and importing that everywhere, but that starts slowing down builds – even in this tiny app it 3x'd the build-time from ~1s to ~3s  (See 0039deeef2c57d6523b7c245d161a102dc24eef4)
///                 - Counter: For stuff aside from utility functions, we still need headers for the most part.
///         - Con:
///             - Incremental builds are a little slower.
///                 Testing build-times after small change in `_shorten__func__()`: (M1 MBA with unity-build. [Dec 2025])
///                     Pre-unity build ->  1.3-1.5 secs     (But earlier I consistently measured 0.9-1.1)
///                     Unity build       ->  1.5-1.7 secs     (But earlier I consistently measured 1.1-1.3 – no idea where these fluctuations come from.)
///     - Build-time note:
///         #include is a little faster than #import and @import (I think, maybe random fluctuations.) [Dec 2025]

/// Framework imports for the entire program

#include <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <objc/runtime.h>
#include <objc/message.h>
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
#include "Utility/MFImplementMethod.m"
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
