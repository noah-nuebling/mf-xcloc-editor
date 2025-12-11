//
//  NSObject+MFTargetAction.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 12/11/25.
//

#import "NSObject+MFTargetAction.h"
#import <AppKit/AppKit.h>
#import "NSObject+MFAssociatedObject.h"

/// Block-based interface for Target-Action

@interface MFTargetActionTarget : NSObject @end
@implementation MFTargetActionTarget
    {
        @public
        void (^block)(id sender);
    }
    - (void) action: (id)sender { block(sender); }
@end

@implementation NSObject (MFTargetAction)

    - (void) mf_bindTargetAction: (void (^)(id sender))actionCallback {
        
        MFTargetActionTarget *target = [MFTargetActionTarget new];
        target->block = actionCallback;
        
        [(id)self setTarget: target];
        [(id)self setAction: @selector(action:)];
        
        [self mf_setAssociatedObject: target forKey: @"__MFTargetActionTarget"]; /// `mf_setAssociatedObject:` retains the target and keeps it alive until self is released. [Dec 2025]
                                                                                 /// Retain cycles: Don't capture self in the callback block! Use the sender arg instead. [Dec 2025]
    }

@end

