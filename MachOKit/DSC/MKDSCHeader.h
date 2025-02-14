//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//! @file       MKDSCHeader.h
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

#import <MachOKit/macho.h>
#import <Foundation/Foundation.h>
#import <MachOKit/MKOffsetNode.h>
#import <MachOKit/DyldSharedCache.h>

@class MKVersion;
NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------//
//! The \c MKDSCHeader parses the structure at the beginning of a the dyld
//! shared cache.
//
@interface MKDSCHeader : MKOffsetNode {
@package
    NSString *_magic;
    uint32_t _mappingOffset;
    uint32_t _mappingCount;
    uint32_t _imagesOffset;
    uint64_t _imagesCount;
    uint64_t _dyldBaseAddress;
    uint64_t _codeSignatureOffset;
    uint64_t _codeSignatureSize;
    uint64_t _slideInfoOffset;
    uint64_t _slideInfoSize;
    uint64_t _localSymbolsOffset;
    uint64_t _localSymbolsSize;
    NSUUID *_uuid;
    uint64_t _cacheType;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Shared Cache Header Values
//! @name       Shared Cache Header Values
//!
//! @brief      These values are lifted directly from the shared cache
//!             header without modification or cleanup.
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@property (nonatomic, strong, readonly) NSString *magic;
@property (nonatomic, assign, readonly) uint32_t mappingOffset;
@property (nonatomic, assign, readonly) uint32_t mappingCount;
@property (nonatomic, assign, readonly) uint32_t imagesOffset;
@property (nonatomic, assign, readonly) uint64_t imagesCount;
@property (nonatomic, assign, readonly) uint64_t dyldBaseAddress;
@property (nonatomic, assign, readonly) uint64_t codeSignatureOffset;
@property (nonatomic, assign, readonly) uint64_t codeSignatureSize;
@property (nonatomic, assign, readonly) uint64_t slideInfoOffset;
@property (nonatomic, assign, readonly) uint64_t slideInfoSize;
@property (nonatomic, assign, readonly) uint64_t localSymbolsOffset;
@property (nonatomic, assign, readonly) uint64_t localSymbolsSize;
@property (nonatomic, strong, readonly, nullable) NSUUID *uuid;
@property (nonatomic, assign, readonly) uint64_t cacheType;

@property (nonatomic, strong, readonly) MKVersion *osVersion;
@property (nonatomic, assign, readonly) uint32_t platform;

- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent dsc:(DyldSharedCache *)dsc error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
