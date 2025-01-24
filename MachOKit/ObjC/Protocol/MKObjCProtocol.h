//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//! @file       MKObjCProtocol.h
//!
//! @author     D.V.
//! @copyright  Copyright (c) 2014-2015 D.V. All rights reserved.
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

#include <MachOKit/macho.h>
#import <Foundation/Foundation.h>

#import <MachOKit/MKOffsetNode.h>
#import <MachOKit/MKPointer.h>
#import <MachOKit/MKCString.h>

@class MKObjCProtocolList;
@class MKObjCClassMethodList;
@class MKObjCClassPropertyList;
@class MKObjCProtocolMethodTypesList;

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------//
@interface MKObjCProtocol : MKOffsetNode {
@package
    MKPointer *_isa;
    MKPointer *_mangledName;
    MKPointer *_protocols;
    MKPointer *_instanceMethods;
    MKPointer *_classMethods;
    MKPointer *_optionalInstanceMethods;
    MKPointer *_optionalClassMethods;
    MKPointer *_instanceProperties;
    uint32_t _size;
    uint32_t _flags;
    MKPointer *_extendedMethodTypes;
    MKPointer *_demangledName;
    MKPointer *_classProperties;
}

@property (nonatomic, strong, readonly) MKPointer *isa;

@property (nonatomic, strong, readonly) MKPointer<MKCString*> *mangledName;

@property (nonatomic, strong, readonly) MKPointer<MKObjCProtocolList*> *protocols;

@property (nonatomic, strong, readonly) MKPointer<MKObjCClassMethodList*> *instanceMethods;

@property (nonatomic, strong, readonly) MKPointer<MKObjCClassMethodList*> *classMethods;

@property (nonatomic, strong, readonly) MKPointer<MKObjCClassMethodList*> *optionalInstanceMethods;

@property (nonatomic, strong, readonly) MKPointer<MKObjCClassMethodList*> *optionalClassMethods;

@property (nonatomic, strong, readonly) MKPointer<MKObjCClassPropertyList*> *instanceProperties;

@property (nonatomic, assign, readonly) uint32_t size;

@property (nonatomic, assign, readonly) uint32_t flags;

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Extended Protocol Fields
//! @name       Extended Protocol Fields
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@property (nonatomic, strong, readonly, nullable) MKPointer<MKObjCProtocolMethodTypesList*> *extendedMethodTypes;

//! This will point to NULL for Objective-C protocols.
@property (nonatomic, strong, readonly, nullable) MKPointer<MKCString*> *demangledName;

@property (nonatomic, strong, readonly, nullable) MKPointer<MKObjCClassPropertyList*> *classProperties;

@end

NS_ASSUME_NONNULL_END
