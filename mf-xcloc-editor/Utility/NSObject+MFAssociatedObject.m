//
//  NSObject+Additions.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

#import "NSObject+MFAssociatedObject.h"
#import <objc/runtime.h>

@implementation NSObject (MFAssociatedObject)

    /// associatedObject convenience (Not sure this is actually useful [Oct 2025]
    - (id) mf_associatedObjectForKey: (NSString *)key {
        return objc_getAssociatedObject(self, (void *)[key hash]);
    }
    - (void) mf_setAssociatedObject: (id)obj forKey: (NSString *)key {
        objc_setAssociatedObject(self, (void *)[key hash], obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

@end
