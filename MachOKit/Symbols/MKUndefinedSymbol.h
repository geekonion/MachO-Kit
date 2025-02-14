//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//! @file       MKUndefinedSymbol.h
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

#import <MachOKit/MKRegularSymbol.h>
#import <MachOKit/MKNodeFieldSymbolReferenceType.h>
#import <MachOKit/MKNodeFieldSymbolLibraryOrdinalType.h>

@class MKDependentLibrary;

NS_ASSUME_NONNULL_BEGIN

//----------------------------------------------------------------------------//
@interface MKUndefinedSymbol : MKRegularSymbol {
@package
    MKDependentLibrary *_sourceLibrary;
}

//! Indicates if the  undefined reference is a lazy reference or non-lazy
//! reference.
@property (nonatomic, assign, readonly) MKSymbolReferenceType referenceType;

//! For images with two-level namespaces, the index of the library the
//! undefined symbol is bound to.
@property (nonatomic, assign, readonly) MKSymbolLibraryOrdinal sourceLibraryOrdinal;

//! For images with two-level namespaces, the library the undefined symbol is
//! bound to.
@property (nonatomic, strong, readonly, nullable) MKDependentLibrary *sourceLibrary;

//! \c True if the undefined symbol is allowed to be missing and is to have
//! the address of zero when missing.
@property (nonatomic, assign, readonly, getter=isWeakReference) BOOL weakReference;

//! \c True if the undefined symbol should be resolved using flat namespace
//! searching.
@property (nonatomic, assign, readonly, getter=isReferenceToWeak) BOOL referenceToWeak;

@end

NS_ASSUME_NONNULL_END
