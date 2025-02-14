//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKStringTable.m
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

#import "MKStringTable.h"
#import "MKInternal.h"
#import "MKMachO.h"
#import "MKLCSymtab.h"
#import "MKCString.h"
#import "MKSegment.h"
#import "MKMachO+Segments.h"

//----------------------------------------------------------------------------//
@implementation MKStringTable

@synthesize strings = _strings;

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithSize:(mk_vm_size_t)size offset:(mk_vm_offset_t)offset inImage:(MKMachOImage*)image error:(NSError**)error
{
    self = [super initWithSize:size offset:offset inImage:image error:error];
    if (self == nil) return nil;
    
    // A size of 0 is valid; but we don't need to do anything else.
    // TODO - What if the address/offset is 0?  Is that an error?  Does it
    // occur in valid Mach-O images?
    if (self.nodeSize == 0) {
        // Still need to assign a value to the strings dictionary.
        _strings = @{};
        return self;
    }
    
    // Load Strings
    {
        NSMutableDictionary<NSNumber*, MKCString*> *strings = [NSMutableDictionary new];
        mk_vm_offset_t sym_off = 0;
        BOOL isFromSharedCache = image.isFromSharedCache;
        __block vm_address_t strTabAddr = 0;
        /*
         dyld_shared_cache中的镜像共享string table，非常耗性能，不解析
         如果解析string table，symbol tab解析也会更耗性能
         从dyld_shared_cache中提取出来的二进制，提取了完整的string table，也不解析
         */
        if (false && isFromSharedCache) {
            MKSegment *linkEdit = [[[image segmentsWithName:@(SEG_LINKEDIT)] firstObject] value];
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:offset length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                strTabAddr = address;
            }];
        }
        
        if (isFromSharedCache && strTabAddr == 0) {
            return self;
        }
        
        // Cast to mk_vm_size_t is safe; nodeSize can't be larger than UINT32_MAX.
        while ((mk_vm_size_t)sym_off < self.nodeSize)
        {
            NSError *stringError = nil;
            MKCString *string = NULL;
            if (isFromSharedCache) {
                const char *ptr = (void *)(strTabAddr + sym_off);
                NSString *str = [NSString stringWithUTF8String:ptr];
                string = [[MKCString alloc] initWithOffset:offset parent:self string:str];
            } else {
                string = [[MKCString alloc] initWithOffset:sym_off fromParent:self error:&stringError];
            }
            
            if (string == nil) {
                MK_PUSH_WARNING_WITH_ERROR(strings, MK_EINTERNAL_ERROR, stringError, @"Could not parse string at offset [%" MK_VM_PRIuOFFSET "].", sym_off);
                break;
            }
            
            [strings setObject:string forKey:@(sym_off)];
            
            // SAFE - All string nodes must be within the size of this node.
            sym_off += string.nodeSize ?: 1;
        }
        
        _strings = strings;
    }
    
    return self;
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithImage:(MKMachOImage*)image error:(NSError**)error;
{
    NSParameterAssert(image != nil);
    
    // Find LC_SYMTAB
    MKLCSymtab *symtabLoadCommand = nil;
    {
        NSArray *commands = [image loadCommandsOfType:LC_SYMTAB];
        if (commands.count > 1)
            MK_PUSH_WARNING(nil, MK_EINVALID_DATA, @"Image contains multiple LC_SYMTAB load commands.  Ignoring %@.", commands.lastObject);
        
        if (commands.count == 0) {
            // TODO - Is this really an error?
            MK_ERROR_OUT = [NSError mk_errorWithDomain:MKErrorDomain code:MK_ENOT_FOUND description:@"Image does not contain a LC_SYMTAB load command."];
            return nil;
        }
        
        symtabLoadCommand = commands.firstObject;
    }
    
    return [self initWithSize:symtabLoadCommand.strsize offset:symtabLoadCommand.stroff inImage:image error:error];
}

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithParent:(MKNode*)parent error:(NSError**)error
{ return [self initWithImage:parent.macho error:error]; }

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  MKPointer
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (MKResult*)childNodeOccupyingVMAddress:(mk_vm_address_t)address targetClass:(Class)targetClass
{
    MKResult *child = [MKBackedNode childNodeOccupyingVMAddress:address targetClass:targetClass inSortedArray:(NSArray *)self.strings];
    if (child.value)
        return child;
    
    return [super childNodeOccupyingVMAddress:address targetClass:targetClass];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    MKNodeFieldBuilder *strings = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(strings)
        type:[MKNodeFieldTypeCollection typeWithCollectionType:[MKNodeFieldTypeNode typeWithNodeType:MKCString.class]]
    ];
    strings.description = @"Strings";
    strings.options = MKNodeFieldOptionDisplayAsDetail | MKNodeFieldOptionMergeContainerContents;
    
    if (self.macho.isImageInSharedCache) {
        return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        ]];
    }
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        strings.build
    ]];
}

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  NSObject
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (NSString*)description
{ return @"String Table"; }

@end
