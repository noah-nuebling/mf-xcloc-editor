//
//  Utility.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

///
/// General convenience
///

#define auto __auto_type                /// `auto` keyword is unused in C, so overriding with CPP-style `__auto_type` should be fine.
#define mflog(msg...)                   NSLog(@ __FILE_NAME__ ": " msg)
#define isclass(obj, classname)        ({ [[(obj) class] isSubclassOfClass: [classname class]]; })
#define stringf(format, args...)        [NSString stringWithFormat: (format), ## args]

        
#define mferror(domain, code_, msg_and_args...) \
    [NSError errorWithDomain: (domain) code: (code_) userInfo: @{ NSDebugDescriptionErrorKey: stringf(msg_and_args) }] /** Should we use `NSLocalizedFailureReasonErrorKey`? [Oct 2025] */

#define loopc(varname, count) for (int64_t varname = 0; varname < (count); varname++)

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


///
/// NSXML convenience.
///

#define xml_childat(xmlNode, idx) ({                            \
    auto _node = (xmlNode);                                     \
    safeidx(_node.children, _node.children.count, (idx), nil);  \
})
#define xml_childnamed(xmlNode, name_) ({                        \
    auto _node = (xmlNode);                                     \
    firstmatch(_node.children, _node.children.count, nil, x, [x.name isEqual: (name_)]);  \
})

static NSXMLNode *xml_attr(NSXMLElement *xmlElement, NSString *name) {
    return [xmlElement attributeForName: name];
}

static NSMutableDictionary<NSString *, NSXMLNode *> *xml_attrdict(NSXMLElement *_xmlElement) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSXMLNode *el in [_xmlElement attributes]) result[el.name] = el;
    return result;
}

#pragma mark - Shorthands for horrible NSFileWrapper API

    static void _fw_walk(NSFileWrapper *fileWrapper, void (^callback)(NSFileWrapper *subFileWrapper, NSString *subpath), NSMutableArray *currentKeyPath) {
        
        /// Helper for `fw_walk`
        ///     Optimization: We only need this for `fw_findPaths`, and it only needs to see file nodes not directory nodes, so we could skip calling the callback on those [Oct 2025]
        
        callback(fileWrapper, [currentKeyPath componentsJoinedByString: @"/"]);
        
        if (fileWrapper.isDirectory)
        for (NSString *key in fileWrapper.fileWrappers) {
            
            NSFileWrapper *w = fileWrapper.fileWrappers[key];
            
            [currentKeyPath addObject: key];
            _fw_walk(w, callback, currentKeyPath); /// Recurse
            [currentKeyPath removeLastObject];
        }
    }
    static void fw_walk(NSFileWrapper *fileWrapper, void (^callback)(NSFileWrapper *w, NSString *subpath)) {
        
        /// Walk all the filesystem nodes inside the `fileWrapper`
    
        _fw_walk(fileWrapper, callback, [NSMutableArray new]);
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
    

    static NSArray<NSString *> *fw_findPaths(NSFileWrapper *wrapper, BOOL (^condition)(NSFileWrapper *fw, NSString *p)) {
        
        /// Like `findPaths()` but for NSFileWrapper [Oct 2025]
        
        auto result = [NSMutableArray new];
        
        fw_walk(wrapper, ^(NSFileWrapper *fw, NSString *p) {
            if (condition(fw, p))
                [result addObject: p]; /// Unlike `findPaths()`, these paths are relative [Oct 2025]
        });
        
        return result;
    }


static NSArray<NSString *> *findPaths(NSString *dirPath, BOOL (^condition)(NSString *path)) {
    
    /// Like shell globbing but more cumbersome. I guess we could also use zsh for globbing. [Oct 2025]
    
    auto result = [NSMutableArray new];
    
    for (NSString *p in [[NSFileManager defaultManager] enumeratorAtPath: dirPath])
        if (condition(p))
            [result addObject: [dirPath stringByAppendingPathComponent: p]]; /// Make path absolute, (When it's passed into `condition()` it's still relative – hope that's not confusing [Oct 2025])

    return result;
}

#import <AppKit/AppKit.h>

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

static NSData *imageData(NSImage *image, NSBitmapImageFileType type, NSDictionary *properties) {
        
    /// This implementation comes from the PackagedDocument sample project (https://developer.apple.com/library/archive/samplecode/PackagedDocument/Introduction/Intro.html#//apple_ref/doc/uid/DTS40012955-Intro-DontLinkElementID_2)
    /// Copying this here cause I'm often confused as to what is the right way to serialize an NSImage. [Oct 2025]
    
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

