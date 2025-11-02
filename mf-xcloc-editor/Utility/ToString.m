//
//  ToString.m
//  MMF Xcloc Editor
//
//  Created by Noah Nübling on 11/2/25.
//

#import <AppKit/AppKit.h>
#import "Utility.h"

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
