//
//  MFTextField.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

#import "MFTextField.h"
#import "Utility.h"
#import "NSAttributedString+Additions.h"
#import "NSObject+Additions.h"


@implementation MFInvisiblesLayoutManager

    /// NSLayoutManager that visualizes invisible characters like linebreaks
    ///     Can be attached to an NSTextView
    ///     (I also tried adding invisibles to NSTextField but could just not figure out where it does it's drawing – it's all private APIs) [Oct 2025]

    - (void)drawGlyphsForGlyphRange:(NSRange)range atPoint:(NSPoint)point {
    
        /// Source: https://stackoverflow.com/a/29681234
    
      NSTextStorage* storage = self.textStorage;
      NSString* string = storage.string;
      for (NSUInteger glyphIndex = range.location; glyphIndex < range.location + range.length; glyphIndex++) {
            NSUInteger characterIndex = [self characterIndexForGlyphAtIndex: glyphIndex];
            switch ([string characterAtIndex:characterIndex]) {
                break;
                case ' ':
                if ((0)) {
                    NSFont* font = [storage attribute: NSFontAttributeName atIndex: characterIndex effectiveRange:NULL];
                    [self replaceGlyphAtIndex:glyphIndex withGlyph: [font glyphWithName: @"periodcentered"]];
                }

                break;
                case '\n': {
                    NSFont* font = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
                    /// Get glyph for return symbol character
                    /// Use CTFont with font fallback to support characters not in the base font
                    unichar returnChar =
                        u'¬'
                        //u'⏎'
                        //u'￢' // not works
                        //u'↵'  // not works
                        //u'↩'  // not works
                    ;
                    CGGlyph returnGlyph; /// TODO: Use a better glyph [Oct 2025]
                    
                    CTFontGetGlyphsForCharacters((__bridge void *)font, &returnChar, &returnGlyph, 1);

                    if (returnGlyph != 0)
                        [self replaceGlyphAtIndex:glyphIndex withGlyph: returnGlyph];
                    else {
                        assert(false);

                    }
                }
            }
        }

        [super drawGlyphsForGlyphRange:range atPoint:point];
    }

    - (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSUInteger)glyphCount font:(NSFont *)font textMatrix:(CGAffineTransform)textMatrix attributes:(NSDictionary *)attributes inContext:(CGContextRef)graphicsContext {

        /// TODO: This doesn't gray-out consecutive linebreaks correctly.

        /// Draw glyphs individually so we can set different opacity for newline symbols
        NSTextStorage* storage = self.textStorage;
        NSString* string = storage.string;

        NSRange glyphRange = NSMakeRange([self glyphIndexForPoint:positions[0] inTextContainer:self.textContainers.firstObject fractionOfDistanceThroughGlyph:NULL], glyphCount);

        for (NSUInteger i = 0; i < glyphCount; i++) {
            NSUInteger glyphIndex = glyphRange.location + i;
            if (glyphIndex < [self numberOfGlyphs]) {
                NSUInteger characterIndex = [self characterIndexForGlyphAtIndex:glyphIndex];
                if (characterIndex < string.length && [string characterAtIndex:characterIndex] == '\n') {
                    CGContextSaveGState(graphicsContext);
                    CGContextSetAlpha(graphicsContext, 0.3);
                    [super showCGGlyphs:&glyphs[i] positions:&positions[i] count:1 font:font textMatrix:textMatrix attributes:attributes inContext:graphicsContext];
                    CGContextRestoreGState(graphicsContext);
                } else {
                    [super showCGGlyphs:&glyphs[i] positions:&positions[i] count:1 font:font textMatrix:textMatrix attributes:attributes inContext:graphicsContext];
                }
            }
        }
    }

@end

@implementation MFTextField

    ///
    /// NSTextField that auto-resizes while being edited.
    ///     NSTextField doesn't have intrinsicHeight when editable. (Which means it won't work right with autolayout) This does have intrinsicHeight..
    ///     Used in the `@target"` column of `TableView` [Oct 2025]
    ///     Discussion: For the ToastNotifications in MMF I reverse-engineered how NSTextField does its auto-layout-support and decided it was too hard and went with programmatic layout instead.
    ///         But this seems to work well (at least embedded in an `NSTableView` - where the width is fixed to the column width, which may make things easier) [Oct 2025]

    {
        CGFloat lastWidth;
        BOOL expectingFieldEditor;
        BOOL isCoolFirstResponder;
    }
    
    - (instancetype)initWithFrame:(NSRect)frame {
        self = [super initWithFrame:frame];
        if (self) realInit(self);
        return self;
    }
    
    - (instancetype)initWithCoder:(NSCoder *)coder {
        self = [super initWithCoder:coder];
        if (self) realInit(self);
        return self;
    }

    #pragma mark - First responder status
        /// (Copied into mf-xcloc-editor from mac-mouse-fix) [Oct 2025]
        /// This is absolutely terrible and hacky. Could we just subclass the fieldEditor and track its firstResponder status? Or just use NSTextView everywhere? [Oct 2025]

        - (BOOL)resignFirstResponder {
            /// For some reason resignFirstResponder() is always called before becomeFirstResponder() ?

            BOOL success = [super resignFirstResponder];

            mflog(@"Raw resignFirstResponder (%p)", self);

            if (success) {
                self->expectingFieldEditor = YES;
            }

            return success;
        }

        - (BOOL)becomeFirstResponder {

            if (![self coolValidateProposedFirstResponder]) return NO;

            BOOL success = [super becomeFirstResponder];

            mflog(@"Raw becomeFirstResponder (%p)", self);

            if (success && self->expectingFieldEditor) {
                /// Call cool function
                self->isCoolFirstResponder = YES;
                [self coolDidBecomeFirstResponder];
            }
            self->expectingFieldEditor = NO;

            return success;
        }
        - (void)controlTextDidEndEditing:(NSNotification *)obj {
            mflog(@"Raw controlTextDidEndEditing: (%p)", self);
        }

        - (void)textDidEndEditing:(NSNotification *)notification {
            [super textDidEndEditing: notification];

            mflog(@"Raw textEndEditing (%p)", self);
            
            /// Not called when hitting escape, we're calling it manually. See @"MFHACK" [Oct 2025]

            /// Call cool function
            if (self->isCoolFirstResponder) {
                self->isCoolFirstResponder = NO;
                [self coolDidResignFirstResponder];
            }
        }

        /// Subclass overridable firstResponder functions
        ///     (Not needed for mf-xcloc-editor – this was copied from mac-mouse-fix)
        #if 0
            - (BOOL)coolValidateProposedFirstResponder {
                return YES;
            }

            - (void)coolDidBecomeFirstResponder {
                /// Override
            }

            - (void)coolDidResignFirstResponder {
                /// Override
            }

        #endif
        
        /// Overrides of 'Subclass overridable firstResponder functions'
        
        - (BOOL)coolValidateProposedFirstResponder {
            return YES;
        }
        - (void) coolDidBecomeFirstResponder {
            mflog(@"MFTextField became firstRespondeer: %@", self);
            [[NSNotificationCenter defaultCenter] postNotificationName: @"MFTextField_BecomeFirstResponder"
                                                                object: self
                                                              userInfo: @{}];
        }

        - (void) coolDidResignFirstResponder {
            mflog(@"MFTextField resigned firstResponder: %@", self);
            /// Post notification so TableView can reload the source cell
            [[NSNotificationCenter defaultCenter] postNotificationName: @"MFTextField_ResignFirstResponder"
                                                                object: self
                                                              userInfo: @{}];
        }

    #pragma mark AutoLayout support
    
        static void realInit(MFTextField *self) {
            [[NSNotificationCenter defaultCenter] addObserverForName: NSControlTextDidChangeNotification object: self queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
                [self setNeedsUpdateConstraints: YES]; /// Call `intrinsicContentSize` again
            }];
        }
        
        - (void)layout {
            [super layout];

            if (self.frame.size.width != self->lastWidth) {
                self->lastWidth = self.frame.size.width;
                [self setNeedsUpdateConstraints: YES]; /// Call `intrinsicContentSize` again || Sidenote: Could maybe also do this in `setFrame:` instead of `layout` - that called at around the same times.[Oct 2025]
            }
        }
        
        - (NSSize) intrinsicContentSize {
            auto result = [super intrinsicContentSize];
            auto newResult = result;
            {
                auto attrStr = [self.attributedStringValue attributedStringByAddingAttributesAsBase: @{ /// Fill out attributes so `sizeAtMaxWidth:` works correctly [Oct 2025]
                    NSFontAttributeName: self.font,
                    NSForegroundColorAttributeName: self.textColor,
                }];
            
                newResult = [attrStr sizeAtMaxWidth: self.frame.size.width - 4.0]; /// Has to be exactly -4.0. Not sure why. This might be `self.currentEditor.textContainer.lineFragmentPadding * 2` [Oct 2025]
                newResult.height += 2.0; /// Without `+2`, the content shifts slightly up/down when MFTextField is in the tallest cell in the row and you add / remove text lines from it. [Oct 2025]
            }
            return newResult;
        }
        
        /// Old logging stuff (This is how we figured this out)
        #if 0
        
            static int _logCount = 0;
        
            #define log(msg...) \
                mflog(@"%@ / %@%@", @(_logCount++), stringf(@"row %@: ", [self mf_associatedObjectForKey: @"MFTextField_Row"]), stringf(msg))
            
            - (void) _logSize {
                log(@"   frame: %@", NSStringFromRect(self.frame));
            }

            - (void)layoutSubtreeIfNeeded {
                [super layoutSubtreeIfNeeded];
                log(@"MFTextField called 'layoutSubtreeIfNeeded'");
                [self _logSize];
            }
            - (void)setFrame:(NSRect)frame {
                [super setFrame: frame];
                
                log(@"MFTextField called 'setFrame' – %@", @(frame));
                [self _logSize];
            }

            - (NSSize)fittingSize {
                auto result = [super fittingSize];
                log(@"MFTextField called 'fittingSize' – %@", @(result));
                [self _logSize];
                return result;
            }
            
            - (NSSize)sizeThatFits:(NSSize)size {
                auto result = [super sizeThatFits: size];
                log(@"MFTextField called 'sizeThatFits:' – %@", @(result));
                [self _logSize];
                return result;
            }
            
            - (void)sizeToFit {
                [super sizeToFit];
                log(@"MFTextField called 'sizeToFit'");
                [self _logSize];
            }
        #endif
        
@end
