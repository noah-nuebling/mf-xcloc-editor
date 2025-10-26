//
//  NSObject+Thing.m
//  MMF Xcloc Editor
//
//  Created by Noah Nübling on 10/25/25.
//

#import <AppKit/AppKit.h>
#import "Utility.h"
#import "MFUI.h"

@interface FlippedClipView : NSClipView @end /// Necessary to make the content gravitate to the top instead of bottom when using autolayout or sth [Oct 2025]
@interface FlippedScrollView : NSScrollView @end /// Necessary to unflip scroll direction from `FlippedClipView`[Oct 2025]

@implementation FlippedScrollView
    - (BOOL)isFlipped { return YES; }
@end
@implementation FlippedClipView
    - (BOOL)isFlipped { return YES; }
@end

NSScrollView *mfui_scrollview(NSView *view) {
    
    /// Note: We tried to put an NSStackView inside this, and its width was 0 unless we did weird stuff like use FlippedScrollView and use autolayout on the children [Oct 2025]
    ///     Don't this this is necessary anymore.
    
    NSScrollView *scrollView;
    if ((0)) { /// Saw weird autolayout crashes due to this I think. I toggled the state and then switched to another file and then tried to resize the sidebar ... Nope those issues still happen
    
        scrollView = mfui_new(FlippedScrollView);
        scrollView.contentView = mfui_new(FlippedClipView);
        scrollView.documentView = view;
        
        scrollView.drawsBackground = NO;
        
        scrollView.hasVerticalScroller = YES;
        scrollView.autohidesScrollers = YES;
    }
    if ((1)) {
        scrollView = [NSScrollView new];
        scrollView.drawsBackground = NO;
        
        scrollView.hasVerticalScroller = YES;
        scrollView.autohidesScrollers = YES;
        
        scrollView.documentView = view;
    }
    
    
    return scrollView;
}
