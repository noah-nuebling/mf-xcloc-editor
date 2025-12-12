//
//  NSObject+Additions.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

@interface NSObject (Additions)
    
    - (NSMutableDictionary *)mf_associatedObjects;

@end


//
//  NSObject+Additions.m
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

@implementation NSObject (Additions)


    - (NSMutableDictionary *)mf_associatedObjects {
    
        /// associatedObject convenience. Very useful. You can do all the JavaScript things. [Dec 2025]
    
         id dict = objc_getAssociatedObject(self, "__mf_associatedObjects");
         if (!dict) {
            dict = [NSMutableDictionary new];
            objc_setAssociatedObject(self, "__mf_associatedObjects", dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
         }
         return dict;
    }
@end

