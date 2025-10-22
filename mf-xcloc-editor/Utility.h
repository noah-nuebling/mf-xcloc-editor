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

static NSArray<NSString *> *findPaths(NSString *dirPath, BOOL (^condition)(NSString *path)) {
    
    auto result = [NSMutableArray new];
    
    for (NSString *p in [[NSFileManager defaultManager] enumeratorAtPath: dirPath])
        if (condition(p))
            [result addObject: [dirPath stringByAppendingPathComponent: p]]; /// Make path absolute, (So when it's passed into `condition()` it's still relative – hope that's not confusing [Oct 2025]

    return result;
}

