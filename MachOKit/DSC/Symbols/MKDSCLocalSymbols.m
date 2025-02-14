//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKDSCLocalSymbols.m
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

#import "MKDSCLocalSymbols.h"
#import "NSError+MK.h"
#import "MKNode+SharedCache.h"
#import "MKSharedCache.h"
#import "MKDSCHeader.h"
#import "MKDSCLocalSymbolsHeader.h"
#import "MKDSCSymbolTable.h"
#import "MKDSCStringTable.h"
#import "MKDSCDylibInfos.h"

//----------------------------------------------------------------------------//
@implementation MKDSCLocalSymbols {
    DyldSharedCache *_dsc;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithSharedCache:(MKSharedCache*)sharedCache error:(NSError**)error
{
    NSParameterAssert(sharedCache);
    NSError *localError = nil;
    mk_error_t err = MK_ESUCCESS;
    
    self = [super initWithParent:sharedCache error:error];
    if (self == nil) return nil;
    
    // Local symbols do not reside in a region of the shared cache that is
    // mapped into process memory.
    _memoryMap = sharedCache.memoryMap;
    
    mk_vm_offset_t localSymbolsOffset = sharedCache.header.localSymbolsOffset;
    mk_vm_size_t localSymbolsSize = sharedCache.header.localSymbolsSize;
    mk_vm_address_t sharedCacheAddress = sharedCache.nodeContextAddress;
    
    if ((err = mk_vm_address_apply_offset(sharedCacheAddress, localSymbolsOffset, &_contextAddress))) {
        MK_ERROR_OUT = MK_MAKE_VM_ADDRESS_APPLY_OFFSET_ARITHMETIC_ERROR(err, sharedCacheAddress, localSymbolsOffset);
        return nil;
    }

    // Local symbols are not mapped.
    _vmAddress = MK_VM_ADDRESS_INVALID;
    
    _size = [self.memoryMap mappingSizeAtOffset:localSymbolsOffset fromAddress:sharedCacheAddress length:localSymbolsSize];
    // This is not an error...
    if (_size < localSymbolsSize) {
        MK_PUSH_WARNING(nodeSize, MK_EINVALID_DATA, @"Mappable memory at address %" MK_VM_PRIxADDR " for local symbols is less than the expected size %" MK_VM_PRIxSIZE ".", self.nodeContextAddress, localSymbolsSize);
    }
    
    // ...but it will be if we can't map the symbols info header.
    _header = [[MKDSCLocalSymbolsHeader alloc] initWithParent:self error:&localError];
    if (_header == nil) {
        MK_ERROR_OUT = [NSError mk_errorWithDomain:MKErrorDomain code:localError.code underlyingError:localError description:@"Failed to load symbols info header."];
        return nil;
    }
    
    return self;
}

- (instancetype)initWithSharedCache:(MKSharedCache*)sharedCache {
    NSParameterAssert(sharedCache);
    NSError *localError = nil;
    
    self = [super initWithParent:sharedCache error:&localError];
    if (self == nil) return nil;
    
    _size = sharedCache.header.localSymbolsSize;
    _dsc = sharedCache.dsc;
    // ...but it will be if we can't map the symbols info header.
    _header = [[MKDSCLocalSymbolsHeader alloc] initWithDSC:_dsc offset:0 fromParent:self error:&localError];
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithParent:(MKNode*)parent error:(NSError**)error
{ return [self initWithSharedCache:parent.sharedCache error:error]; }

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize header = _header;

//|++++++++++++++++++++++++++++++++++++|//
- (MKDSCSymbolTable*)symbolTable
{
    if (_symbolTable == nil)
    @autoreleasepool {
        NSError *e = nil;
            
        _symbolTable = [[MKDSCSymbolTable alloc] initWithParent:self error:&e];
        if (_symbolTable == nil)
            MK_PUSH_UNDERLYING_WARNING(symbolTable, e, @"Could not load symbol table.");
    }
    
    return _symbolTable;
}

//|++++++++++++++++++++++++++++++++++++|//
- (MKDSCStringTable*)stringTable
{
    if (_stringTable == nil)
    @autoreleasepool {
        NSError *e = nil;
        
        _stringTable = [[MKDSCStringTable alloc] initWithParent:self error:&e];
        if (_stringTable == nil)
            MK_PUSH_UNDERLYING_WARNING(stringTable, e, @"Could not load string table.");
    }
    
    return _stringTable;
}

//|++++++++++++++++++++++++++++++++++++|//
- (MKDSCDylibInfos*)entriesTable
{
    if (_entriesTable == nil)
    @autoreleasepool {
        NSError *e = nil;
        // 耗性能非常严重，暂不解析
        //_entriesTable = [[MKDSCDylibInfos alloc] initWithParent:self error:&e];
        if (_entriesTable == nil)
            MK_PUSH_UNDERLYING_WARNING(stringTable, e, @"Could not load entries table.");
    }
    
    return _entriesTable;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return _size; }

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_address_t)nodeAddress:(MKNodeAddressType)type
{
    switch (type) {
        case MKNodeContextAddress:
            return _contextAddress;
        case MKNodeVMAddress:
            return _vmAddress;
        default:
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Unsupported node address type." userInfo:nil];
    }
}

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    MKNodeFieldBuilder *symHeader = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(header) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCLocalSymbolsHeader.class]]
    ];
    symHeader.description = @"LocalSymbolHeader";
    symHeader.options = MKNodeFieldOptionDisplayAsDetail | MKNodeFieldOptionMergeWithParent;
    
    MKNodeFieldBuilder *symTable = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(symbolTable) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCSymbolTable.class]]
    ];
    symTable.description = @"SymbolTable";
    symTable.options = MKNodeFieldOptionDisplayAsChild | MKNodeFieldOptionDisplayContainerContentsAsChild;
    
    MKNodeFieldBuilder *strTable = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(stringTable) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCSymbolTable.class]]
    ];
    strTable.description = @"StringTable";
    strTable.options = MKNodeFieldOptionDisplayAsChild | MKNodeFieldOptionDisplayContainerContentsAsChild;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        symHeader.build,
        symTable.build,
        strTable.build,
        [MKNodeField nodeFieldWithProperty:MK_PROPERTY(entriesTable) description:@"Entries Table"],
    ]];
}

- (NSString *)description {
    return @"LocalSymbols";
}

@end
