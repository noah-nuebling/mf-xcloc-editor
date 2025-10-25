//
//  MFUI.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import "AppKit/AppKit.h"

#pragma once

#define mfui_new(classname) ({                                \
    auto *_v = [classname new];                             \
    _v.translatesAutoresizingMaskIntoConstraints = NO;      \
    _v;                                                     \
})

#define mfui_outlet(bindingTarget, view) ({ \
    auto _v = (view); \
    *(bindingTarget) = _v; \
    _v; \
})

static NSEdgeInsets mfui_margin(double top, double bottom, double left, double right) {
    /// To be used with `mfui_wrap()` and `mfui_insert()`
    return NSEdgeInsetsMake(top, left, bottom, right);
}

static void mfui_setmargins(NSEdgeInsets insets, NSView *big, NSView *little) {
    if (!isnan(insets.top))     [big.topAnchor      constraintEqualToAnchor: little.topAnchor    constant: -insets.top].active = YES;
    if (!isnan(insets.bottom))  [big.bottomAnchor   constraintEqualToAnchor: little.bottomAnchor constant: insets.bottom].active = YES;
    if (!isnan(insets.left))    [big.leftAnchor     constraintEqualToAnchor: little.leftAnchor   constant: -insets.left].active = YES;
    if (!isnan(insets.right))   [big.rightAnchor    constraintEqualToAnchor: little.rightAnchor  constant: insets.right].active = YES;
}
static void mfui_insert(NSView *big, NSEdgeInsets insets, NSView *little) {
    [big addSubview: little];
    mfui_setmargins(insets, big, little);
}

static NSView *mfui_wrap(NSEdgeInsets insets, NSView *v) {
    auto wrapper = mfui_new(NSView);
    mfui_insert(wrapper, insets, v);
    return wrapper;
}

@interface FlippedClipView : NSClipView @end /// Necessary to make the content gravitate to the top instead of bottom when using autolayout or sth [Oct 2025]
@implementation FlippedClipView
    - (BOOL)isFlipped { return YES; }
@end

@interface FlippedScrollView : NSScrollView @end /// Necessary to unflip scroll direction from `FlippedClipView`[Oct 2025]
@implementation FlippedScrollView
    - (BOOL)isFlipped { return YES; }
@end

static NSScrollView *mfui_scrollview(NSView *view) {
    
    /// Note: We tried to put an NSStackView inside this, and its width was 0 unless we did weird stuff like use FlippedScrollView and use autolayout on the children [Oct 2025]
    ///     Don't this this is necessary anymore.
    
    auto scrollView = mfui_new(FlippedScrollView);
    scrollView.contentView = mfui_new(FlippedClipView);
    scrollView.documentView = view;
    
    scrollView.drawsBackground = NO;
    
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    
    return scrollView;
}

NSStackView *mfui_vstack(NSArray *arrangedSubviews) {

    assert(false); /// Unused

    auto v = mfui_new(NSStackView);
    v.orientation = NSUserInterfaceLayoutOrientationVertical;
    
    for (NSView *w in arrangedSubviews) {
        [v addArrangedSubview: w];
    }
    
    [v setContentHuggingPriority: 1                  forOrientation: NSLayoutConstraintOrientationHorizontal];
    [v setContentCompressionResistancePriority: 1000 forOrientation: NSLayoutConstraintOrientationHorizontal];
    [v setContentHuggingPriority: 1000               forOrientation: NSLayoutConstraintOrientationVertical];
    [v setContentCompressionResistancePriority: 1000 forOrientation: NSLayoutConstraintOrientationVertical];
    
    ///TEST
    if ((0)) [[v widthAnchor] constraintGreaterThanOrEqualToConstant: 200].active = YES;
    
    return v;
}

NSTextField *mfui_label(NSString *text) {
    
    assert(false); /// Unused
    
    auto v = mfui_new(NSTextField);
    v.stringValue = text;
    
    [v setBezeled:NO];
    [v setDrawsBackground:NO];
    [v setEditable:NO];
    [v setSelectable:NO];
    
    return v;
}
