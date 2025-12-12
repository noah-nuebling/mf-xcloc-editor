//
//  ToString.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 11/2/25.
//

@implementation NSObject (UnrelatedCFunctions)

static NSString *NSEventType_ToString(NSEventType type) {
    switch (type) {
        case NSEventTypeLeftMouseDown        : return @"LeftMouseDown";
        case NSEventTypeLeftMouseUp          : return @"LeftMouseUp";
        case NSEventTypeRightMouseDown       : return @"RightMouseDown";
        case NSEventTypeRightMouseUp         : return @"RightMouseUp";
        case NSEventTypeMouseMoved           : return @"MouseMoved";
        case NSEventTypeLeftMouseDragged     : return @"LeftMouseDragged";
        case NSEventTypeRightMouseDragged    : return @"RightMouseDragged";
        case NSEventTypeMouseEntered         : return @"MouseEntered";
        case NSEventTypeMouseExited          : return @"MouseExited";
        case NSEventTypeKeyDown              : return @"KeyDown";
        case NSEventTypeKeyUp                : return @"KeyUp";
        case NSEventTypeFlagsChanged         : return @"FlagsChanged";
        case NSEventTypeAppKitDefined        : return @"AppKitDefined";
        case NSEventTypeSystemDefined        : return @"SystemDefined";
        case NSEventTypeApplicationDefined   : return @"ApplicationDefined";
        case NSEventTypePeriodic             : return @"Periodic";
        case NSEventTypeCursorUpdate         : return @"CursorUpdate";
        case NSEventTypeScrollWheel          : return @"ScrollWheel";
        case NSEventTypeTabletPoint          : return @"TabletPoint";
        case NSEventTypeTabletProximity      : return @"TabletProximity";
        case NSEventTypeOtherMouseDown       : return @"OtherMouseDown";
        case NSEventTypeOtherMouseUp         : return @"OtherMouseUp";
        case NSEventTypeOtherMouseDragged    : return @"OtherMouseDragged";
        case NSEventTypeGesture              : return @"Gesture";
        case NSEventTypeMagnify              : return @"Magnify";
        case NSEventTypeSwipe                : return @"Swipe";
        case NSEventTypeRotate               : return @"Rotate";
        case NSEventTypeBeginGesture         : return @"BeginGesture";
        case NSEventTypeEndGesture           : return @"EndGesture";
        case NSEventTypeSmartMagnify         : return @"SmartMagnify";
        case NSEventTypeQuickLook            : return @"QuickLook";
        case NSEventTypePressure             : return @"Pressure";
        case NSEventTypeDirectTouch          : return @"DirectTouch";
        case NSEventTypeChangeMode           : return @"ChangeMode";
        case /*NSEventTypeMouseCancelled*/40 : return @"MouseCancelled";
        default                              : return stringf(@"%ld", type);
    };
}

static NSString *NSEventModifierFlags_ToString(NSEventModifierFlags x) {
    
    NSString *map[] = {
        [bitpos(NSEventModifierFlagCapsLock)]           = @"CapsLock",
        [bitpos(NSEventModifierFlagShift)]              = @"Shift",
        [bitpos(NSEventModifierFlagControl)]            = @"Control",
        [bitpos(NSEventModifierFlagOption)]             = @"Option",
        [bitpos(NSEventModifierFlagCommand)]            = @"Command",
        [bitpos(NSEventModifierFlagNumericPad)]         = @"NumericPad",
        [bitpos(NSEventModifierFlagHelp)]               = @"Help",
        [bitpos(NSEventModifierFlagFunction)]           = @"Function",
    };
    return bitflagstring(x, map, arrcount(map));
}

// MARK: Helper function: bitflagstring (Copied from MMF)

static NSString *_Nonnull bitflagstring(int64_t flags, NSString *const _Nullable bitposToNameMap[_Nullable], int bitposToNameMapCount) {
    
    /**
    Debug-printing for enums. [Apr 2025]
        
    Also see: `CodeStyle.md`
    Usage example:
        ```
        NSString *MFCGDisplayChangeSummaryFlags_ToString(CGDisplayChangeSummaryFlags flags) {
        
            static NSString *map[] = {
                [bitpos(kCGDisplayBeginConfigurationFlag)]      = @"BeginConfiguration",
                [bitpos(kCGDisplayMovedFlag)]                   = @"Moved",
                [bitpos(kCGDisplaySetMainFlag)]                 = @"SetMain",
                [bitpos(kCGDisplaySetModeFlag)]                 = @"SetMode",
                [bitpos(kCGDisplayAddFlag)]                     = @"Add",
                [bitpos(kCGDisplayRemoveFlag)]                  = @"Remove",
                [bitpos(kCGDisplayEnabledFlag)]                 = @"Enabled",
                [bitpos(kCGDisplayDisabledFlag)]                = @"Disabled",
                [bitpos(kCGDisplayMirrorFlag)]                  = @"Mirror",
                [bitpos(kCGDisplayUnMirrorFlag)]                = @"UnMirror",
                [bitpos(kCGDisplayDesktopShapeChangedFlag)]     = @"DesktopShapeChanged",
            };
            
            NSString *result = bitflagstring(flags, map, arrcount(map));
            return result;
        };
        ```
    */
    
    /// Build result
    NSMutableString *result = [NSMutableString string];
    
    int i = 0;
    while (1) {
        
        /// Break
        if (flags == 0) break;
        
        if ((flags & 1) != 0) { /// If `flags` contains bit `i`
            
            /// Insert separator
            if (result.length > 0)
                [result appendString:@" | "];
            
            /// Get string describing bit `i`
            NSString *bitName = safeindex(bitposToNameMap, bitposToNameMapCount, i, nil);
            NSString *str = (bitName && bitName.length > 0) ? bitName : stringf(@"(1 << %d)", i);
            
            /// Append
            [result appendString:str];
        }
        
        /// Increment
        flags >>= 1;
        i++;
    }
    
    /// Wrap result in ()
    result = [NSMutableString stringWithFormat:@"(%@)", result];
    
    /// Return
    return result;
}

@end
