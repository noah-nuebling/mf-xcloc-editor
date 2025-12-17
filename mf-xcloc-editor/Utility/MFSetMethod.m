
//
//  MFSetMethod.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 12/13/25.
//

/**

    Override/define a method on an instance without having to do any subclassing.
        A bit like associatedObjects but for methods. [Dec 2025]

    Example usage:
        ```
        NSTextField *field = [NSTextField new];

        [field mf_setMethod: @selector(hitTest:) to: mfimp_begin(NSView *, (NSPoint point))
            
            mflog(@"intercepted method with: self: %@, _cmd: %@", self, NSStringFromSelector(_cmd));
                            
            point.x += 5;                               // Make everything confusing and introduce subtle errors
            NSView *result = mfimp_super(point);        // Call the original method implementation that this mfimp overrides
            return result;
            
        mfimp_end()];
        ```
    Notes:
        This is quite a bit more complicated than our `mf_associatedObjects`, which is just a thin convenience wrapper, that I can re-write in 5 minutes. Not sure I actually wanna use this. [Dec 2025]
    
    FOOTGUNS:
        - If you use `super` keyword inside the `mfimp` code, that will be captured from the outside (I think.) [Dec 2025]
            ->>> Use `mfimp_super` instead!
*/

#if 0 /// Currently unused [Dec 2025]

    #define _MFIMP_APPEND(x...) , ## x

    #define mfimp_begin(ret, args...) \
        /** The `mfimp_begin` and `mfimp_end` macros create a 'factory' block which is called by `_MFSetMethod` to create the actual block that is passed to the objc runtime via `imp_implementationWithBlock`. This is necessary to give the block the necessary information (`_cmd` and `ogimp`) to call the original IMP function that it is overriding. */\
        /** Doing separate `_begin` and `_end` macros because Xcode can't set breakpoints inside macro args. (At least last time I checked, it's been a while [Dec 2025] */\
        /** All this is a bit complicated. But user won't have to think about that, usually. All the other approaches I explored were more complicated. */ \
        (id) \
        ^id (SEL _cmd, ret (*ogimp)(id, SEL _MFIMP_APPEND args)) {  /** Outer 'factory' block provides `_cmd` and `ogimp` for the inner block to capture. */\
            return ^ret (id self _MFIMP_APPEND args) {              /** Inner block is passed to `imp_implementationWithBlock`. */\

    #define mfimp_end() \
            }; \
        }
    #define mfimp_super(args...) \
        ogimp(self, _cmd, ##args)

    @interface      _MFSetMethod_DeallocTracker : NSObject @end
    @implementation _MFSetMethod_DeallocTracker
        { @public void (^onDealloc)(void); }
        - (void) dealloc { onDealloc(); }
    @end

    BOOL _MFSetMethod(id self, SEL sel, id (^mfimp_factory)(SEL _cmd, IMP ogimp)) {
        
        /// Override a method on an instance
        ///     Returns success.
        
        assert(NSThread.isMainThread); /// mf-xcloc-editor is single-threaded.
        
        /// Prep
        BOOL success = NO;
        #define fail(msg...) ({ assert(false); mflog(msg); return NO; });
            
        /// Alloc `newcls`
        Class newcls = objc_allocateClassPair(
            object_getClass(self),
            [stringf(@"%s_MFDynamicSubclass:%p", class_getName(object_getClass(self)), self) UTF8String], /// When we override multiple methods on the same instance, the `_MFDynamicSubclass:%p` suffixes are stacked. Bitt ugly. Not sure it matters. [Dec 2025] || (%p, self) prevents conflicts between different instances of the same class. [Dec 2025]
            0
        );
        if (!newcls) fail(@"Allocating class-pair failed.");
        
        /// Install `sel` override on `newcls`
        IMP newimp;
        {
            IMP ogimp = class_getMethodImplementation(newcls, sel);
            newimp = imp_implementationWithBlock(mfimp_factory(sel, ogimp));
            success = class_addMethod(newcls, sel, newimp, method_getTypeEncoding(class_getInstanceMethod(newcls, sel))); /// `method_getTypeEncoding()` would be NULL if no superclass implements the method. Not sure what happens then. The `class_addMethod` param is marked `_Nullable`, so it might be fine? [Dec 2025]
            if (!success) fail(@"Overriding '%s' failed.", sel_getName(sel));
        }
        
        /// Install `newcls` on `self`
        objc_registerClassPair(newcls);
        object_setClass(self, newcls);
        
        /// Install cleanup
        ///     Could override  `-dealloc` but not sure if calling `objc_disposeClassPair()` is safe inside `-dealloc`. (LLM made me paranoid, it says the  isa pointer is still used after all the deallocs run to destroy cpp ivars or something.) [Dec 2025]
        ///     Complication: `objc_disposeClassPair` docs say:  `Do not call this function if instances of the cls class or any subclass exist.`. I guess in our case the subclasses would be destroyed at the same time (almost)?
        ///     Consideration: Unless we call this over and over at runtime, it's probably ok to let these leak [Dec 2025]
        {
            auto tracker = [_MFSetMethod_DeallocTracker new];
            tracker->onDealloc = ^{
                imp_removeBlock(newimp);
                objc_disposeClassPair(newcls);
            };
            [self mf_associatedObjects][stringf(@"_MFSetMethod_DeallocTracker:%p", newcls)] = tracker;
        }
        
        /// Return succ
        return YES;
        #undef fail
    }

    @implementation NSObject (MFSetMethod)
        - (BOOL) mf_setMethod: (SEL)sel to: (id (^)(SEL _cmd, IMP ogimp))mfimp_factory {
            return _MFSetMethod(self, sel, mfimp_factory);
        }
    @end

#endif
