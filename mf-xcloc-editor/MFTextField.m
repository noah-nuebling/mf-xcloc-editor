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

unichar returnChar =
    //u'¬'
    //u'⏎'
    //u'￢'
    //u'↵'
    u'↩'
;

- (void) drawGlyphsForGlyphRange: (NSRange)range atPoint: (NSPoint)point {
    
        /// Source: https://stackoverflow.com/a/29681234
      
      mflog(@"drawGlyphsForGlyphRange: %@ atPoint: %@", NSStringFromRange(range), @(point));
      
      /// Extend range
      ///   Cause range is often one specific, line, but whether we wanna draw the newline indicator on the previous line depends on current line content [Oct 2025]
      ///   TODO: Make this work
      if (range.location >= 1) {
        range.location   -= 1;
        range.length     += 1;
      }
      
      for (NSInteger i = range.location; i < NSMaxRange(range); i++) {
            
            NSInteger characterIndex    = [self characterIndexForGlyphAtIndex: i];
            unichar character           = [self.textStorage.string characterAtIndex: characterIndex];
            unichar nextCharacter       =
                (characterIndex+1 >= self.textStorage.string.length) ?
                0 :
                [self.textStorage.string characterAtIndex: characterIndex+1]
            ;
            unichar lastCharacter =
                (characterIndex-1 < 0) ?
                0 :
                [self.textStorage.string characterAtIndex: characterIndex-1]
            ;
            
            printf("%C", character);
            
            if (
                character == '\n' &&
                lastCharacter != '\n' && lastCharacter != 0 &&
                nextCharacter != '\n' && nextCharacter != 0  /// Translators can easily see blank lines – no need to highlight them.
            ) {
                NSFont* font = [self.textStorage attribute: NSFontAttributeName atIndex: characterIndex effectiveRange: NULL];
                
                printf("DRAW DA NEWLINE");
                NSInteger markerSize = 9;
                NSFontWeight markerWeight = NSFontWeightBold; /// Not sure it's affecting u'↩' – which we're currently using [Oct 2025]
                NSColor *markerColor = [NSColor secondaryLabelColor]; /// I kinda want something in-between secondaryLabelColor and tertiaryLabelColor
                
                NSPoint glyphPoint = [self locationForGlyphAtIndex: i];
                NSRect glyphRect = [self lineFragmentRectForGlyphAtIndex: i effectiveRange: NULL];
                { /// Don't understand but necessary for wrapping lines. Src: https://stackoverflow.com/a/576642/10601702
                    glyphPoint.x += glyphRect.origin.x;
                    glyphPoint.y = glyphRect.origin.y;
                }
                { /// Adjust position some by vibes
                    glyphPoint.y += (font.pointSize - markerSize) / 2.0 + 1; /// Center
                    glyphPoint.x += 2; /// Increase margin
                }
                [stringf(@"%C", returnChar) drawAtPoint: glyphPoint withAttributes: @{
                    NSFontAttributeName: [NSFont systemFontOfSize: markerSize weight: markerWeight],
                    NSForegroundColorAttributeName: markerColor
                }];

            }
        }
            
        [super drawGlyphsForGlyphRange: range atPoint: point];
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
