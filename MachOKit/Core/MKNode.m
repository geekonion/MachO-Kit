//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKNode.m
//|
//|             D.V.
//|             Copyright (c) 2014-2015 D.V. All rights reserved.
//|
//| Permission is hereby granted, free of charge, to any person obtaining a
//| copy of this software and associated documentation files (the "Software"),
//| to deal in the Software without restriction, including without limitation
//| the rights to use, copy, modify, merge, publish, distribute, sublicense,
//| and/or sell copies of the Software, and to permit persons to whom the
//| Software is furnished to do so, subject to the following conditions:
//|
//| The above copyright notice and this permission notice shall be included
//| in all copies or substantial portions of the Software.
//|
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//| OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//| MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//| IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//| CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//| TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//| SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------------//

#import "MKNode.h"
#import "MKInternal.h"

#import <objc/runtime.h>

_mk_internal const char * const AssociatedDelegate = "AssociatedDelegate";
_mk_internal const char * const AssociatedWarnings = "AssociatedWarnings";
_mk_internal const char * const AssociatedDescription = "AssociatedDescription";

//----------------------------------------------------------------------------//
@implementation MKNode

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithParent:(MKNode*)parent error:(NSError**)error
{
#pragma unused (error)
    self = [super init];
    if (self == nil) return nil;
    
    _parent = parent;
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)init
{ @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"-init unavailable." userInfo:nil]; }

//|++++++++++++++++++++++++++++++++++++|//
- (void)dealloc
{
    self.delegate = nil;
    _parent = nil;
    
    NSLog(@"%s %@", __PRETTY_FUNCTION__, self.className);
}

- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"valueForUndefinedKey %@", key);
    return nil;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Retreiving The Layout and Description
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{ return [MKNodeDescription new]; }

//|++++++++++++++++++++++++++++++++++++|//
- (NSString*)compactDescription
{
    IMP nodeDescriptionMethod = [MKNode instanceMethodForSelector:@selector(description)];
    IMP descriptionMethod = [self methodForSelector:@selector(description)];
    
    if (descriptionMethod != nodeDescriptionMethod)
        return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), self.description];
    else
        return [NSString stringWithFormat:@"<%@>", NSStringFromClass(self.class)];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Getting Related Objects
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (id<MKNodeDelegate>)delegate
{
    id<MKNodeDelegate> delegate = objc_getAssociatedObject(self, AssociatedDelegate);
    if (delegate)
        return delegate;
    else
        return self.parent.delegate;
}

//|++++++++++++++++++++++++++++++++++++|//
- (void)setDelegate:(id<MKNodeDelegate>)delegate
{ objc_setAssociatedObject(self, AssociatedDelegate, delegate, OBJC_ASSOCIATION_ASSIGN); }

//|++++++++++++++++++++++++++++++++++++|//
- (MKMemoryMap*)memoryMap
{ return self.parent.memoryMap; }

//|++++++++++++++++++++++++++++++++++++|//
- (MKDataModel*)dataModel
{ return self.parent.dataModel; }

//|++++++++++++++++++++++++++++++++++++|//
- (NSArray*)warnings
{ return objc_getAssociatedObject(self, AssociatedWarnings) ?: @[]; }
- (void)setWarnings:(NSArray*)warnings
{ objc_setAssociatedObject(self, AssociatedWarnings, warnings, OBJC_ASSOCIATION_COPY); }

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Navigating the Node Tree
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize parent = _parent;

//|++++++++++++++++++++++++++++++++++++|//
- (nullable __kindof MKNode*)nearestAncestorOfType:(Class)cls
{
    NSParameterAssert([cls isSubclassOfClass:MKNode.class]);
    
    for (MKNode *n = self; n != nil; n = n.parent) {
        if ([n isKindOfClass:cls])
            return n;
    }
    
    return nil;
}

//|++++++++++++++++++++++++++++++++++++|//
- (nullable __kindof MKNode*)nearestAncestorConformingToProtocol:(Protocol*)protocol
{
    for (MKNode *n = self; n != nil; n = n.parent) {
        if ([n conformsToProtocol:protocol])
            return n;
    }
    
    return nil;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Subclasses
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
+ (NSSet *)_subclassesCache
{ return NULL; }

+ (void)_setSubclassesCache:(NSSet *)subclasses {
}

//|++++++++++++++++++++++++++++++++++++|//
+ (NSSet*)subclasses
{
    NSMutableSet <Class>*subclasses = NULL;
    @synchronized(self) {
        NSSet *cache = [self _subclassesCache];
        if (cache) {
            return cache;
        }
        
        subclasses = [NSMutableSet set];
        
        unsigned classCount;
        Class *classes = objc_copyClassList(&classCount);
        Class specClass = objc_getClass("SPTSpec");

        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classes[i];

            // Without this, Specta breaks.  Technically only needed during testing.
            if (specClass && class_getSuperclass(cls) == specClass)
                continue;

            // Calling +isSubclassOfClass: causes the receiver's +initialize
            // to run (if it has one).  Avoid that.
            for (Class s = cls; s != nil; s = class_getSuperclass(s)) {
                if (s == self)
                    [subclasses addObject:cls];
            }
        }
        
        free(classes);
        
        [self _setSubclassesCache:subclasses];
    }
    

    return subclasses;
}

//|++++++++++++++++++++++++++++++++++++|//
+ (Class)bestSubclassWithRanking:(uint32_t (^)(Class cls))rank
{
    // TODO - Don't let anything into the autorelease pool here.
    NSMutableArray *subclasses = [[[self subclasses] allObjects] mutableCopy];
    
    if (subclasses.count)
    {
        [subclasses sortUsingComparator:^NSComparisonResult(Class obj1, Class obj2) {
            uint32_t class1Score = rank(obj1);
            uint32_t class2Score = rank(obj2);
            if (class1Score > class2Score) return NSOrderedDescending;
            else if (class1Score < class2Score) return NSOrderedAscending;
            else return NSOrderedSame;
        }];
        
        Class retValue = [subclasses lastObject];
        
        if (rank(retValue) > 0)
            return retValue;
        else
            return self;
    }
    
    return self;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  NSObject
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
+ (NSString*)description
{
    NSString *cachedDescription = objc_getAssociatedObject(self, AssociatedDescription);
    if (cachedDescription)
        return cachedDescription;
    
    @synchronized(self)
    {
        // Make sure another thread did not beat us.
        cachedDescription = objc_getAssociatedObject(self, AssociatedDescription);
        if (cachedDescription)
            return cachedDescription;
        
        NSString *className = NSStringFromClass(self);
        NSMutableString *description = [NSMutableString new];
        
        /* Split the camel case class name into words. */
        for (NSUInteger i = [className hasPrefix:@"MK"] ? 2 : 0; i < className.length; i++) {
            unichar character = [className characterAtIndex:i];
            
            if (description.length == 0) {
                CFStringAppendCharacters((CFMutableStringRef)description, &character, 1);
                continue;
            }
            
            if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:character]) {
                [description appendString:@" "];
            }
            
            CFStringAppendCharacters((CFMutableStringRef)description, &character, 1);
        }
        
        cachedDescription = description;
        
        objc_setAssociatedObject(self, AssociatedDescription, cachedDescription, OBJC_ASSOCIATION_RETAIN);
    }
    
    return cachedDescription;
}

//|++++++++++++++++++++++++++++++++++++|//
- (NSString*)debugDescription
{ return [self.layout textualDescriptionForNode:self traversalDepth:NSUIntegerMax]; }

@end

