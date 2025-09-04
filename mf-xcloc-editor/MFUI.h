//
//  MFUI.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 9/4/25.
//

#import "AppKit/AppKit.h"

#pragma once

#define mfview(classname) ({                                \
    auto *_v = [classname new];                             \
    _v.translatesAutoresizingMaskIntoConstraints = NO;      \
    _v;                                                     \
})

NSView *mfoutlet(NSView *__strong *binding_target, NSView *v);
NSScrollView *mfscrollview(NSView *v);
NSEdgeInsets mfmargin(double top, double bottom, double left, double right);
void mfinsert(NSView *big, NSEdgeInsets insets, NSView *little);
NSView *mfwrap(NSEdgeInsets insets, NSView *v);
