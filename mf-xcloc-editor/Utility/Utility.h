//
//  Utility.h
//  mf-xcloc-editor
//
//  Created by Noah Nübling on 09.06.25.
//

#import <AppKit/AppKit.h>

/// Most of these macros are copies / reimplementations from ` mac-mouse-fix` [Nov 2025]
///     Look there for documentation.

///
/// Helper macros
///

#define TOSTR(x)    #x                      /// `#` operator but delayed – Sometimes necessary when order-of-operations matters
#define TOSTR_(x)   TOSTR(x)                /// `#` operator but delayed even more

///
/// General convenience
///

#define auto __auto_type                /// `auto` keyword is unused in C, so overriding with CPP-style `__auto_type` should be fine.
#define isclass(obj,  classname)        ({ [[(obj) class] isSubclassOfClass: [classname class]]; })
#define isclassd(obj, classname_str)     ({ [[(obj) class] isSubclassOfClass: NSClassFromString(classname_str)]; })
#define stringf(format, args...)        [NSString stringWithFormat: (format), ## args]
#define attributed(str)                 [[NSMutableAttributedString alloc] initWithString: (str)]

#define arrcount(x...) (sizeof ((x)) / sizeof (x)[0])
        
#define nowtime() (CACurrentMediaTime() * 1000.0) /// Timestamp in milliseconds
        
#define mferror(domain, code_, msg_and_args...) \
    [NSError errorWithDomain: (domain) code: (code_) userInfo: @{ NSDebugDescriptionErrorKey: stringf(msg_and_args) }] /** Should we use `NSLocalizedFailureReasonErrorKey`? [Oct 2025] */

#define bitpos(mask) (                                                  \
    (mask) == 0               ? -1 :                                    /** Fail: less than one bit set */\
    ((mask) & (mask)-1) != 0  ? -1 :                                    /** Fail: more than one bit set (aka not a power of two) */\
    __builtin_ctz(mask)                                                 /** Sucess! – Count trailling zeros*/ \
)

#define nowarn_push(w)                                                      \
    _Pragma("clang diagnostic push")                                        \
    _Pragma(TOSTR(clang diagnostic ignored #w))                             \

#define nowarn_pop()                                                        \
    _Pragma("clang diagnostic pop")

#define safeindex(arr, count, idx, fallback) ({                   \
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

#define tourl(pathstr) [NSURL fileURLWithPath: (pathstr)]
#define toset(arr...) [NSSet setWithArray: (arr)]

#define charset(str) [NSCharacterSet characterSetWithCharactersInString: (str)]

NSMutableIndexSet *indexSetWithIndexArray(NSInteger arr[], int len);
#define indexset(indexes...) ({ \
    NSInteger _arr[] = { indexes }; \
    indexSetWithIndexArray(_arr, arrcount(_arr)); \
})

struct _MFRectOverrides { CGFloat x, y, width, height; };
NSRect _NSRectFromRect(NSRect base, struct _MFRectOverrides overrides);
#define NSRectFromRect(base, overrides_...) ({ \
    [[maybe_unused]] CGFloat x = (base).origin.x; /** Make locali vars so the expressions that the caller passes into `overrides_` can easily reference the current values in the `base` NSRect. This is a bit obscure, not sure if good API, usually it's better when the caller passes in a varname [Nov 2025] */\
    [[maybe_unused]] CGFloat y = (base).origin.y; \
    [[maybe_unused]] CGFloat width = (base).size.width; \
    [[maybe_unused]] CGFloat height = (base).size.height; \
    _NSRectFromRect((base), (struct _MFRectOverrides) { nowarn_push(-Winitializer-overrides) \
        .x=NAN, .y=NAN, .width=NAN, .height=NAN, ##overrides_ \
    nowarn_pop() }); \
})

///
/// Logging
///

NSString *_shorten__func__(const char *func);
#define mflog(msg...)  printf("%s: %s\n", /*__FILE_NAME__,*/ [_shorten__func__(__func__) UTF8String], [stringf(@"" msg) UTF8String])

///
/// XML
///

typedef struct { NSXMLNode *fallback; } xml_attr_args;
NSXMLNode *_xml_attr(NSXMLElement *xmlElement, NSString *name, xml_attr_args args);
#define xml_attr(xmlElement, name, fallback...) _xml_attr((xmlElement), (name), (xml_attr_args) { fallback })

typedef struct { NSXMLNode *fallback; } xml_childnamed_args;
NSXMLNode *_xml_childnamed(NSXMLElement *_node, NSString *name_, xml_childnamed_args args);
#define xml_childnamed(node, name, fallback...) _xml_childnamed((node), (name), (xml_childnamed_args){ fallback })

NSMutableDictionary<NSString *, NSXMLNode *> *xml_attrdict(NSXMLElement *_xmlElement);

///
/// Files
///

//void fw_walk(NSFileWrapper *fileWrapper, void (^callback)(NSFileWrapper *w, NSString *subpath, BOOL *stop));
NSFileWrapper *fw_readPath(NSFileWrapper *fw, NSString *subpath);
void fw_writePath(NSFileWrapper *fw, NSString *subpath, NSData *fileContents);
NSArray<NSString *> *fw_findPaths(NSFileWrapper *wrapper, BOOL (^condition)(NSFileWrapper *fw, NSString *p, BOOL *stop));
NSArray<NSString *> *findPaths(int timeout_ms, NSString *dirPath, BOOL (^condition)(NSString *path));

/// Animate

struct mfanimate_args {
    NSTimeInterval duration;
    CAMediaTimingFunction *curve;
    BOOL implicitAnimation;
};
#define mfanimate_args(args...) nowarn_push(-Winitializer-overrides) \
    (struct mfanimate_args) { .duration = NAN, ## args } \
nowarn_pop() \


void mfanimate(struct mfanimate_args args, void (^block)(void), void (^completion)(void));

///
///
///
/// Other
///
///
///

NSEvent *makeKeyDown(unichar keyEquivalent, int keyCode);
BOOL eventIsKey(NSEvent *event, unichar key);
void runOnMain(double delay, void (^workload)(void));
void mfdebounce(double delay, NSString *identifier, void (^block)(void));
NSData *imageData(NSImage *image, NSBitmapImageFileType type, NSDictionary *properties);
