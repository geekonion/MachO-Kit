//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKDSCImage.m
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

#import "MKDSCImage.h"
#import "NSError+MK.h"
#import "MKMachO.h"
#import "MKSharedCache.h"
#import "MKDSCMapping.h"
#import "_MKFileMemoryMap.h"

#include "dyld_cache_format.h"

//----------------------------------------------------------------------------//
@implementation MKDSCImage

//|++++++++++++++++++++++++++++++++++++|//
- (nullable instancetype)initWithDSC:(DyldSharedCache *)dsc image:(DyldSharedCacheImage *)image parent:(MKBackedNode *)parent error:(NSError**)error
{
    NSParameterAssert(parent.dataModel);
    
    self = [super initWithParent:parent error:error];
    if (self == nil || *error) return nil;
    
    _address = image->address;
    _path = [NSString stringWithUTF8String:image->path];
    _name = _path.lastPathComponent;
    _uuid = [[NSUUID alloc] initWithUUIDBytes:image->uuid];
    _textSegmentSize = image->size;
    
    bool needFree = false;
    void *buffer = dsc_find_buffer(dsc, image->address, image->size, &needFree);
    if (!buffer) {
        return self;
    }
    _macho = [[MKMachOImage alloc] initWithDSC:dsc name:image->path flags:0 address:buffer size:image->size];
    if (needFree) {
        free(buffer);
    }
    
    return self;
}

//----------------------------------------------------------------------------//
#pragma mark -  MKNode
//----------------------------------------------------------------------------//

//|++++++++++++++++++++++++++++++++++++|//
- (mach_vm_size_t)nodeSize
{ return sizeof(struct dyld_cache_image_info); }

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    MKNodeFieldBuilder *macho = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(macho) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKMachOImage.class]]
    ];
    macho.description = @"MachO";
    macho.options = MKNodeFieldOptionDisplayAsChild | MKNodeFieldOptionDisplayContainerContentsAsChild;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(address) description:@"Image Start Address" format:MKNodeFieldFormatAddress],
        [MKFormattedNodeField fieldWithProperty:MK_PROPERTY(textSegmentSize) description:@"Text Segment Size" format:MKNodeFieldFormatSize],
        [MKNodeField nodeFieldWithProperty:MK_PROPERTY(uuid) description:@"UUID"],
//        [MKNodeField nodeFieldWithProperty:MK_PROPERTY(path) description:@"Image Path"],
        macho.build
    ]];
}

- (NSString *)description {
    if (_name.length) {
        return _name;
    }
    return @"unknown";
}

- (void)extractTo:(NSString *)path {
    [_macho extractTo:path];
}

- (BOOL)extractable {
    return YES;
}

@end
