//
//  Utility.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <AppKit/AppKit.h>

///
/// General convenience
///

#define auto __auto_type                /// `auto` keyword is unused in C, so overriding with CPP-style `__auto_type` should be fine.
#define mflog(msg...)                   NSLog(@"%20s: %@", __FILE_NAME__, stringf(@"" msg))
#define isclass(obj,  classname)        ({ [[(obj) class] isSubclassOfClass: [classname class]]; })
#define isclassd(obj, classname_str)     ({ [[(obj) class] isSubclassOfClass: NSClassFromString(classname_str)]; })
#define stringf(format, args...)        [NSString stringWithFormat: (format), ## args]

#define arrcount(x...) (sizeof ((x)) / sizeof (x)[0])
        
#define nowtime() (CACurrentMediaTime() * 1000.0) /// Timestamp in milliseconds
        
#define mferror(domain, code_, msg_and_args...) \
    [NSError errorWithDomain: (domain) code: (code_) userInfo: @{ NSDebugDescriptionErrorKey: stringf(msg_and_args) }] /** Should we use `NSLocalizedFailureReasonErrorKey`? [Oct 2025] */

#define mfonce dispatch_once
#define mfoncet ({ static dispatch_once_t onceToken; &onceToken; })

#define safeidx(arr, count, idx, fallback) ({                   \
    auto _arr = (arr);                                          \
    auto _idx = (idx);                                          \
    (0 <= _idx && _idx < (count)) ? _arr[_idx] : (fallback);    /** If index is signed an negative, it would underflow in the `< (count)` comparison , but it would still fail  the `>= 0` comparison. I think our safety precautionns in MMF are overkill. */\
})

#define allsatisfy(arr, count, varname, condition...) ({    \
    bool _result = 1;                                       \
    auto _arr = (arr);                                      \
    for (auto _i = 0; _i < (count); _i++) {                 \
        auto varname = _arr[_i];                            \
        if (!(condition)) { _result = 0; break; }           \
    }                                                       \
    _result;                                                \
})
#define firstmatch(arr, count, fallback, varname, condition...) ({    \
    typeof((arr)[0]) _result = (fallback);                  \
    auto _arr = (arr);                                      \
    for (auto _i = 0; _i < (count); _i++) {                 \
        auto varname = _arr[_i];                            \
        if ((condition)) { _result = varname; break; }      \
    }                                                       \
    _result;                                                \
})

#define toset(arr...) [NSSet setWithArray: (arr)]

#define indexset(indexes...) ({ \
    NSInteger _arr[] = { indexes }; \
    indexSetWithIndexArray(_arr, arrcount(_arr)); \
})
static NSMutableIndexSet *indexSetWithIndexArray(NSInteger arr[], int len) {
    auto set = [NSMutableIndexSet new];
    for (int i = 0; i < len; i++)
        if (arr[i] >= 0 && arr[i] != NSNotFound) /// outlineView row-getter methods sometimes return -1 if the row-search failed, but when you pass these to `reloadDataForRowIndexes:` it silently fails, so we filter these 'nil' indexes out. [Oct 2025]
            [set addIndex: arr[i]];
    
    return set;
}

///
/// NSXML convenience.
///

#define xml_childat(xmlNode, idx) ({                            \
    auto _node = (xmlNode);                                     \
    safeidx(_node.children, _node.children.count, (idx), nil);  \
})

typedef struct { NSXMLNode *fallback; } xml_childnamed_args;
static NSXMLNode *xml_childnamed(NSXMLElement *_node, NSString *name_, xml_childnamed_args args) {
    #define xml_childnamed(node, name, fallback...) xml_childnamed((node), (name), (xml_childnamed_args){ fallback })
    
    auto result = firstmatch(_node.children, _node.children.count, nil, x, [x.name isEqual: (name_)]);
    if (!result && args.fallback) {
        [args.fallback setName: name_];
        [_node addChild: args.fallback]; /// NSXMLNode doesn't have `addChild:` for some reason, otherwise this func would work on NSXMLNode, not just NSXMLElement.
        result = args.fallback;
    }
    return result;
}

typedef struct { NSXMLNode *fallback; } xml_attr_args;
static NSXMLNode *xml_attr(NSXMLElement *xmlElement, NSString *name, xml_attr_args args) {
    #define xml_attr(xmlElement, name, fallback...) xml_attr((xmlElement), (name), (xml_attr_args) { fallback })
    
    auto result = [xmlElement attributeForName: name];
    if (!result && args.fallback) {
        args.fallback.name = name;
        [xmlElement addAttribute: args.fallback];
        result = args.fallback;
    }
    return result;
}

static NSMutableDictionary<NSString *, NSXMLNode *> *xml_attrdict(NSXMLElement *_xmlElement) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSXMLNode *el in [_xmlElement attributes]) result[el.name] = el;
    return result;
}

#pragma mark - Shorthands for horrible NSFileWrapper API

    static void _fw_walk(NSFileWrapper *fileWrapper, void (^callback)(NSFileWrapper *subFileWrapper, NSString *subpath, BOOL *stop), NSMutableArray *currentKeyPath, BOOL *stop) {
        
        /// Helper for `fw_walk`
        
        if (!fileWrapper.isDirectory) { /// { Optimization: We only need this for `fw_findPaths`, and it only needs to see file nodes not directory nodes. [Oct 2025]
            callback(fileWrapper, [currentKeyPath componentsJoinedByString: @"/"], stop);
            if (*stop) return;
        }
        else
            for (NSString *key in fileWrapper.fileWrappers) {
                
                NSFileWrapper *w = fileWrapper.fileWrappers[key];
                
                [currentKeyPath addObject: key];
                _fw_walk(w, callback, currentKeyPath, stop); /// Recurse
                if (*stop) return;
                [currentKeyPath removeLastObject];
            }
    }
    static void fw_walk(NSFileWrapper *fileWrapper, void (^callback)(NSFileWrapper *w, NSString *subpath, BOOL *stop)) {
        
        /// Walk all the filesystem nodes inside the `fileWrapper`
    
        BOOL stop = NO;
        _fw_walk(fileWrapper, callback, [NSMutableArray new], &stop);
    }

    static NSFileWrapper *fw_readPath(NSFileWrapper *fw, NSString *subpath) {
        
        /// Get the NSFileWrapper at `subpath` inside `fw`
        ///     May explode if you pass an invalid subpath [Oct 2025]

        NSArray *kp = [subpath componentsSeparatedByString: @"/"];
        
        for (NSInteger i = 0; i < kp.count; i++)
            fw = fw.fileWrappers[kp[i]];
        
        return fw;
    }

    static void fw_writePath(NSFileWrapper *fw, NSString *subpath, NSData *fileContents) {
        
        /// Replace the NSFileWrapper at `subpath` inside `fw` with `fileContents`
        ///     May explode if you pass an invalid subpath [Oct 2025]
        
        NSArray *kp = [subpath componentsSeparatedByString: @"/"];
        
        /// Navigate to the parent dir of the file we wanna manipulate
        for (NSInteger i = 0; i < kp.count-1; i++)
            fw = fw.fileWrappers[kp[i]];
        
        /// Delete the existing child
        [fw removeFileWrapper: fw.fileWrappers[kp.lastObject]];
        
        /// Add the new child
        {   /// Could use `addRegularFileWithContents:`
            auto x = [[NSFileWrapper alloc] initRegularFileWithContents: fileContents];
            [x setPreferredFilename: kp.lastObject];
            [fw addFileWrapper: x];
        }
    }
    

    static NSArray<NSString *> *fw_findPaths(NSFileWrapper *wrapper, BOOL (^condition)(NSFileWrapper *fw, NSString *p, BOOL *stop)) {
        
        /// Like `findPaths()` but for NSFileWrapper [Oct 2025]
        
        auto result = [NSMutableArray new];
        
        fw_walk(wrapper, ^(NSFileWrapper *fw, NSString *p, BOOL *stop) {
            if (condition(fw, p, stop)) {
                [result addObject: p]; /// Unlike `findPaths()`, these paths are relative [Oct 2025]
            }
        });
        
        return result;
    }


static NSArray<NSString *> *findPaths(int timeout_ms, NSString *dirPath, BOOL (^condition)(NSString *path)) {
    
    /// Like shell globbing but more cumbersome.
    ///     `timeout_ms` arg is for when we're searching outside of our own bundle, where the folder structure could be anything.
    
    auto result = [NSMutableArray new];
    
    double ts_start = nowtime();
    
    for (NSString *p in [[NSFileManager defaultManager] enumeratorAtPath: dirPath]) {
        if (timeout_ms > 0)
            if (nowtime() - ts_start > timeout_ms) {
                mflog(@"Timed out after %d ms", timeout_ms);
                break;
            }
        if (condition(p)) {
            [result addObject: [dirPath stringByAppendingPathComponent: p]]; /// Make path absolute, (When it's passed into `condition()` it's still relative – hope that's not confusing [Oct 2025])
        }
    }
        
    return result;
}

static NSEvent *makeKeyDown(unichar keyEquivalent, int keyCode) {
    return [NSEvent
        keyEventWithType: NSEventTypeKeyDown
        location: NSZeroPoint
        modifierFlags: 0
        timestamp: 0
        windowNumber: 0
        context: nil
        characters: stringf(@"%C", (unichar)keyEquivalent)
        charactersIgnoringModifiers: stringf(@"%C", (unichar)keyEquivalent)
        isARepeat: NO
        keyCode: keyCode
    ];
}

static BOOL eventIsKey(NSEvent *event, unichar key) {
    return [stringf(@"%C", (unichar)key) isEqual: [event charactersIgnoringModifiers]];
}

static void runOnMain(double delay, void (^workload)(void)) {
    
    /// Delayed run on main for UI code [Oct 2025]
    ///     If you pass 0.0 as the delay, the workload will be executed during the next iteration of main runLoop (I think) [Oct 2025]
    
    auto t = [NSTimer timerWithTimeInterval: delay repeats: NO block:^(NSTimer * _Nonnull timer) {
        workload();
    }];
    [[NSRunLoop mainRunLoop] addTimer: t forMode: NSRunLoopCommonModes];
}

static NSData *imageData(NSImage *image, NSBitmapImageFileType type, NSDictionary *properties) {
        
    /// This implementation comes from the PackagedDocument sample project (https://developer.apple.com/library/archive/samplecode/PackagedDocument/Introduction/Intro.html#//apple_ref/doc/uid/DTS40012955-Intro-DontLinkElementID_2)
    /// Copying this here cause I'm often confused as to what is the right way to serialize an NSImage. [Oct 2025]
    
    /// TODO: Maybe copy this into mac-mouse-fix
    
    NSData *imageData = [NSBitmapImageRep /// I assume this is done for speed
        representationOfImageRepsInArray: image.representations
        usingType: type
        properties: properties
    ];
    if (!imageData) { /// I assume this is done for reliability
        NSBitmapImageRep *imageRep = nil;
        @autoreleasepool {
            imageRep = [[NSBitmapImageRep alloc] initWithData: image.TIFFRepresentation];
        }
        imageData = [imageRep representationUsingType: type properties: properties];
    }
    
    return imageData;
}

