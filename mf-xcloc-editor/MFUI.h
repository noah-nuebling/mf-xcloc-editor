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

#define mfui_outlet(bindingTarget, view...) ({ \
    auto _v = (view); \
    *(bindingTarget) = _v; \
    _v; \
})

static NSEdgeInsets mfui_margin(double top, double bottom, double left, double right) {
    /// To be used with `mfui_wrap()` and `mfui_insert()`
    return NSEdgeInsetsMake(top, left, bottom, right);
}

static void mfui_setmargins(NSEdgeInsets insets, NSView *big, NSView *little) {
    if (!isnan(insets.top))     ({ auto c = [big.topAnchor      constraintEqualToAnchor: little.topAnchor    constant: -insets.top]  ; c.identifier = @"mui_setmargins"; c; }).active = YES;
    if (!isnan(insets.bottom))  ({ auto c = [big.bottomAnchor   constraintEqualToAnchor: little.bottomAnchor constant: insets.bottom]; c.identifier = @"mui_setmargins"; c; }).active = YES;
    if (!isnan(insets.left))    ({ auto c = [big.leftAnchor     constraintEqualToAnchor: little.leftAnchor   constant: -insets.left] ; c.identifier = @"mui_setmargins"; c; }).active = YES;
    if (!isnan(insets.right))   ({ auto c = [big.rightAnchor    constraintEqualToAnchor: little.rightAnchor  constant: insets.right] ; c.identifier = @"mui_setmargins"; c; }).active = YES;
    
    
}
static void mfui_insert(NSView *big, NSEdgeInsets insets, NSView *little) {
    [big addSubview: little];
    mfui_setmargins(insets, big, little);
}

static NSView *mfui_wrap(NSEdgeInsets insets, NSView *v) {
    auto wrapper = mfui_new(NSView);
    mfui_insert(wrapper, insets, v);
    wrapper.identifier = @"mfui_wrap";
    return wrapper;
}

static NSView *mfui_spacer(void) {
    auto v = mfui_new(NSView);
    v.identifier = @"mfui_spacer";
    return v;
}

NSScrollView *mfui_scrollview(NSView *view);

static NSStackView *mfui_vstack(NSArray *arrangedSubviews) {

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

static NSTextField *mfui_label(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    
    auto v = mfui_new(NSTextField);
    v.stringValue = text;
    
    [v setBezeled:NO];
    [v setDrawsBackground:NO];
    [v setEditable:NO];
    [v setSelectable:NO];
    
    v.font = [NSFont systemFontOfSize: size weight: weight];
    v.textColor = color;
    
    return v;
}
