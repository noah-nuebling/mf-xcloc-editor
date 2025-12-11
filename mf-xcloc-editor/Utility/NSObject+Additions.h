//
//  NSObject+Additions.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 10/21/25.
//

#import <Foundation/Foundation.h>

@interface NSObject (Additions)

    - (id) mf_associatedObjectForKey: (NSString *)key;
    - (void) mf_setAssociatedObject: (id)obj forKey: (NSString *)key;

@end
