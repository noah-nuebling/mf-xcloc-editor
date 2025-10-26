//
//  MFUI.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

/// Macros for making defining view-hierarchies without IB easier.
///     We have a version of this in a bunch of repos, in some of them we explained some of the choices more IIRC.
///     This is kinda unnecessary since the view hierarchies in mf-xcloc-editor  are very simple and non-repetitve. But it's fun I guess. [Oct 2025]

#import "AppKit/AppKit.h"

#pragma once

#define mfui_new(classname) ({                              \
    auto *_v = [classname new];                             \
    _v.translatesAutoresizingMaskIntoConstraints = NO;      \
    _v;                                                     \
})

#define mfui_outlet(bindingTarget, view...) ({ \
    auto _v = (view); \
    *(bindingTarget) = _v; \
    _v; \
})

static NSEdgeInsets mfui_margins(double top, double bottom, double left, double right) {
    /// To be used with `mfui_wrap()` and `mfui_insert()`
    return NSEdgeInsetsMake(top, left, bottom, right);
}

static void mfui_setmargins(NSView *big, NSEdgeInsets margins, NSView *little) {
    if (!isnan(margins.top))     { auto c = [big.topAnchor      constraintEqualToAnchor: little.topAnchor    constant: -margins.top]  ; c.identifier = @"mui_setmargins"; c.active = YES; }
    if (!isnan(margins.bottom))  { auto c = [big.bottomAnchor   constraintEqualToAnchor: little.bottomAnchor constant: margins.bottom]; c.identifier = @"mui_setmargins"; c.active = YES; }
    if (!isnan(margins.left))    { auto c = [big.leftAnchor     constraintEqualToAnchor: little.leftAnchor   constant: -margins.left] ; c.identifier = @"mui_setmargins"; c.active = YES; }
    if (!isnan(margins.right))   { auto c = [big.rightAnchor    constraintEqualToAnchor: little.rightAnchor  constant: margins.right] ; c.identifier = @"mui_setmargins"; c.active = YES; }
}
static void mfui_insert(NSView *big, NSEdgeInsets margins, NSView *little) {
    [big addSubview: little];
    mfui_setmargins(big, margins, little);
}

static NSView *mfui_wrap(NSEdgeInsets insets, NSView *v) {
    auto wrapper = mfui_new(NSView);
    wrapper.identifier = @"mfui_wrap";
    mfui_insert(wrapper, insets, v);
    return wrapper;
}

NSScrollView *mfui_scrollview(NSView *view);

static NSView *mfui_spacer(void) {
    assert(false); /// Unused
    auto v = mfui_new(NSView);
    v.identifier = @"mfui_spacer";
    return v;
}


typedef struct { CGFloat size; NSFontWeight weight; NSColor *color; } mfui_label_args;
static NSTextField *mfui_label(NSString *text, mfui_label_args args) {
    #define mfui_label(text, args...) mfui_label((text), (mfui_label_args){ args })
    
    if (!args.size)     args.size = NSFont.systemFontSize;
    if (!args.weight)   args.weight = NSFontWeightRegular;
    if (!args.color)    args.color = NSColor.labelColor;
    
    auto v = mfui_new(NSTextField);
    v.stringValue = text;
    
    [v setBezeled:NO];
    [v setDrawsBackground:NO];
    [v setEditable:NO];
    [v setSelectable:NO];
    
    v.font = [NSFont systemFontOfSize: args.size weight: args.weight];
    v.textColor = args.color;
    
    return v;
}


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
