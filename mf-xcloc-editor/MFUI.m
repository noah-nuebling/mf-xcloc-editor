//
//  MFUI.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import "MFUI.h"
#import "Utility.h"
#import <Foundation/Foundation.h>

NSView *mfoutlet(NSView *__strong *binding_target, NSView *v) {
    *binding_target = v;
    return v;
}
NSScrollView *mfscrollview(NSView *v) {
    auto scrollView = mfview(NSScrollView);
    scrollView.documentView = v;
    if ((0)) scrollView.hasVerticalScroller = YES;
    return scrollView;
}

NSEdgeInsets mfmargin(double top, double bottom, double left, double right) {
    /// To be used with `mfwrap()` and `mfinsert()`
    return NSEdgeInsetsMake(top, left, bottom, right);
}

void mfinsert(NSView *big, NSEdgeInsets insets, NSView *little) {
    
    [big addSubview: little];
    
    [big.topAnchor      constraintEqualToAnchor: little.topAnchor    constant: -insets.top].active = YES;
    [big.bottomAnchor   constraintEqualToAnchor: little.bottomAnchor constant: insets.bottom].active = YES;
    [big.leftAnchor     constraintEqualToAnchor: little.leftAnchor   constant: -insets.left].active = YES;
    [big.rightAnchor    constraintEqualToAnchor: little.rightAnchor  constant: insets.right].active = YES;
}
NSView *mfwrap(NSEdgeInsets insets, NSView *v) {
    auto wrapper = mfview(NSView);
    mfinsert(wrapper, insets, v);
    return wrapper;
}
