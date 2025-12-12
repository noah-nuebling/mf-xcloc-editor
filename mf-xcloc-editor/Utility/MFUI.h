//
//  MFUI.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

/// Macros for making defining view-hierarchies without IB easier.
///     We have a version of this in a bunch of repos, in some of them we explained some of the choices more.
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


typedef struct { CGFloat size; NSFontWeight weight; NSColor *color; NSLineBreakMode breakMode; } mfui_label_args;
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
    
    if (args.breakMode) {
        assert(false); /// Unused
        v.lineBreakMode = args.breakMode;
        [v setContentCompressionResistancePriority: 1 forOrientation: NSLayoutConstraintOrientationHorizontal];
    }
    
    return v;
}


static NSStackView *mfui_stack(char orientation, CGFloat spacing, NSArray *arrangedSubviews) {
    
    assert(false); /// Unused
    
    auto v = mfui_new(NSStackView);
    v.orientation = orientation == 'v' ? NSUserInterfaceLayoutOrientationVertical : NSUserInterfaceLayoutOrientationHorizontal;
    
    for (NSView *w in arrangedSubviews) {
        [v addArrangedSubview: w];
    }
    
    v.spacing = spacing;
    
    return v;
}

#define mfui_vstack(spacing, views...) mfui_stack('v', (spacing), (views))
#define mfui_hstack(spacing, views...) mfui_stack('h', (spacing), (views))

static NSView *mfui_spacer(void) {
    assert(false);
    auto v = mfui_new(NSView);
    v.identifier = @"mfui_spacer";
    return v;
}
