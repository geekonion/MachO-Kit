//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKSharedCache.m
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

#import "MKSharedCache.h"
#import "NSError+MK.h"
#import "MKDSCHeader.h"
#import "MKDSCMappingInfo.h"
#import "MKDSCMapping.h"
#import "MKDSCImagesInfo.h"
#import "MKDSCLocalSymbols.h"
#import "MKDSCSlideInfo.h"
#import "MKDSCImage.h"

#include "dyld_cache_format.h"
#include <objc/runtime.h>
#import "DyldSharedCache.h"

#if __has_include(<mach/shared_region.h>)
#include <mach/shared_region.h>
#else
// shared_region.h is not available on embedded.
#define SHARED_REGION_BASE_I386			0x90000000ULL
#define SHARED_REGION_BASE_X86_64		0x00007FFF70000000ULL
#define SHARED_REGION_BASE_ARM64		0x180000000ULL
#define SHARED_REGION_BASE_ARM			0x20000000ULL
#endif

@interface MKSharedCache () {
    DyldSharedCache *_dsc;
    BOOL _extracting;
    NSArray <MKDSCImage *> *_sortedImages;
}

@end
//----------------------------------------------------------------------------//
@implementation MKSharedCache

- (instancetype)initWithFlags:(MKSharedCacheFlags)flags url:(NSURL *)url {
    NSError *tmp = nil;
    self = [super initWithParent:nil error:&tmp];
    if (self == nil) return nil;
    
    NSError *localError = nil;
    mk_vm_address_t sharedRegionBase;
    mk_vm_address_t contextAddress = 0;
    bool load_sym = true;
    _dsc = dsc_init_from_path(url.path.UTF8String, load_sym);
    if (!_dsc) {
        return nil;
    }
    DyldSharedCacheFile *main = _dsc->files[0];
    // Read the Magic
    {
        struct dyld_cache_header *header = &main->header;
        char *magic = header->magic;
        // First 4 bytes must == 'dyld'
        if (strncmp(&magic[0], "dyld", 4)) {
            return nil;
        }
        
        // TODO - Support parsing shared cache v0.
        if (strncmp(&magic[5], "v1", 2)) {
            return nil;
        }
        
        _version = 1;
        
        // Architecture
        if (strcmp(magic, "dyld_v1    i386") == 0) {
            _dataModel = [MKDarwinIntel32DataModel sharedDataModel];
            _cpuType = CPU_TYPE_I386;
            _cpuSubtype = CPU_SUBTYPE_I386_ALL;
            sharedRegionBase = SHARED_REGION_BASE_I386;
        } else if (strcmp(magic, "dyld_v1 x86_64h") == 0) {
            _dataModel = [MKDarwinIntel64DataModel sharedDataModel];
            _cpuType = CPU_TYPE_X86_64;
            _cpuSubtype = CPU_SUBTYPE_X86_64_H;
            sharedRegionBase = SHARED_REGION_BASE_X86_64;
        } else if (strcmp(magic, "dyld_v1  x86_64") == 0) {
            _dataModel = [MKDarwinIntel64DataModel sharedDataModel];
            _cpuType = CPU_TYPE_X86_64;
            _cpuSubtype = CPU_SUBTYPE_X86_64_ALL;
            sharedRegionBase = SHARED_REGION_BASE_X86_64;
        } else if (strcmp(magic, "dyld_v1  arm64e") == 0) {
            _dataModel = [MKDarwinARM64DataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM64;
            _cpuSubtype = CPU_SUBTYPE_ARM64E;
            sharedRegionBase = SHARED_REGION_BASE_ARM64;
        } else if (strcmp(magic, "dyld_v1   arm64") == 0) {
            _dataModel = [MKDarwinARM64DataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM64;
            _cpuSubtype = CPU_SUBTYPE_ARM64_ALL;
            sharedRegionBase = SHARED_REGION_BASE_ARM64;
        } else if (strcmp(magic, "dyld_v1  armv7s") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_V7S;
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else if (strcmp(magic, "dyld_v1  armv7k") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_V7K;
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else if (strcmp(magic, "dyld_v1  armv7f") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_V7F;
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else if (strcmp(magic, "dyld_v1   armv7") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_V7;
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else if (strcmp(magic, "dyld_v1   armv6") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_V6;
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else if (strcmp(magic, "dyld_v1   armv5") == 0) {
            _dataModel = [MKDarwinARMDataModel sharedDataModel];
            _cpuType = CPU_TYPE_ARM;
            _cpuSubtype = CPU_SUBTYPE_ARM_ALL; //TODO - Find a better value
            sharedRegionBase = SHARED_REGION_BASE_ARM;
        } else {
            return nil;
        }
    }
    
    // Can now parse the full header
    _header = [[MKDSCHeader alloc] initWithOffset:0 fromParent:self dsc:_dsc error:&localError];
    if (_header == nil) {
        return nil;
    }
    
    // Handle flags
    {
        // If neither the MKSharedCacheFromSourceFile or MKSharedCacheFromVM
        // were specified, attempt to detect whether we are parsing a
        // dyld_shared_cache_[arch] from disk.  The best heuristic is a
        // contextAddress of 0.
        if (!(flags & MKSharedCacheFromSourceFile) && !(flags & MKSharedCacheFromVM)) {
            if (contextAddress == 0)
                flags |= MKSharedCacheFromSourceFile;
            else
                flags |= MKSharedCacheFromVM;
        }
        
        _flags = flags;
    }
    
    // Load mappings
    {
        uint32_t nmapping = _dsc->mappingCount;
        NSMutableArray<MKDSCMapping*> *mappings = [[NSMutableArray alloc] initWithCapacity:nmapping];
        
        for (int32_t i = 0; i < nmapping; i++) {
            DyldSharedCacheMapping *dscmapping = &_dsc->mappings[i];
            NSError *e = nil;
            
            MKDSCMapping *mapping = [[MKDSCMapping alloc] initWithDSCMapping:dscmapping parent:self error:&e];
            
            [mappings addObject:mapping];
        }
        
        _mappings = mappings;
    }
    
    // Load images
    {
        uint64_t nimage = _dsc->containedImageCount;
        NSMutableArray<MKDSCImage*> *images = [[NSMutableArray alloc] initWithCapacity:nimage];
        
        for (int64_t i = 0; i < nimage; i++) {
            DyldSharedCacheImage *dsimage = &_dsc->containedImages[i];
            NSError *e = nil;
            MKDSCImage *image = [[MKDSCImage alloc] initWithDSC:_dsc image:dsimage parent:self error:&e];
            
            [images addObject:image];
        }
        
        _images = images;
    }
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithParent:(MKBackedNode*)parent error:(NSError**)error
{
    self = [self initWithParent:parent error:error];
    if (!self) return nil;
    
    _parent = parent;
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (void)dealloc
{
    dsc_free(_dsc);
    _dsc = NULL;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - Retrieving the Initialization Context
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize dataModel = _dataModel;

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - Getting Shared Cache Metadata
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (BOOL)isSourceFile
{ return !!(_flags & MKSharedCacheFromSourceFile); }

@synthesize slide = _slide;

@synthesize version = _version;
@synthesize cpuType = _cpuType;
@synthesize cpuSubtype = _cpuSubtype;

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - Header and Mappings
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@synthesize header = _header;
@synthesize mappingInfos = _mappingInfos;
@synthesize mappings = _mappings;

- (MKDSCMapping *)findMapping:(uint64_t)vmaddr {
    for (MKDSCMapping *mapping in _mappings) {
        uint64_t mappingEndAddr = mapping.vmAddress + mapping.vmSize;
        
        if (vmaddr >= mapping.vmAddress && (vmaddr < mappingEndAddr)) {
            return mapping;
        }
    }
    return NULL;
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark - MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (MKMemoryMap*)memoryMap
{ return _memoryMap; }

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return 0; }

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
    MKNodeFieldBuilder *header = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(header) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCHeader.class]]
    ];
    header.description = @"Header";
    header.options = MKNodeFieldOptionDisplayAsDetail | MKNodeFieldOptionMergeWithParent;
    
    MKNodeFieldBuilder *mappings = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(mappings) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCMapping.class]]
    ];
    mappings.description = [NSString stringWithFormat:@"Mappings (%lu)", self.mappings.count];
    mappings.options = MKNodeFieldOptionDisplayAsChild | MKNodeFieldOptionDisplayContainerContentsAsChild;
    
    MKNodeFieldBuilder *images = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(images) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCImage.class]]
    ];
    images.description = [NSString stringWithFormat:@"Images (%lu)", self.images.count];
    images.options = MKNodeFieldOptionDisplayAsChild | MKNodeFieldOptionDisplayContainerContentsAsChild;
    
//    MKNodeFieldBuilder *slideInfo = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(slideInfo) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCSlideInfo.class]]
//    ];
//    slideInfo.description = @"SlideInfo";
//    slideInfo.options = MKNodeFieldOptionDisplayAsChild;
    
    MKNodeFieldBuilder *symbols = [MKNodeFieldBuilder builderWithProperty:MK_PROPERTY(localSymbols) type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKDSCLocalSymbols.class]]
    ];
    symbols.description = @"Symbols";
    symbols.options = MKNodeFieldOptionDisplayAsChild;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        header.build,
        mappings.build,
        images.build,
//        slideInfo.build,
        symbols.build
    ]];
}

- (const char *)architecture_description {
    const char *description = "";
    
    switch (_cpuType) {
        case CPU_TYPE_ARM: {
            switch (_cpuSubtype) {
                case CPU_SUBTYPE_ARM_V7K:
                    description = "armv7k";
                    break;
                case CPU_SUBTYPE_ARM_V7S:
                    description = "armv7s";
                    break;
                case CPU_SUBTYPE_ARM_V7F:
                    description = "armv7f";
                    break;
                case CPU_SUBTYPE_ARM_V7:
                    description = "armv7";
                    break;
                case CPU_SUBTYPE_ARM_V6:
                    description = "armv6";
                    break;
                default:
                    description = "ARM";
                    break;
            }
            break;
        }
        case CPU_TYPE_ARM64: {
            switch (_cpuSubtype) {
                case CPU_SUBTYPE_ARM64E:
                    description = "arm64e";
                    break;
                default:
                    description = "arm64";
                    break;
            }
            break;
        }
        case CPU_TYPE_ARM64_32: {
            description = "arm64_32";
            break;
        }
        default:
            description = "Unknown";
            break;
    }
    
    return description;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DSC (%s)", [self architecture_description]];
}

- (void)extractTo:(NSString *)path {
    if (_extracting) {
        return;
    }
    
    _extracting = YES;
    if (![[path lastPathComponent] isEqualToString:@"images"]) {
        path = [path stringByAppendingPathComponent:@"images"];
        NSFileManager *fileMng = [NSFileManager defaultManager];
        if (![fileMng fileExistsAtPath:path]) {
            NSError *error = nil;
            [fileMng createDirectoryAtPath:path withIntermediateDirectories:NO attributes:@{} error:&error];
            if (error) {
                return;
            }
        }
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (MKDSCImage *image in self.images) {
            [image extractTo:path];
        }
        self->_extracting = NO;
    });
}

- (BOOL)extractable {
    return YES;
}

- (NSArray <MKDSCImage *> *)sortedImages {
    if (_sortedImages) {
        return _sortedImages;
    }
    _sortedImages = [self.images sortedArrayUsingComparator:^NSComparisonResult(MKDSCImage * _Nonnull image1, MKDSCImage *  _Nonnull image2) {
        return [image1.name compare:image2.name options:NSCaseInsensitiveSearch];
    }];
    
    return _sortedImages;
}

@end
