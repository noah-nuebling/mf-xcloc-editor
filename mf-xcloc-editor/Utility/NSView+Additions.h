//
//  NSView+Additions.h
//  Xcloc Editor
//
//  Created by Noah Nübling on 11/2/25.
//

#import <Cocoa/Cocoa.h>

@interface NSView (Additions)

    - (NSView *) searchSubviewWithIdentifier: (NSUserInterfaceItemIdentifier) identifier;

@end
