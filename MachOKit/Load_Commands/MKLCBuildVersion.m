//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKLCBuildVersion.m
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

#import "MKLCBuildVersion.h"
#import "MKInternal.h"
#import "MKMachO.h"

//----------------------------------------------------------------------------//
@implementation MKLCBuildVersion

@synthesize tools = _tools;
@synthesize platform = _platform;
@synthesize minos = _minos;
@synthesize sdk = _sdk;
@synthesize ntools = _ntools;

//|++++++++++++++++++++++++++++++++++++|//
+ (uint32_t)ID
{ return LC_BUILD_VERSION; }

//|++++++++++++++++++++++++++++++++++++|//
+ (uint32_t)canInstantiateWithLoadCommandID:(uint32_t)commandID
{
    if (self != MKLCBuildVersion.class)
        return 0;
    
    return commandID == [self ID] ? 10 : 0;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent error:(NSError**)error
{
    self = [super initWithOffset:offset fromParent:parent error:error];
    if (self == nil) return nil;
    
    struct build_version_command lc;
    if ([self.memoryMap copyBytesAtOffset:offset fromAddress:parent.nodeContextAddress into:&lc length:sizeof(lc) requireFull:YES error:error] < sizeof(lc))
    { return nil; }
 
    _platform = MKSwapLValue32(lc.platform, self.macho.dataModel);
    
    MKSwapLValue32(lc.minos, self.macho.dataModel);
    _minos = [[MKVersion alloc] initWithMachVersion:lc.minos];
    if (_minos == nil) { return nil; }
    
    MKSwapLValue32(lc.sdk, self.macho.dataModel);
    _sdk = [[MKVersion alloc] initWithMachVersion:lc.sdk];
    if (_sdk == nil) { return nil; }
    
    _ntools = MKSwapLValue32(lc.ntools, self.macho.dataModel);
    
    // Load the build tool versions
    {
        uint32_t toolCount = self.ntools;
        
        NSMutableArray<MKLCBuildToolVersion*> *tools = [[NSMutableArray alloc] initWithCapacity:toolCount];
        mach_vm_offset_t offset = sizeof(lc);
        mach_vm_offset_t oldOffset;
        
        while (toolCount--) {
        @autoreleasepool {
            NSError *toolError = nil;
            
            // It is safe to pass the mach_vm_offset_t offset as the offset
            // parameter because the offset can not grow beyond the node size,
            // which is capped at UINT32_MAX.  Any uint32_t can be acurately
            // represented by an mk_vm_offset_t.
            
            MKLCBuildToolVersion *tool = [[MKLCBuildToolVersion alloc] initWithOffset:offset fromParent:self error:&toolError];
            if (tool == nil) {
                // If we fail to instantiate an instance of the
                // MKLCBuildToolVersion it means we've walked off the end of
                // memory that can be mapped by our MKMemoryMap.
                MK_PUSH_UNDERLYING_WARNING(tools, toolError, @"Failed to instantiate build tool version at index " PRIi32 "", (self.ntools - toolCount));
                break;
            }
            
            oldOffset = offset;
            offset += tool.nodeSize;
            
            // We will attempt to load build tool versions that are (partially)
            // beyond the end of this load command (as specified by the load
            // command size).  Apple's tools don't appear to guard against this
            // either.
            
            if (oldOffset > offset) {
                // This should be impossible - we would fail to load the next
                // build tool version first.  But just to be safe...
                break;
            }
            
            [tools addObject:tool];
        }}
		
		_tools = tools;
    }
    
    return self;
}

- (instancetype)initWithLC:(struct load_command *)lc_ptr parent:(nonnull MKBackedNode *)parent
{
    self = [super initWithLC:lc_ptr parent:parent];
    if (self == nil) return nil;
    
    struct build_version_command *lc = (void *)lc_ptr;
    
    _platform = lc->platform;
    
    _minos = [[MKVersion alloc] initWithMachVersion:lc->minos];
    if (_minos == nil) { return nil; }
    
    _sdk = [[MKVersion alloc] initWithMachVersion:lc->sdk];
    if (_sdk == nil) { return nil; }
    
    _ntools = lc->ntools;
    
    // Load the build tool versions
    {
        uint32_t toolCount = self.ntools;
        
        NSMutableArray<MKLCBuildToolVersion*> *tools = [[NSMutableArray alloc] initWithCapacity:toolCount];
        mach_vm_offset_t offset = sizeof(*lc);
        mach_vm_offset_t oldOffset;
        
        while (toolCount--) {
            @autoreleasepool {
                NSError *toolError = nil;
                
                // It is safe to pass the mach_vm_offset_t offset as the offset
                // parameter because the offset can not grow beyond the node size,
                // which is capped at UINT32_MAX.  Any uint32_t can be acurately
                // represented by an mk_vm_offset_t.
                struct build_tool_version *btv_ptr = (struct build_tool_version *)((char *)lc + offset);
                MKLCBuildToolVersion *tool = [[MKLCBuildToolVersion alloc] initWithBTV:btv_ptr fromParent:self];
                if (tool == nil) {
                    // If we fail to instantiate an instance of the
                    // MKLCBuildToolVersion it means we've walked off the end of
                    // memory that can be mapped by our MKMemoryMap.
                    MK_PUSH_UNDERLYING_WARNING(tools, toolError, @"Failed to instantiate build tool version at index " PRIi32 "", (self.ntools - toolCount));
                    break;
                }
                
                oldOffset = offset;
                offset += tool.nodeSize;
                
                // We will attempt to load build tool versions that are (partially)
                // beyond the end of this load command (as specified by the load
                // command size).  Apple's tools don't appear to guard against this
                // either.
                
                if (oldOffset > offset) {
                    // This should be impossible - we would fail to load the next
                    // build tool version first.  But just to be safe...
                    break;
                }
                
                [tools addObject:tool];
            }}
        
        _tools = tools;
    }
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    __unused struct build_version_command bvc;
    
    MKNodeFieldBuilder *platform = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(platform)
        type:[MKNodeFieldTypeEnumeration enumerationWithUnderlyingType:MKNodeFieldTypeUnsignedDoubleWord.sharedInstance name:@"Build Version Platform" elements:@{
            @(PLATFORM_MACOS): @"PLATFORM_MACOS",
            @(PLATFORM_IOS): @"PLATFORM_IOS",
            @(PLATFORM_TVOS): @"PLATFORM_TVOS",
            @(PLATFORM_WATCHOS): @"PLATFORM_WATCHOS",
            @(PLATFORM_BRIDGEOS): @"PLATFORM_BRIDGEOS",
            @(PLATFORM_MACCATALYST): @"PLATFORM_MACCATALYST",
            @(PLATFORM_IOSSIMULATOR): @"PLATFORM_IOSSIMULATOR",
            @(PLATFORM_TVOSSIMULATOR): @"PLATFORM_TVOSSIMULATOR",
            @(PLATFORM_WATCHOSSIMULATOR): @"PLATFORM_WATCHOSSIMULATOR",
            @(PLATFORM_DRIVERKIT): @"PLATFORM_DRIVERKIT",
        }]
        offset:offsetof(struct build_version_command, platform)
        size:sizeof(bvc.platform)
    ];
    platform.description = @"Platform";
    platform.options = MKNodeFieldOptionDisplayAsDetail;
    
    MKNodeFieldBuilder *minos = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(minos)
        type:nil // TODO -
        offset:offsetof(typeof(bvc), minos)
        size:sizeof(bvc.minos)
    ];
    minos.description = @"Minimum OS Version";
    minos.formatter = nil;
    minos.options = MKNodeFieldOptionDisplayAsDetail;
    
    MKNodeFieldBuilder *sdk = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(sdk)
        type:nil // TODO -
        offset:offsetof(typeof(bvc), sdk)
        size:sizeof(bvc.sdk)
    ];
    sdk.description = @"SDK Version";
    sdk.formatter = nil;
    sdk.options = MKNodeFieldOptionDisplayAsDetail;
    
    MKNodeFieldBuilder *ntools = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(ntools)
        type:MKNodeFieldTypeUnsignedDoubleWord.sharedInstance
        offset:offsetof(typeof(bvc), ntools)
        size:sizeof(bvc.ntools)
    ];
    ntools.description = @"Number Of Tools";
    ntools.options = MKNodeFieldOptionDisplayAsDetail;
    
    MKNodeFieldBuilder *tools = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(tools)
        type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKLCBuildToolVersion.class]]
    ];
    tools.description = @"Build Tool Versions";
    tools.options = MKNodeFieldOptionDisplayAsDetail | MKNodeFieldOptionMergeWithParent;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        platform.build,
        minos.build,
        sdk.build,
        ntools.build,
        tools.build
    ]];
}

@end



//----------------------------------------------------------------------------//
@implementation MKLCBuildToolVersion

@synthesize tool = _tool;
@synthesize version = _version;

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent error:(NSError **)error
{
    self = [super initWithOffset:offset fromParent:parent error:error];
    if (self == nil) return self;
    
    struct build_tool_version btv;
    if ([self.memoryMap copyBytesAtOffset:offset fromAddress:parent.nodeContextAddress into:&btv length:sizeof(btv) requireFull:YES error:error] < sizeof(btv))
    { return nil; }
    
    _tool = MKSwapLValue32(btv.tool, self.macho.dataModel);
    _version = [[MKVersion alloc] initWithMachVersion:btv.version];
    
    return self;
}

- (instancetype)initWithBTV:(struct build_tool_version *)btv_ptr fromParent:(MKBackedNode*)parent
{
    self = [super initWithOffset:0 fromParent:parent error:nil];
    if (self == nil) return self;
    
    struct build_tool_version *btv = (void *)btv_ptr;
    
    _tool = btv->tool;
    _version = [[MKVersion alloc] initWithMachVersion:btv->version];
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return sizeof(struct build_tool_version); }

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    __unused struct build_tool_version btv;
    
    MKNodeFieldBuilder *tool = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(tool)
        type:[MKNodeFieldTypeEnumeration enumerationWithUnderlyingType:MKNodeFieldTypeUnsignedDoubleWord.sharedInstance name:@"Build Tool" elements:@{
            @(TOOL_CLANG): [NSString stringWithFormat:@"clang (%d)", TOOL_CLANG],
            @(TOOL_SWIFT): [NSString stringWithFormat:@"swift (%d)", TOOL_SWIFT],
            @(TOOL_LD): [NSString stringWithFormat:@"ld (%d)", TOOL_LD],
            @(TOOL_LLD): [NSString stringWithFormat:@"lld (%d)", TOOL_LLD],
        }]
        offset:offsetof(typeof(btv), tool)
        size:sizeof(btv.tool)
    ];
    tool.description = @"Tool";
    tool.options = MKNodeFieldOptionDisplayAsDetail;
    
    MKNodeFieldBuilder *version = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(version)
        type:MKNodeFieldTypeUnsignedDoubleWord.sharedInstance
        offset:offsetof(typeof(btv), version)
        size:sizeof(btv.version)
    ];
    version.description = @"Tool Version";
    version.options = MKNodeFieldOptionDisplayAsDetail;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        tool.build,
        version.build
    ]];
}

@end

