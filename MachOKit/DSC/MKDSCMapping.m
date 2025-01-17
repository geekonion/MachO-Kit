//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKDSCMapping.m
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

#import "MKDSCMapping.h"
#import "NSError+MK.h"
#import "MKDSCMappingInfo.h"
#import "MKSharedCache.h"

@interface MKDSCMapping () {
    DyldSharedCacheMapping *_mapping;
}
    
@end
//----------------------------------------------------------------------------//
@implementation MKDSCMapping

@synthesize vmAddress = _vmAddress;
@synthesize vmSize = _vmSize;
@synthesize fileOffset = _fileOffset;
@synthesize maximumProtection = _maximumProtection;
@synthesize initialProtection = _initialProtection;

//|++++++++++++++++++++++++++++++++++++|//
- (nullable instancetype)initWithDSCMapping:(DyldSharedCacheMapping *)mapping parent:(MKNode *)parent error:(NSError**)error
{
    self = [super initWithParent:parent error:error];
    if (self == nil) return nil;
    
    _vmAddress = mapping->vmaddr;
    _vmSize = mapping->size;
    _fileOffset = mapping->fileoff;
    _maximumProtection = mapping->maxProt;
    _initialProtection = mapping->initProt;
    
    _mapping = mapping;
    
    return self;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return _vmSize; }

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_address_t)nodeAddress:(MKNodeAddressType)type
{
    switch (type) {
        case MKNodeContextAddress:
            return _contextAddress;
            break;
        case MKNodeVMAddress:
            return _vmAddress;
            break;
        default:
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Unsupported node address type." userInfo:nil];
    }
}

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(fileOffset) description:@"File offset" format:MKNodeFieldFormatOffset],
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(vmAddress) description:@"VM Address" format:MKNodeFieldFormatAddress],
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(vmSize) description:@"VM Size" format:MKNodeFieldFormatSize],
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(maximumProtection) description:@"Maximum VM Protection" format:MKNodeFieldFormatHexCompact],
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(initialProtection) description:@"Initial VM Protection" format:MKNodeFieldFormatHexCompact]
    ]];
}

- (NSString *)description {
    const char *path = _mapping->file->filepath;
    
    return [NSString stringWithUTF8String:path].lastPathComponent;
}

@end
