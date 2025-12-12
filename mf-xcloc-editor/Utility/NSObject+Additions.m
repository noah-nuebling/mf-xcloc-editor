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
        
        static const char *key = "__mf_associatedObjects"; /// Is this shared across compilation units? (Doesn't matter since mf-xcloc-editor is a unity-build now.) (We could hash the string or use @selector if this ever causes problems) [Dec 2025]
    
         id dict = objc_getAssociatedObject(self, key);
         if (!dict) {
            dict = [NSMutableDictionary new];
            objc_setAssociatedObject(self, key, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
         }
         return dict;
    }
@end

