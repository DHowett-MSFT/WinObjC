//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include <TestFramework.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Starboard/SmartTypes.h>
#import <IwMalloc.h>

#define TEST_PREFIX Foundation_NSObject_Tests
#define _CONCAT(x, y) x ## y
#define CONCAT(x, y) _CONCAT(x, y)
#define TEST_IDENT(x) CONCAT(TEST_PREFIX, _ ## x)

typedef struct {
    int a;
    float b;
} MixedStruct;

@interface TEST_IDENT(BaseClass) : NSObject
- (void)methodWithMixedStructArg:(MixedStruct)arg;
- (MixedStruct)methodWithMixedStructReturn;
- (float)methodWithChangingReturnType;
@end

@interface TEST_IDENT(DerivedClass) : TEST_IDENT(BaseClass)
- (void)methodExtantOnlyOnDerivedType;
- (MixedStruct)methodWithMixedStructReturn;
- (int)methodWithChangingReturnType;
@end

@implementation TEST_IDENT(BaseClass)
- (void)methodWithMixedStructArg:(MixedStruct)arg {

}
- (MixedStruct)methodWithMixedStructReturn {
    return {1, 1.0f};
}
- (float)methodWithChangingReturnType {
    return 1.0;
}
@end

@implementation TEST_IDENT(DerivedClass)
- (void)methodExtantOnlyOnDerivedType {
}
- (MixedStruct)methodWithMixedStructReturn {
    return {2, 2.0f};
}
- (int)methodWithChangingReturnType {
    return 10;
}
@end

TEST(NSObject, InstanceMethodSignature) {
    // -[BaseClass methodWithMixedStructArg:] is a method that returns void and takes
    // a single public argument. Adding in self and _cmd (the selector) brings the true
    // argument count to 3.
    NSMethodSignature* base_mixedStructArg = [TEST_IDENT(BaseClass) instanceMethodSignatureForSelector:@selector(methodWithMixedStructArg:)];
    EXPECT_OBJCNE(nil, base_mixedStructArg);
    EXPECT_STREQ(@encode(void), [base_mixedStructArg methodReturnType]);
    EXPECT_EQ(0, [base_mixedStructArg methodReturnLength]);
    EXPECT_EQ(3, [base_mixedStructArg numberOfArguments]);
    EXPECT_STREQ(@encode(MixedStruct), [base_mixedStructArg getArgumentTypeAtIndex:2]);

    NSMethodSignature* base_mixedStructRet = [TEST_IDENT(BaseClass) instanceMethodSignatureForSelector:@selector(methodWithMixedStructReturn)];
    EXPECT_OBJCNE(nil, base_mixedStructRet);
    EXPECT_STREQ(@encode(MixedStruct), [base_mixedStructRet methodReturnType]);
    EXPECT_EQ(sizeof(MixedStruct), [base_mixedStructRet methodReturnLength]);
    EXPECT_EQ(2, [base_mixedStructRet numberOfArguments]);

    NSMethodSignature* base_changingRet = [TEST_IDENT(BaseClass) instanceMethodSignatureForSelector:@selector(methodWithChangingReturnType)];
    EXPECT_OBJCNE(nil, base_changingRet);
    EXPECT_STREQ(@encode(float), [base_changingRet methodReturnType]);
    EXPECT_EQ(sizeof(float), [base_changingRet methodReturnLength]);
    EXPECT_EQ(2, [base_changingRet numberOfArguments]);

    // Test that derived methods do not appear on parent classes.
    EXPECT_OBJCEQ(nil, [TEST_IDENT(BaseClass) instanceMethodSignatureForSelector:@selector(methodOnlyExtantOnDerivedType)]);

    // Test whether method signatures are inherited.
    NSMethodSignature* derived_mixedStructArg = [TEST_IDENT(DerivedClass) instanceMethodSignatureForSelector:@selector(methodWithMixedStructArg:)];
    EXPECT_OBJCNE(nil, derived_mixedStructArg);
    EXPECT_STREQ(@encode(void), [derived_mixedStructArg methodReturnType]);
    EXPECT_EQ(0, [derived_mixedStructArg methodReturnLength]);
    EXPECT_EQ(3, [derived_mixedStructArg numberOfArguments]);
    EXPECT_STREQ(@encode(MixedStruct), [derived_mixedStructArg getArgumentTypeAtIndex:2]);

    NSMethodSignature* derived_mixedStructRet = [TEST_IDENT(DerivedClass) instanceMethodSignatureForSelector:@selector(methodWithMixedStructReturn)];
    EXPECT_OBJCNE(nil, derived_mixedStructRet);
    EXPECT_STREQ(@encode(MixedStruct), [derived_mixedStructRet methodReturnType]);
    EXPECT_EQ(sizeof(MixedStruct), [derived_mixedStructRet methodReturnLength]);
    EXPECT_EQ(2, [derived_mixedStructRet numberOfArguments]);

    NSMethodSignature* derived_changingRet = [TEST_IDENT(DerivedClass) instanceMethodSignatureForSelector:@selector(methodWithChangingReturnType)];
    EXPECT_OBJCNE(nil, derived_changingRet);
    EXPECT_STREQ(@encode(int), [derived_changingRet methodReturnType]);
    EXPECT_EQ(sizeof(int), [derived_changingRet methodReturnLength]);
    EXPECT_EQ(2, [derived_changingRet numberOfArguments]);
}

TEST(NSObject, NSZombie) { // This test will fail with an AV if zombies do not work.
    WinObjC_SetZombiesEnabled(YES);

    NSObject* object = [[NSObject alloc] init];
    [object release];
    EXPECT_ANY_THROW([object self]);

    WinObjC_SetZombiesEnabled(NO);
}

@interface TEST_IDENT(DynamicResolution): NSObject
- (void)dynamicInstanceMethodForSignature:(int)x;
+ (void)dynamicClassMethodForSignature:(int)x;
- (void)dynamicInstanceMethodForResponseChecking;
+ (void)dynamicClassMethodForResponseChecking;
- (int)dynamicInstanceMethod;
+ (int)dynamicClassMethod;
@end

static void _voidImp(id self, SEL _cmd) {
}

static int _intImp(id self, SEL _cmd) {
    return 2048;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TEST_IDENT(DynamicResolution)
+ (BOOL)resolveClassMethod:(SEL)method {
    IMP imp = nullptr;
    const char* types = nullptr;
    if (sel_isEqual(method, @selector(dynamicClassMethodForResponseChecking))) {
        imp = (IMP)&_voidImp;
        types = "v@:";
    } else if (sel_isEqual(method, @selector(dynamicClassMethodForSignature:))) {
        imp = (IMP)&_voidImp;
        types = "v@:i";
    } else if (sel_isEqual(method, @selector(dynamicClassMethod))) {
        imp = (IMP)&_intImp;
        types = "i@:";
    }
    if (imp) {
        class_addMethod(object_getClass(self), method, imp, types);
    }
    return imp != nullptr;
}

+ (BOOL)resolveInstanceMethod:(SEL)method {
    IMP imp = nullptr;
    const char* types = nullptr;
    if (sel_isEqual(method, @selector(dynamicInstanceMethodForResponseChecking))) {
        imp = (IMP)&_voidImp;
        types = "v@:";
    } else if (sel_isEqual(method, @selector(dynamicInstanceMethodForSignature:))) {
        imp = (IMP)&_voidImp;
        types = "v@:i";
    } else if (sel_isEqual(method, @selector(dynamicInstanceMethod))) {
        imp = (IMP)&_intImp;
        types = "i@:";
    }
    if (imp) {
        class_addMethod(self, method, imp, types);
    }
    return imp != nullptr;
}
@end
#pragma clang diagnostic pop

TEST(NSObject, DynamicRespondsToSelector) {
    EXPECT_TRUE([TEST_IDENT(DynamicResolution) respondsToSelector:@selector(dynamicClassMethodForResponseChecking)]);
    EXPECT_FALSE([TEST_IDENT(DynamicResolution) respondsToSelector:@selector(dynamicInstanceMethodForResponseChecking)]);
    EXPECT_TRUE([TEST_IDENT(DynamicResolution) instancesRespondToSelector:@selector(dynamicInstanceMethodForResponseChecking)]);
    EXPECT_FALSE([TEST_IDENT(DynamicResolution) instancesRespondToSelector:@selector(dynamicClassMethodForResponseChecking)]);
}

TEST(NSObject, DynamicClassResolution) {
    EXPECT_EQ(2048, [TEST_IDENT(DynamicResolution) dynamicClassMethod]);
    EXPECT_ANY_THROW([TEST_IDENT(DynamicResolution) dynamicInstanceMethod]);

    NSMethodSignature* signature = nil;
    ASSERT_OBJCNE(nil, signature = [TEST_IDENT(DynamicResolution) methodSignatureForSelector:@selector(dynamicClassMethodForSignature:)]);
    EXPECT_STREQ("i", [signature getArgumentTypeAtIndex:2]);

    EXPECT_OBJCEQ(nil, [TEST_IDENT(DynamicResolution) methodSignatureForSelector:@selector(dynamicInstanceMethodForSignature:)]);
}

TEST(NSObject, DynamicResolution) {
    id instance = [[[TEST_IDENT(DynamicResolution) alloc] init] autorelease];
    EXPECT_EQ(2048, [instance dynamicInstanceMethod]);
    EXPECT_ANY_THROW([instance dynamicClassMethod]);

    NSMethodSignature* signature = nil;
    ASSERT_OBJCNE(nil, signature = [instance methodSignatureForSelector:@selector(dynamicInstanceMethodForSignature:)]);
    EXPECT_STREQ("i", [signature getArgumentTypeAtIndex:2]);

    EXPECT_OBJCEQ(nil, [instance methodSignatureForSelector:@selector(dynamicClassMethodForSignature:)]);
}

enum annotation_type: unsigned int {
    Unknown = 0,
    Cluster,
    Prototype,
};

struct annotation {
    id protocol;
    Class baseClass;
    annotation* next;
};

static std::map<std::tuple<std::string, annotation_type>, annotation> gatherAnnotationProtocols() {
    std::map<std::tuple<std::string, annotation_type>, annotation> annotations;
    unsigned int count = 0;
    woc::unique_iw<Protocol*> objcProtocolList(objc_copyProtocolList(&count));
    for(int i = 0; i < count; ++i) {
        Protocol* p = *(objcProtocolList.get() + i);
        annotation_type type = Unknown;
        if(strstr(protocol_getName(p), "_Annotation_Cluster") != nullptr) {
            type = Cluster;
        } else if(strstr(protocol_getName(p), "_Annotation_Prototype") != nullptr) {
            type = Prototype;
        }

        if (type == Unknown) {
            continue;
        }

        char* name = IwStrDup(protocol_getName(p));
        name[strlen(name) - (type == Cluster ? 19 : 21)] = '\0';
        std::string className(name);
        Class cls = objc_getClass(name);
        IwFree(name);
        annotation& a = annotations[std::forward_as_tuple(className, type)];
        a.protocol = p;
        a.baseClass = cls;
        a.next = nullptr;
    }

    for (auto& pair: annotations) {
        auto& a = pair.second;
        Class cls = a.baseClass;
        for(cls = class_getSuperclass(cls); cls; cls = class_getSuperclass(cls)) {
            std::string thisClassName(class_getName(cls));
            auto f = annotations.find(std::forward_as_tuple(thisClassName, std::get<1>(pair.first)));
            if (f != annotations.end()) {
                a.next = &f->second;
                break;
            }
        }
    }
    return annotations;
}

@protocol NSCalendar_Annotation_Prototype
@required
- (id)initWithCalendarIdentifier:(int)identifier;
@end

@protocol NSCalendar_Annotation_Cluster
@required
- (BOOL)date:(NSDate*)date matchesComponents:(NSDateComponents*)comps;
- (NSUInteger)notTheRealLengthButClose;
@optional
- (void)calculateExpensiveThings;
@end

TEST(AAA, AAAA) {
    auto annotations = gatherAnnotationProtocols();
    std::set<Class> annotatedClasses;
    for(auto pair: annotations) {
        annotatedClasses.emplace(pair.second.baseClass);
    }

    unsigned int count;
    woc::unique_iw<Class[]> objcClassList(objc_copyClassList(&count));
    for(int i = 0; i < count; ++i) {
        Class baseClass, cls = baseClass = objcClassList[i];
        if (annotatedClasses.find(cls) != annotatedClasses.end()) {
            // Do not signal on annotated classes themselves.
            continue;
        }
        std::string baseClassName(class_getName(baseClass));
        annotation_type classType = Cluster;
        const char* typeString = "Concrete";
        if (baseClassName.find("Prototype") != std::string::npos) {
            classType = Prototype;
            typeString = "Prototype";
        }

        for(; cls; cls = class_getSuperclass(cls)) {
            std::string thisClassName(class_getName(cls));

            auto f = annotations.find(std::forward_as_tuple(thisClassName, classType));
            if (f == annotations.end()) {
                continue;
            }

            for(annotation* a = &f->second; a; a = a->next) {
                if (baseClass == a->baseClass) {
                    continue;
                }

                unsigned int reqCount = 0, optCount = 0;
                woc::unique_iw<objc_method_description[]> reqMethodDescs(protocol_copyMethodDescriptionList(a->protocol, YES, YES, &reqCount));
                woc::unique_iw<objc_method_description[]> optMethodDescs(protocol_copyMethodDescriptionList(a->protocol, NO, YES, &optCount));
                for(unsigned int method_i = 0; method_i < reqCount; ++method_i) {
                    objc_method_description& desc = reqMethodDescs[method_i];
                    Method rootMethod = class_getInstanceMethod(a->baseClass, desc.name);
                    Method m = class_getInstanceMethod(baseClass, desc.name);
                    if (rootMethod && m == rootMethod) {
                        // Ignore implementations inherited straight from the base class.
                        m = nullptr;
                    }
                    EXPECT_NE_MSG(nullptr, m, @"%s subclass %s of class cluster %@ does not implement required method %s.", typeString, class_getName(baseClass), a->baseClass, sel_getName(desc.name));
                    if (m) {
                        EXPECT_STREQ_MSG(desc.types, method_getTypeEncoding(m), @"%s subclass %s of class cluster %@ implemented required method %s with incorrect type.", typeString, class_getName(baseClass), a->baseClass, sel_getName(desc.name));
                    }
                }
                for(unsigned int method_i = 0; method_i < optCount; ++method_i) {
                    objc_method_description& desc = optMethodDescs[method_i];
                    Method rootMethod = class_getInstanceMethod(a->baseClass, desc.name);
                    Method m = class_getInstanceMethod(baseClass, desc.name);
                    if (rootMethod && m == rootMethod) {
                        // Ignore implementations inherited straight from the base class.
                        m = nullptr;
                    }
                    if (!m) {
                        LOG_INFO(@"%s subclass %s of class cluster %@ could implement optional method %s for performance improvements.", typeString, class_getName(baseClass), a->baseClass, sel_getName(desc.name));
                    }
                }
            }
        }
    }

}
