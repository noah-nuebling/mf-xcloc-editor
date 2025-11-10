//
//  Constants.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

/// Some uiStrings are in the code, some are here. Whatever works. [Nov 2025]

#define kMFStr_Separator                @"Project Files"
#define kMFPath_AllDocuments            @"All Project Files"
#define kMFStr_FilterTranslations       @"Filter Translations (⌘F)"
#define kMFStr_MarkForReview            @"Mark for Review"
#define kMFStr_MarkAsTranslated         @"Mark as Translated" /// @"Mark as Reviewed" | Formerly 'Mark as Translated' – use "Review" in both variants so it's searchable.
#define kMFStr_RevealInFile(doc, transUnit) ({ \
    auto _name = [(doc)->ctrl->out_sourceList filenameForTransUnit: (transUnit)]; \
    _name ? stringf(@"Show in '%@'", _name) : @"Show in File";      /** The fallback is for `[AppDelegate validateMenuItem:]` [Nov 2025] */\
})
    
#define kMFStr_RevealInAll                      stringf(@"Show in '%@'", kMFPath_AllDocuments)

#define kMFStr_MarkForReview_Symbol     @"circle"
#define kMFStr_MarkAsTranslated_Symbol  @"checkmark.circle"
#define kMFStr_RevealInFile_Symbol      @"document"
#define kMFStr_RevealInAll_Symbol       (@"document.on.document"/*@"document.viewfinder"*/)

