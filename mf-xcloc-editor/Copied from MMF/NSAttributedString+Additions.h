//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface NSAttributedString (Additions)

    - (NSSize) sizeAtMaxWidth: (CGFloat)maxWidth;
    
    - (NSAttributedString *)attributedStringByAddingAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes;
@end
