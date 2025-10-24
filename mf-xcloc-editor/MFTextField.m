//
//  MFTextField.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/23/25.
//

///
/// NSTextField that auto-resizes while being edited.
///     NSTextField doesn't have intrinsicHeight when editable. (Which means it won't work right with autolayout) This does have intrinsicHeight..
///     Used in the `@target"` column of `TableView` [Oct 2025]
///     Discussion: For the ToastNotifications in MMF I reverse-engineered how NSTextField does its auto-layout-support and decided it was too hard and went with programmatic layout instead.
///         But this seems to work well (at least embedded in an `NSTableView` - where the width is fixed to the column width, which may make things easier) [Oct 2025]
///

#import "MFTextField.h"
#import "Utility.h"
#import "NSAttributedString+Additions.h"
#import "NSObject+Additions.h"

@implementation MFTextField
    {
        CGFloat lastWidth;
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
    
    void realInit(MFTextField *self) {
        [[NSNotificationCenter defaultCenter] addObserverForName: NSControlTextDidChangeNotification object: self queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
            [self setNeedsUpdateConstraints: YES]; /// Call `intrinsicContentSize` again
        }];
    }
    
    - (void)layout {
        [super layout];

        if (self.frame.size.width != self->lastWidth) {
            self->lastWidth = self.frame.size.width;
            [self setNeedsUpdateConstraints: YES]; /// Call `intrinsicContentSize` again || Sidenote: Could maybe also do this in `setFrame:` instead of `layout` – that called at around the same times.[Oct 2025]
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
