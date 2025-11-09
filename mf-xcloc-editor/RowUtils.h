//
//  RowMUtils.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/24/25.
//

/// Created to share rowModel parsing logic from `TableView.m` with `SourceList.m` (To implement localization-progress indicators)[Oct 2025]

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Utility.h"


#pragma mark - RowModelUtils

    #define kMFTransUnitState_Translated      @"translated"
    #define kMFTransUnitState_DontTranslate   @"mf_dont_translate"
    #define kMFTransUnitState_New             @"new"
    #define kMFTransUnitState_NeedsReview     @"needs-review-l10n"
    #define kMFTransUnitState_NeedsReview2    @"needs-translation" /// Saw the app crash on this. Can't reproduce. May have been editing the file with Xcode. Was loca studio ja.xcloc example.. Will map this to `kMFTransUnitState_NeedsReview` just in case.
    static auto _stateOrder = @[ /// Order of the states to be used for sorting [Oct 2025]
        kMFTransUnitState_New,
        kMFTransUnitState_NeedsReview,
        kMFTransUnitState_Translated,
        kMFTransUnitState_DontTranslate
    ];

    /// Column-ids
    ///     ... Actually feels fine just using the strings directly [Oct 2025]
    #define kColID_ID       @"id"
    #define kColID_State    @"state"
    #define kColID_Source   @"source"
    #define kColID_Target   @"target"
    #define kColID_Note     @"note"

     static NSString *rowModel_getCellModel(NSXMLElement *transUnit, NSString *columnID) {
        if ((0)) {}
            else if ([columnID isEqual: @"id"])        return xml_attr(transUnit, @"id")           .objectValue;
            else if ([columnID isEqual: @"source"])    return xml_childnamed(transUnit, @"source") .objectValue;
            else if ([columnID isEqual: @"target"])    return xml_childnamed(transUnit, @"target") .objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
            else if ([columnID isEqual: @"note"])      return xml_childnamed(transUnit, @"note")   .objectValue;
            else if ([columnID isEqual: @"state"]) {
                if ([xml_attr(transUnit, @"translate").objectValue isEqual: @"no"])
                    return kMFTransUnitState_DontTranslate;
                else {
                    NSString *state = xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue ?: kMFTransUnitState_New;
                    if ([state isEqual: kMFTransUnitState_NeedsReview2])
                        state = kMFTransUnitState_NeedsReview;
                    return state;
                }
            }
        else assert(false);
        return nil;
    }
     static void _rowModel_setCellModel(NSXMLElement *transUnit, NSString *columnID, NSString *newValue) { /// This is only called from wrapper functions which use `NSUndoManager` [Oct 2025]
        #define new_attr() [[NSXMLNode alloc] initWithKind: NSXMLAttributeKind]
        #define new_el()   [NSXMLElement new]
        
        if ((0)) {}
            else if ([columnID isEqual: @"target"])    xml_childnamed(transUnit, @"target", .fallback=new_el()).objectValue = newValue;
            else if ([columnID isEqual: @"state"]) {
                if ([newValue isEqual: kMFTransUnitState_DontTranslate])
                    xml_attr(transUnit, @"translate", .fallback=new_attr()).objectValue = @"no";
                else {
                    NSXMLElement *el = (id)xml_childnamed(transUnit, @"target", .fallback=new_el());
                    xml_attr(el, @"state", .fallback=new_attr()).objectValue = newValue;
                }
            }
        else assert(false); /// Only handle @"target" and @"state" cause we never wanna edit the other stuff [Oct 2025]
    };
    
    static BOOL rowModel_isPluralParent(NSXMLElement *transUnit) { /// Detects the `%#@formatSstring@` of pluralizable strings (parent row)
        return [rowModel_getCellModel(transUnit, @"source") containsString: @"%#@"];
    }
    static BOOL rowModel_isPluralChild(NSXMLElement *transUnit) { /// Detects the `|==|` separator found in pluralizable variants (child rows). We also expect the children to always be preceeded by parent. [Nov 2025]]
        return [xml_attr(transUnit, @"id").objectValue containsString: @"|==|"];
    }
        

#pragma mark - Other utils shared between TableView.m and SourceList.m

    static NSMutableAttributedString *make_green_checkmark(NSString *axDescription) {
        auto image = [NSImage imageWithSystemSymbolName: @"checkmark.circle" accessibilityDescription: axDescription];
        auto textAttachment = [NSTextAttachment new]; {
            [textAttachment setImage: image];
        }
        
        NSMutableAttributedString *result = [[NSAttributedString attributedStringWithAttachment: textAttachment] mutableCopy];
        [result addAttributes: @{
            NSForegroundColorAttributeName: [NSColor systemGreenColor]
        } range: NSMakeRange(0, result.length)];
        return result;
    }
