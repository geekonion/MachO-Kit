//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKDSCStringTable.m
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

#import "MKDSCStringTable.h"
#import "NSError+MK.h"
#import "MKCString.h"
#import "MKDSCLocalSymbols.h"
#import "MKDSCLocalSymbolsHeader.h"
#import "DyldSharedCache.h"

//----------------------------------------------------------------------------//
@implementation MKDSCStringTable

@synthesize strings = _strings;

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithSize:(mk_vm_size_t)size offset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent error:(NSError**)error
{
    self = [super initWithOffset:offset fromParent:parent error:error];
    if (self == nil) return nil;
    
    // A size of 0 is valid; but we don't need to do anything else.
    if (size == 0) {
        // If we return early, 'strings' must be initialized in order to
        // fufill the non-null promise for the property.
        _strings = [[NSDictionary dictionary] retain];
        
        return self;
    }
    _nodeSize = size;
    // Read strings
    @autoreleasepool
    {
        NSMutableDictionary<NSNumber*, MKCString*> *strings = [[NSMutableDictionary alloc] init];
        mk_vm_offset_t offset = 0;
        MKDSCLocalSymbols *symbols = (id)self.parent;
        DyldSharedCache *dsc = symbols.dsc;
        const char *str_ptr = dsc->symbolFile.strings;
        while (offset < _nodeSize)
        {
            
            const char *ptr = str_ptr + offset;
            NSString *str = [NSString stringWithUTF8String:ptr];
            MKCString *string = [[MKCString alloc] initWithOffset:offset parent:self string:str];
            
            [strings setObject:string forKey:@(offset)];
            [string release];
            if (str.length == 0) {
                offset += 1;
            } else {
                offset += str.length;
            }
        }
        
        _strings = [strings copy];
        [strings release];
    }
    
    return self;
}

- (NSData *)data {
    MKDSCLocalSymbols *symbols = (id)self.parent;
    DyldSharedCache *dsc = symbols.dsc;
    const char *str_ptr = dsc->symbolFile.strings;
    
    return [NSData dataWithBytes:str_ptr length:dsc->symbolFile.stringsSize];
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent error:(NSError**)error
{
    MKDSCLocalSymbols *symbols = [parent nearestAncestorOfType:MKDSCLocalSymbols.class];
    NSParameterAssert(symbols);
    
    MKDSCLocalSymbolsHeader *symbolsInfo = symbols.header;
    NSParameterAssert(symbolsInfo);
    
    mk_vm_offset_t stringsOffset = symbolsInfo.stringsOffset;
    mk_vm_size_t stringsSize = symbolsInfo.stringsSize;
    
    // Verify that offset is in range of the strings table.
    if (offset < stringsOffset || offset > stringsOffset + stringsSize) {
        MK_ERROR_OUT = [NSError mk_errorWithDomain:MKErrorDomain code:MK_EOUT_OF_RANGE description:@"Offset (%" MK_VM_PRIiOFFSET ") not in range of the string table.", offset];
        [self release]; return nil;
    }
    
    return [self initWithSize:stringsSize offset:stringsOffset fromParent:symbols error:error];

}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithParent:(MKNode*)parent error:(NSError**)error
{
    MKDSCLocalSymbols *symbols = [parent nearestAncestorOfType:MKDSCLocalSymbols.class];
    NSParameterAssert(symbols);
    
    MKDSCLocalSymbolsHeader *symbolsInfo = symbols.header;
    NSParameterAssert(symbolsInfo);
    
    return [self initWithOffset:symbolsInfo.stringsOffset fromParent:symbols error:error];
}

//|++++++++++++++++++++++++++++++++++++|//
- (void)dealloc
{
    [_strings release];
    
    [super dealloc];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize nodeSize = _nodeSize;

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    MKNodeFieldBuilder *strings = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(strings) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKCString.class]]
    ];
    strings.description = @"Symbols";
    strings.options = MKNodeFieldOptionDisplayAsDetail | MKNodeFieldOptionMergeWithParent;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
    ]];
}

- (NSString *)description {
    return @"StringTable";
}

@end
