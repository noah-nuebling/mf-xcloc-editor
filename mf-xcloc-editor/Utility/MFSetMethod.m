
//
//  MFSetMethod.m
//  Xcloc Editor
//
//  Created by Noah Nübling on 12/13/25.
//

/**

    Method swizzling convenience
        
    Usecase I'm aiming for: Dynamically override method on specific *instance*
        -> That would work a bit like `mf_associatedObjects` but for methods.
        -> That would work a lot like JavaScript – very flexible.
        -> Gave up on this (for now). Instead this abstraction overrides methods on *classes* (not instances)
            -> But it's pretty easy to capture the instance you want to modify in the override block and then check for it before running youir custom code (See below) [Jan 2026]
            -> Reasoning: See `Alternative strategies` below.

    Example usage:
        ```
        
        NSTextField *outerSelf = self;
        [object_getClass(self) mf_setMethod: @selector(hitTest:) to: mfimp_begin(NSView *, (NSPoint point))             // NOTE: Not sure whether to use `object_getClass(self)` or `[self class]` (There would be differences when KVO is isa-swizzling the instance we wanna modify, or maybe for class-clusters) [Jan 2026]
            if (self != outerSelf) return mfimp_super(point);                                                           // Only run the custom code for the `outerSelf` instance
                        
            mflog(@"intercepted method with: self: %@, _cmd: %@", self, NSStringFromSelector(_cmd));                    // `self` and `_cmd` are magically inserted into the scope, just like in a normal method definition. The outer scope's `self` and `_cmd` are shadowed (but `super` isn't) [Jan 2026]
                            
            point.x += 5;                               // Make everything confusing and introduce subtle errors
            NSView *result = mfimp_super(point);        // Call the original method implementation that this mfimp overrides
            return result;
            
        mfimp_end()];
        ```
    
    FOOTGUNS:
        - If you use `super` keyword inside the `mfimp` code, that will be captured from the outside (I think.) [Dec 2025]
            ->>> Use `mfimp_super` instead!
    
    Caveat: Easy memory leaks when customizing specific instances.
        - Each invocation of `mf_setMethod:` will 'leak' the block that is passed to it (And everything strongly captured by it)
        - When you wanna install custom logic for specific instances, the simplest way (I think) is the `if (self != outerSelf)` pattern (shown above), but this will leak stuff for every instance, since you'd be calling `mf_setMethod:` for each instance.
            Pro: Little bit of 'leakage' should be fine for most cases and for debugging / prototyping.
            Pro: There's an easy workaround: To avoid ever-growing memory usage, you could only call `mf_setMethod:` once and then use `mf_associatedObjects` to decide for which instances to run the custom interception. [Dec 2025]
    
    Alternative strategies:      (for overriding methods on specific instances)
        - isa-swizzling (`object_setClass`)
            - We used to do this. Removed after commit 93f7f688dc31b4c7ca251c8290b3870a921a0dd6 in `mf-xcloc-editor` repo
            - Contra: this seemed to interfere with KVO, which also applies isa-swizzling and it would cause crashes in Apple Frameworks.
                (I think what would happen is that we subclassed the dynamic `NSKVONotifying_` class, but then KVO would later remove that `NSKVONotifying_` class and that would also remove our dynamic `MFSetMethodClass` class, plus it would corrupt things somehow and object_getClass() would return nil IIRC.)
        - is-swizzling pt. 2 (Using `objc_duplicateClass` – another isa-swizzling function that is used by KVO according to the docs. [Dec 2025])
            Contra: No clue why exactly this would work any better. Not much info on it. Docs just tell you to not use it.
            ... But I feel like there has to be a way to do isa-swizzling without breaking everything just because KVO is also isa swizzling?
            What if you just replace the instance's class with an instance-specific copy and then swizzle that? (No subclassing) ... But that actually doesn't seem to be what KVO is doing. (It creates `NSKVONotifying_` subclass)
        - Swizzle the class and then check for the instance with an if-statement
            -> What we're currently doing [Jan 2025]
            Pro: Simple, flexible
            Pro/Contra: The simplest approach 'Leaks' memory for each instance that you swizzle, but there are workarounds (See above)
        - Only override the method once with an imp that looks up the implementation block in an associatedObject, then just store the imp on the instance -> Basically turn it into JavaScript.
            Pro: Avoids the memory leak issue, since blocks are stored on the instance instead of the class, and the class method is only swizzled once to turn it 'dynamic', and then never touched again.
            Pro: Could make the API slightly more concise.
                (Instead of `auto __weak outerSelf = self; [object_getClass(self) mf_setMethod: ...` you could just do `[self mf_setMethod: ...`)
            Con: Seems more complicated to me.
            Con: The memory leak stuff probably doesn't matter in practise.
*/

#if 0

    #define _MFIMP_APPEND(x...) , ## x

    #define mfimp_begin(ret, args...) \
        /** The `mfimp_begin` and `mfimp_end` macros create a 'factory' block which is called by `mf_setMethod:` to create the actual block that is passed to the objc runtime via `imp_implementationWithBlock`. This is necessary to give the block the necessary information (`_cmd` and `ogimp`) to call the original IMP function that it is overriding. */\
        /** Doing separate `_begin` and `_end` macros because Xcode can't set breakpoints inside macro args. (At least last time I checked, it's been a while) [Dec 2025] */\
        /** All this is a bit complicated. But user won't have to think about that, usually. All the other approaches I explored were more complicated. */ \
        (id) \
        ^id (SEL _cmd, ret (*ogimp)(id, SEL _MFIMP_APPEND args)) {  /** Outer 'factory' block provides `_cmd` and `ogimp` for the inner block to capture. */\
            return ^ret (id self _MFIMP_APPEND args) {              /** Inner block is passed to `imp_implementationWithBlock`. */\

    #define mfimp_end() \
            }; \
        }
    #define mfimp_super(args...) \
        ogimp(self, _cmd, ##args)

    @implementation NSObject (MFSetMethod)
        + (void) mf_setMethod: (SEL)sel to: (id (^)(SEL _cmd, IMP ogimp))mfimp_factory {
            
            assert(NSThread.isMainThread); /// mf-xcloc-editor is single-threaded.
            
            /// Install `sel` override on `cls`
            
            Class cls = self;
            
            IMP ogimp = class_getMethodImplementation(cls, sel);
            IMP newimp = imp_implementationWithBlock(mfimp_factory(sel, ogimp));
            
            Method ogmethod = class_getInstanceMethod(cls, sel);
            const char *types = method_getTypeEncoding(ogmethod);
            assert(types);          /// The types arg for `class_replaceMethod()` is nullable, but not sure what happens if it's NULL. [Jan 2026]
            
            class_replaceMethod(cls, sel, newimp, types);
        }
    @end

#endif
