//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//! @file       MKSplitSegmentInfoV1.h
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

#import <MachOKit/MKLinkEditNode.h>

@class MKSplitSegmentInfoV1Entry;
@class MKSplitSegmentInfoV1Terminator;
@class MKSplitSegmentInfoV1Fixup;

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------//
@interface MKSplitSegmentInfoV1 : MKLinkEditNode {
@package
    NSArray<MKSplitSegmentInfoV1Entry*> *_entries;
    MKSplitSegmentInfoV1Terminator *_terminator;
    NSArray<MKSplitSegmentInfoV1Fixup*> *_fixups;
}

//! Initializes the receiver with the provided Mach-O.
- (nullable instancetype)initWithImage:(MKMachOImage*)image error:(NSError**)error;

//!
@property (nonatomic, strong, readonly) NSArray<__kindof MKSplitSegmentInfoV1Entry*> *entries;

//!
@property (nonatomic, strong, readonly, nullable) MKSplitSegmentInfoV1Terminator *terminator;

//! 
@property (nonatomic, strong, readonly) NSArray<MKSplitSegmentInfoV1Fixup*> *fixups;

@end

NS_ASSUME_NONNULL_END
