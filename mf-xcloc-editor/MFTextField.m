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

/// Also see:
///     https://stackoverflow.com/questions/34504031/control-spacing-around-custom-text-attributes-in-nslayoutmanager

double newlineMarkerWidth = 0.0 /*15.0*/; /// Try to stop newline marker from being cut-off right before wrapping. Works but now there's inconsistency between the MFTextField and MFInvisiblesTextView we swap in for it causing text to get cut of :(. Maybe solvable but there's sooo much code here already for this tiny tiny thing.I give up. (Set to 0.0)

@interface MFInvisiblesTextContainer : NSTextContainer @end
@implementation MFInvisiblesTextContainer

    - (NSRect)lineFragmentRectForProposedRect:(NSRect)proposedRect
                                      atIndex:(NSUInteger)characterIndex
                             writingDirection:(NSWritingDirection)baseWritingDirection
                                remainingRect:(NSRectPointer)remainingRect {
        
        NSRect rect = [super lineFragmentRectForProposedRect:proposedRect
                                                     atIndex:characterIndex
                                            writingDirection:baseWritingDirection
                                               remainingRect:remainingRect];
        
        rect.size.width -= newlineMarkerWidth; /// Make lines wrap before they cut off the newlineMarker
        
        mflog(@"lineFragmentRectForProposedRect: %@", NSStringFromRect(rect));
        
        return rect;
    }

@end

@interface MFInvisiblesLayoutManager : NSLayoutManager <NSLayoutManagerDelegate> @end

@implementation MFInvisiblesLayoutManager

    /// NSLayoutManager that visualizes invisible characters like linebreaks
    ///     Can be attached to an NSTextView
    ///     (I also tried adding invisibles to NSTextField but could just not figure out where it does it's drawing – it's all private APIs) [Oct 2025]

    unichar returnChar =
        //u'¬'
        //u'⏎'
        //u'￢'
        //u'↵'
        u'↩' // LOok nice
    ;

    - (instancetype)init {
        if (self = [super init]) [self commonInit];
        return self;
    }
    - (instancetype)initWithCoder:(NSCoder *)coder {
        if (self = [super initWithCoder: coder]) [self commonInit];
        return self;
    }
    
    - (void) commonInit {
        if ((0)) [self setShowsInvisibleCharacters: YES]; /// This looks bad and doesn't show newlines.
        self.delegate = self;
    }
    

    NSRect MFInsetRect(NSRect r, CGFloat top, CGFloat bottom, CGFloat left, CGFloat right) {
        
        return NSMakeRect(
            r.origin.x + left,
            r.origin.y + top,
            r.size.width - left - right,
            r.size.height - top - bottom
        );
    }
    
    - (void)processEditingForTextStorage:(NSTextStorage *)textStorage edited:(NSTextStorageEditActions)editMask range:(NSRange)newCharRange changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange {
        
        /// This is called whenever the text is edited.
        ///     See [NSTextStorage processEditing] documentation [Oct 2025]
        
        /// Log
        mflog(@"invalidatedCharRange: %@, textStorage.string.length: %ld", NSStringFromRange(invalidatedCharRange), textStorage.string.length);
        
        /// Get the newline glyph at the end of the Nth line to update when the content of the N+1th line changes.
        ///     See `drawGlyphsForGlyphRange:`
        if (editMask & NSTextStorageEditedCharacters) {
            
            { /// Try prevent the newline glyphs from being cut off
              
                if ((0)) /// Works a little but doesn't update when resizing while the indicators are displayed.
                {
                    NSTextContainer *textContainer = self.textContainers.firstObject;
                    
                    NSRect exclusionRect = MFInsetRect(
                        (NSRect) { .origin = {}, .size = textContainer.size },
                        0, 0, textContainer.containerSize.width-10, 0
                    );
                    
                    [textContainer setExclusionPaths: @[
                        [NSBezierPath bezierPathWithRect: exclusionRect]
                    ]];
                }
                
                if ((0)) self.textContainers.firstObject.lineFragmentPadding = 10;
            }
            
            
            /// Try to call super with extended range
            ///     ... Works
            if ((1)) {
                
                NSRange extendedRange = newCharRange;
                if (extendedRange.location >= 1) {
                    extendedRange.location -= 1;
                    extendedRange.length += 1;
                }
                
                [super processEditingForTextStorage: textStorage edited: editMask range: newCharRange changeInLength: delta invalidatedRange: extendedRange];
            }
            
            /// Invalide display
            ///     THROWS out of range exceptions inside TextKit no matter what (macOS Tahoe)
            /**
                But Apple docs say
                Finally, the text storage object sends the processEditingForTextStorage:edited:range:changeInLength:invalidatedRange: message to each associated layout manager—indicating the range
                 in the text storage object that has changed, along with the nature of those changes.
                 The layout managers in turn use this information to recalculate their glyph locations AND REDISPLAY IF NECESSARY.
            */
            if ((0)) {
                [self invalidateGlyphsForCharacterRange: newCharRange changeInLength: delta actualCharacterRange: nil];
                if ((0)) [self invalidateDisplayForCharacterRange: NSMakeRange(0,  textStorage.length + textStorage.changeInLength)];
                if ((0)) [self drawGlyphsForGlyphRange: newCharRange atPoint: NSMakePoint(0, 0)];
            }
        }
    }

    static CGGlyph glyphForCharacter(unichar character, NSFont *font) {
        CGGlyph glyph = 0;
        bool succ = CTFontGetGlyphsForCharacters((__bridge void *)font, (unichar[]) { character }, &glyph, 1);
        assert(succ);
        return glyph;
    }

    - (void) drawGlyphsForGlyphRange: (NSRange)range atPoint: (NSPoint)point {
    
        /// Source: https://stackoverflow.com/a/29681234
        ///     IN the SO solution, newlines aloso get cut-off
    
        mflog(@"drawGlyphsForGlyphRange: %@ atPoint: %@", NSStringFromRange(range), @(point));
        
        if ((0)) /// Crashes immediately
        {
            [self firstTextView].frame = MFInsetRect(
                [self firstTextView].frame,
                0, 0, 0, 10
            );
        }
        
        if ((1))
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
            
            if (
                character == '\n' &&
                lastCharacter != '\n' && lastCharacter != 0 &&
                nextCharacter != '\n' && nextCharacter != 0  /// Translators can easily see blank lines – no need to highlight them.
            ) {
                NSFont* font = [self.textStorage attribute: NSFontAttributeName atIndex: characterIndex effectiveRange: NULL];
                
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
@implementation MFInvisiblesTextView
    
    - (instancetype)initWithFrame:(CGRect)frame {
        if (self = [super initWithFrame:frame]) [self commonInit];
        return self;
    }
    - (instancetype)initWithCoder:(NSCoder *)coder {
        if (self = [super initWithCoder:coder]) [self commonInit];
        return self;
    }
    - (void) commonInit {
        {
            MFInvisiblesTextContainer *container = [[MFInvisiblesTextContainer alloc] initWithSize: self.bounds.size];
            container.widthTracksTextView = YES;
            [self replaceTextContainer: container];
        }
        [[self textContainer] replaceLayoutManager: [MFInvisiblesLayoutManager new]];
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
            
                auto maxWidth = self.frame.size.width - 4.0; /// Has to be exactly -4.0. Not sure why. This might be `self.currentEditor.textContainer.lineFragmentPadding * 2` [Oct 2025]
                maxWidth -= newlineMarkerWidth;
                newResult = [attrStr sizeAtMaxWidth: maxWidth];
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
    
    #pragma mark - Old stuff

    #if 0 /// Try to insert linebreak marker such that the layout system knows about it and it doesn't get cut off   - - - Doesn't work. Don't know why. Spent the whole day. Giving up. Angery now.
        - (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)charIndexes font:(NSFont *)aFont forGlyphRange:(NSRange)glyphRange {
            
            /// https://stackoverflow.com/a/57697139/10601702
            
            NSMutableArray *glyphsNS = [NSMutableArray new];
            NSMutableArray *charsNS = [NSMutableArray new];
            
            NSGlyphProperty *mutableProps = malloc(glyphRange.length * sizeof(NSGlyphProperty) * 2); /// `*2` in case we wanna insert the linebreak glyph instead of replacing the default linebreak glyph (65535) (But that also doesn't work) [Oct 2025])
            CGGlyph *mutableGlyphs = malloc(glyphRange.length * sizeof(CGGlyph) * 2);
            NSUInteger *mutableCharIndexes = malloc(glyphRange.length * sizeof(NSUInteger) * 2);
            
            NSInteger i = 0;
            NSInteger j = 0;
            for (;;) {
                
                if (i >= glyphRange.length) break;  // changed from NSMaxRange(glyphRange)
                
                /// Record stuff for logging
                [glyphsNS addObject: stringf(@"%ld: %@", i, @(glyphs[i]))];
                [charsNS addObject: stringf(@"%ld: %C", i, [self.textStorage.string characterAtIndex: charIndexes[i]])];
                
                if ([self.textStorage.string characterAtIndex: charIndexes[i]] == '\n')
                { /// Doesn't work – has no effect, except if we set NSGlyphPropertyNull, which hides the first character of the next line for some reason.
                  ///   when we do the same replacement in `drawGlyphsForGlyphRange:`, then the glyph does show up, but it's not taken into account by layout calculations, and gets cut off when the NSTextView gets narrow (but not narrow enough to wrap the line)
                    mutableGlyphs[j]      = glyphForCharacter(u'c'/*u'⏎'*/, aFont);
                    mutableProps[j]       = 0 /* | NSGlyphPropertyNull*/;
                    mutableCharIndexes[j] = charIndexes[i];
                }
                else
                {
                    mutableGlyphs[j] = glyphs[i];
                    mutableProps[j] = props[i];
                    mutableCharIndexes[j] = charIndexes[i];
                }
                
                i++;
                j++;
            }
            
            /// Log
            mflog(@"shouldGenerateGlyphs: glyhps: %@, props: %@, chars: %@, font: %@, glyphRange: %@", glyphsNS, @(*props), charsNS, aFont, NSStringFromRange(glyphRange));
            
            
            /// Copy over result
            [self setGlyphs: mutableGlyphs properties: mutableProps characterIndexes: mutableCharIndexes font: aFont forGlyphRange: NSMakeRange(glyphRange.location, j)];
            
            /// Cleanup
            free(mutableGlyphs);
            free(mutableProps);
            free(mutableCharIndexes);
            
            /// Return
            return j; /// Don't understand this
            
        }
    #endif

@end
