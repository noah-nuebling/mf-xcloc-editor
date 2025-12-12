//
//  NSObject+Additions.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

@interface NSObject (Additions)

    - (id) mf_associatedObjectForKey: (NSString *)key;
    - (void) mf_setAssociatedObject: (id)obj forKey: (NSString *)key;

@end


//
//  NSObject+Additions.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

@implementation NSObject (Additions)


    /// associatedObject convenience (Not sure this is actually useful [Oct 2025]
    - (id) mf_associatedObjectForKey: (NSString *)key {
        return objc_getAssociatedObject(self, (void *)[key hash]);
    }
    - (void) mf_setAssociatedObject: (id)obj forKey: (NSString *)key {
        objc_setAssociatedObject(self, (void *)[key hash], obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    

@end
