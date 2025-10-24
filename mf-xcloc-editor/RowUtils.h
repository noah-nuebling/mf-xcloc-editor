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
                else
                    return xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue ?: @""; /// ?: cause `<target>` sometimes doesnt' exist. [Oct 2025]
            }
        else assert(false);
        return nil;
    }
     static void _rowModel_setCellModel(NSXMLElement *transUnit, NSString *columnID, NSString *newValue) { /// This is only called from wrapper functions which use `NSUndoManager` [Oct 2025]
        if ((0)) {}
            else if ([columnID isEqual: @"id"])        xml_attr(transUnit, @"id")          .objectValue = newValue;
            else if ([columnID isEqual: @"source"])    xml_childnamed(transUnit, @"source").objectValue = newValue;
            else if ([columnID isEqual: @"target"])    xml_childnamed(transUnit, @"target").objectValue = newValue;
            else if ([columnID isEqual: @"note"])      xml_childnamed(transUnit, @"note")  .objectValue = newValue;
            else if ([columnID isEqual: @"state"]) {
                if ([newValue isEqual: kMFTransUnitState_DontTranslate])
                    xml_attr(transUnit, @"translate").objectValue = @"no";
                else
                    xml_attr((NSXMLElement *)xml_childnamed(transUnit, @"target"), @"state").objectValue = newValue;
            }
        else assert(false);
    };
    
    static BOOL isParentTransUnit(NSXMLElement *transUnit) { /// Detects the `%#@formatSstring@` of pluralizable strings (parent row)
        return [rowModel_getCellModel(transUnit, @"source") containsString: @"%#@"];
    }

#pragma mark - Other utils shared between TableView.m and SourceList.m

    static NSMutableAttributedString *make_green_checkmark(NSString *axDescription) {
        auto image = [NSImage imageWithSystemSymbolName: @"checkmark.circle" accessibilityDescription: axDescription]; /// TODO: This disappears when you double-click it.
        auto textAttachment = [NSTextAttachment new]; {
            [textAttachment setImage: image];
        }
        auto result = [NSMutableAttributedString attributedStringWithAttachment: textAttachment attributes: @{
            NSForegroundColorAttributeName: [NSColor systemGreenColor]
        }];
        return result;
    }
