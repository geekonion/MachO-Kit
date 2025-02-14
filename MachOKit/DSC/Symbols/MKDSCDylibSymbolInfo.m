//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKDSCDylibSymbolInfo.m
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

#import "MKDSCDylibSymbolInfo.h"
#import "NSError+MK.h"
#import "DyldSharedCache.h"
#import "MKDSCLocalSymbols.h"
#import "MKDSCDylibInfos.h"

#include "dyld_cache_format.h"

//----------------------------------------------------------------------------//
@implementation MKDSCDylibSymbolInfo

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithIndex:(uint32_t)index fromParent:(MKBackedNode*)parent error:(NSError**)error
{
    NSParameterAssert(parent.dataModel);
    
    mk_vm_offset_t offset = index * sizeof(dc_local_symbols_entry_t);
    self = [super initWithOffset:index fromParent:parent error:error];
    if (self == nil) return nil;
    
    MKDSCDylibInfos *infos = (id)self.parent;
    MKDSCLocalSymbols *symbols = (id)infos.parent;
    DyldSharedCache *dsc = symbols.dsc;
    DyldSharedCacheFile *symDsc = dsc->files[dsc->symbolFile.index];
    struct dyld_cache_header *symHeader = &symDsc->header;
    uint64_t sym_off = symHeader->localSymbolsOffset;
    dc_local_symbols_entry_t sclse = {};
    if (sym_off) {
        dsc_file_read_at_offset(symDsc, sym_off + infos.nodeOffset + offset, sizeof(sclse), &sclse);
    }
    
    _dylibOffset = MKSwapLValue64(sclse.dylibOffset, self.dataModel);
    _nlistStartIndex = MKSwapLValue32(sclse.nlistStartIndex, self.dataModel);
    _nlistCount = MKSwapLValue32(sclse.nlistCount, self.dataModel);
    
    return self;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Local Symbols Entry Struct Values
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize dylibOffset = _dylibOffset;
@synthesize nlistStartIndex = _nlistStartIndex;
@synthesize nlistCount = _nlistCount;

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (mach_vm_size_t)nodeSize
{ return sizeof(struct dyld_cache_local_symbols_entry); }

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        [MKPrimativeNodeField fieldWithProperty:MK_PROPERTY(dylibOffset) description:@"Dylib offset" offset:offsetof(struct dyld_cache_local_symbols_entry, dylibOffset) size:sizeof(uint32_t)],
        [MKPrimativeNodeField fieldWithProperty:MK_PROPERTY(nlistStartIndex) description:@"Start Index" offset:offsetof(struct dyld_cache_local_symbols_entry, nlistStartIndex) size:sizeof(uint32_t)],
        [MKPrimativeNodeField fieldWithProperty:MK_PROPERTY(nlistCount) description:@"Number of Symbols" offset:offsetof(struct dyld_cache_local_symbols_entry, nlistCount) size:sizeof(uint32_t)]
    ]];
}

@end
