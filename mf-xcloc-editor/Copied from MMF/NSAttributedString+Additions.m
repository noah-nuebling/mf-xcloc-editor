//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSAttributedString+Additions.h"
#import "Utility.h"

@implementation NSAttributedString (Additions)

#pragma mark Determine size

#define NSNotFoundRect NSMakeRect(NSNotFound, NSNotFound, 0, 0)
static NSRect MFUnionRect(NSRect r, NSRect s) {
    
    /// Copied from mac-mouse-fix [Nov 2025]
    
    if (r.origin.x == NSNotFound || r.origin.y == NSNotFound) return s;
    if (s.origin.x == NSNotFound || s.origin.y == NSNotFound) return r;
    
    CGFloat minX, maxX;
    CGFloat minY, maxY;
    
    minX = MIN(r.origin.x, s.origin.x);
    maxX = MAX(NSMaxX(r), NSMaxX(s));
    minY = MIN(r.origin.y, s.origin.y);
    maxY = MAX(NSMaxY(r), NSMaxY(s));
    
    return (NSRect){ { .x = minX, .y = minY }, { .width = maxX-minX, .height = maxY-minY } };

}

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    
    /// Notes:
    /// - Why didn't we use the native `boundingRectWithSize:`? Was there really no way to make it work? Well this works so no need to change it.
    
    if (@available(macOS 12.0, *)) {
        
        /// TextKit 2 Implementation
        ///     v2 APIs were introduced in macOS 12
        ///     See WWDC intro: https://developer.apple.com/videos/play/wwdc2021/10061/
        
        /// Create objects
        NSTextLayoutManager *textLayoutManager;
        NSTextContentStorage *textContentStorage;
        NSTextContainer *textContainer;
        {
        
            /// Create v2 layoutMgr
            textLayoutManager = [[NSTextLayoutManager alloc] init];
            
            /// Create v2 contentMgr
            textContentStorage = [[NSTextContentStorage alloc] init];
            
            /// Create container
            textContainer = [[NSTextContainer alloc] initWithSize: CGSizeMake(maxWidth, CGFLOAT_MAX)]; /// `initWithContainerSize:` was deprecated in macOS 12
            textContainer.lineFragmentPadding = 0; /// 5.0 by default which makes the result always be smaller than the maxWidth (I think) [Sep 2025]
        }
        
        /// Link objects
        {
            /// Link contentMgr -> self
            [textContentStorage setAttributedString:self];
            
            /// Link layoutMgr -> container
            [textLayoutManager setTextContainer:textContainer];
            
            /// Link layoutMgr -> contentMgr
            [textLayoutManager replaceTextContentManager:textContentStorage];
            [textContentStorage setPrimaryTextLayoutManager:textLayoutManager]; /// Not sure if necessary
        }
        
        /// Get size from layoutMgr
        __block NSRect resultRect;
        {
            /// On options:
            ///     - `NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment` is for ensuring layout consistency with editable text, which we don't need here.
            ///     - `NSTextLayoutFragmentEnumerationOptionsEstimatesSize` is a faster, but less accurate alternative to `NSTextLayoutFragmentEnumerationOptionsEnsuresLayout`
            resultRect = NSNotFoundRect;
            NSTextLayoutFragmentEnumerationOptions enumerationOptions = (
                NSTextLayoutFragmentEnumerationOptionsEnsuresLayout |
                NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment /// Doesn't seem to make a difference [Oct 2025]
            );
            [textLayoutManager enumerateTextLayoutFragmentsFromLocation: nil options: enumerationOptions usingBlock: ^BOOL(NSTextLayoutFragment * _Nonnull layoutFragment) {
                resultRect = MFUnionRect(resultRect, layoutFragment.layoutFragmentFrame);
                return YES;
            }];
        }
        
        /// Return
        return resultRect.size;
        
    } else {

        /// TextKit v1 implementation
        ///     Originally Copied from here https://stackoverflow.com/a/33903242/10601702
        
        /// [Jul 2025] Note from master branch (Copying this over while merging master into feature-strings-catalog) (master used a slightly older implementation of the TextKit v1 implementation, so this might not apply here)
        ///     I think the text on the TrialNotification was too short in Chinese due to this. (See 83c6812740c176f8b2ec084c7d5798a5d2968b57)
        ///     I did some minimal testing on the TrialNotification and this seemed consistently smaller than the real size of the NSTextView when there were Chinese characters, while matching exactly, when there were only English characters. Update: Yep the Toasts are also too small in Chinese due to this. (macOS Sequoia 15.5)
        ///     TODO: Maybe review other uses of this in Chinese.
        ///     If this doesn't work reliably, perhaps you always have to layout your NSTextView / NSTextField and then measure that. Or perhaps you can solve all this stuff by just using autolayout constraints directly?
        
        /// Create objects
        NSLayoutManager *layoutManager;
        NSTextStorage *textStorage;
        NSTextContainer *textContainer;
        {
            /// Create layoutMgr
            layoutManager = [[NSLayoutManager alloc] init];

            /// Create content
            textStorage = [[NSTextStorage alloc] init];
            
            /// Create container
            textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
            textContainer.lineFragmentPadding = 0.0; /// Copied from the TextKit v2 implementation. Untested [Sep 2025]
        }
        
        /// Link objects
        {
            /// Link content -> self
            [textStorage setAttributedString:self]; /// This needs to happen before other linking steps, otherwise it won't work. Not sure why.
            
            /// Link layoutMgr -> container
            [layoutManager addTextContainer:textContainer];
            
            /// Link layoutMgr -> content
            [layoutManager replaceTextStorage:textStorage];
            [textStorage addLayoutManager:layoutManager]; /// Not sure if necessary
        }

        /// Force glyph generation & layout
        NSInteger numberOfGlyphs = [layoutManager numberOfGlyphs];                  /// Forces glyph generation
        [layoutManager ensureLayoutForGlyphRange:NSMakeRange(0, numberOfGlyphs)];   /// Forces layout
        
        /// Get size from layoutMgr
        NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
        
        /// Return
        return size;
    }

}

#pragma mark Fill out base

- (NSAttributedString *)attributedStringByFillingOutBase {
    
    /// Fill out default attributes, because layout code won't work if the string doesn't have a font and a textColor attribute on every character. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
    
    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.systemFontSize],
        NSForegroundColorAttributeName: NSColor.labelColor,
        NSFontWeightTrait: @(NSFontWeightMedium),
    };
    
    return [self attributedStringByAddingAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByFillingOutBaseAsHint {
    
    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
        NSFontWeightTrait: @(NSFontWeightRegular), /// Not sure whether to use medium or regular here
    };
    
    return [self attributedStringByAddingAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByAddingAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes {
    
    /// Create string by adding values from `baseAttributes`, without overriding any of the attributes set for `self`
    
    NSMutableAttributedString *result = [self mutableCopy];
    
    /// Add baseAttributes
    ///     baseAttributes will override current attributes
    [result addAttributes: baseAttributes range: NSMakeRange(0, result.length)];
    
    /// Add original string attributes
    ///     to undo overrides by the baseAttributes
    [self enumerateAttributesInRange: NSMakeRange(0, result.length) options: 0 usingBlock: ^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        [result addAttributes: attrs range: range];
    }];
    
    return result;
}

@end
