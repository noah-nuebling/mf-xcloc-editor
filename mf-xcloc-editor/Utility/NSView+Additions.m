//
//  NSView+Additions.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 11/2/25.
//

#import "NSView+Additions.h"

@implementation NSView (Additions)

    - (NSView *) searchSubviewWithIdentifier: (NSUserInterfaceItemIdentifier) identifier {
        
        /// This recursively searches the view's subviews. For single-level search we tend to use the `firstmatch` macro. [Nov 2025]
        
        NSView *rec;
        
        for (NSView *v in self.subviews) {
            if ([[v identifier] isEqual: identifier])
                return v;
            if ((rec = [v searchSubviewWithIdentifier: identifier]))
                return rec;
        }
        
        return nil;
    }

@end
