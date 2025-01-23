//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             MKMachHeader64.m
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

#import "MKMachHeader64.h"
#import "MKInternal.h"
#import "DyldSharedCache.h"
#import "MKMachO.h"
#import "MKSegment.h"

void writeSegment(struct segment_command_64 *seg, int fd, uint64_t offset1, uint32_t *offset2_ptr, DyldSharedCache *dsc);

//----------------------------------------------------------------------------//
@implementation MKMachHeader64

//|++++++++++++++++++++++++++++++++++++|//
- (instancetype)initWithOffset:(mk_vm_offset_t)offset fromParent:(MKBackedNode*)parent error:(NSError**)error
{
    self = [super initWithOffset:offset fromParent:parent error:error];
    if (self == nil) return nil;
    
    struct mach_header_64 lc;
    NSError *memoryMapError = nil;
    
    if ([self.memoryMap copyBytesAtOffset:0 fromAddress:self.nodeContextAddress into:&lc length:sizeof(lc) requireFull:YES error:&memoryMapError] < sizeof(lc)) {
        MK_ERROR_OUT = [NSError mk_errorWithDomain:MKErrorDomain code:MK_EINTERNAL_ERROR underlyingError:memoryMapError description:@"Could not read header."];
        [self release]; return nil;
    }
    
    _reserved = MKSwapLValue32(lc.reserved, self.dataModel);
    
    return self;
}

- (instancetype)initWithHeader:(struct mach_header_64 *)header dataModel:(MKDataModel *)dataModel parent:(MKBackedNode *)parent
{
    if (self = [super initWithHeader:(struct mach_header *)header dataModel:dataModel parent:parent]) {
        _reserved = header->reserved;
    }
    
    return self;
}

- (void)extractTo:(NSString *)path {
    int mod = S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH;
    int fd = open(path.UTF8String, O_WRONLY | O_CREAT, mod);
    if (fd < 0) {
        NSLog(@"open failed %@ %s", path, strerror(errno));
        return;
    }
    
    const struct mach_header_64 *header = (void *)self.header;
    const char *base = (const char *)header;
    uint64_t offset1 = sizeof(struct mach_header_64);
    
    NSLog(@"写入数据 header");
    write(fd, header, offset1);
    
    MKMachOImage *macho = (MKMachOImage *)self.parent;
    DyldSharedCache *dsc = [macho dsc];
    MKSegment *linkEdit = [[[macho segmentsWithName:@(SEG_LINKEDIT)] firstObject] value];
    uint32_t offset2 = 0;
    for (int32_t i = 0; i < header->ncmds; ++i) {
        struct load_command *lc = (void *)(base + offset1);
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (void *)lc;
            if (strcmp(seg->segname, SEG_TEXT) == 0) {
                char *section_start = (char *)seg + sizeof(struct segment_command_64);
                struct section_64 *sec = (void *)section_start;
                offset2 = (uint32_t)(sec->offset - seg->fileoff);
            }
            writeSegment(seg, fd, offset1, &offset2, dsc);
        } else if (lc->cmd == LC_DYLD_INFO
                   || lc->cmd == LC_DYLD_INFO_ONLY) {
            struct dyld_info_command *seg = (void *)lc;
            struct dyld_info_command dic = *seg;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dic.rebase_off length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, dic.rebase_size);
            }];
            dic.rebase_off = offset2;
            offset2 += dic.rebase_size;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dic.bind_off length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, dic.bind_size);
            }];
            dic.bind_off = offset2;
            offset2 += dic.bind_size;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dic.weak_bind_off length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, dic.weak_bind_size);
            }];
            dic.weak_bind_off = offset2;
            offset2 += dic.weak_bind_size;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dic.lazy_bind_off length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, dic.lazy_bind_size);
            }];
            dic.lazy_bind_off = offset2;
            offset2 += dic.lazy_bind_size;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dic.export_off length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, dic.export_size);
            }];
            dic.export_off = offset2;
            offset2 += dic.export_size;
            
            lseek(fd, offset1, SEEK_SET);
            write(fd, &dic, lc->cmdsize);
        } else if (lc->cmd == LC_SYMTAB) {
            struct symtab_command *seg = (void *)lc;
            struct symtab_command sc = *seg;
            
            uint32_t sym_size = sc.stroff - sc.symoff;
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:sc.symoff length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, sym_size);
            }];
            sc.symoff = offset2;
            offset2 += sym_size;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:sc.stroff length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, sc.strsize);
            }];
            sc.stroff = offset2;
            offset2 += sc.strsize;
            
            lseek(fd, offset1, SEEK_SET);
            write(fd, &sc, lc->cmdsize);
        } else if (lc->cmd == LC_DYSYMTAB) {
            struct dysymtab_command *seg = (void *)lc;
            struct dysymtab_command dc = *seg;
            if (dc.tocoff || dc.modtaboff || dc.extreloff) {
                NSAssert(false, @"off need handle");
            }
            
            uint32_t isyms_size = dc.nindirectsyms * 4;
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:dc.indirectsymoff length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, isyms_size);
            }];
            dc.indirectsymoff = offset2;
            offset2 += isyms_size;
            
            lseek(fd, offset1, SEEK_SET);
            write(fd, &dc, lc->cmdsize);
        } else if (lc->cmd == LC_FUNCTION_STARTS
                   || lc->cmd == LC_DATA_IN_CODE
                   || lc->cmd == LC_CODE_SIGNATURE) {
            struct linkedit_data_command *seg = (void *)lc;
            struct linkedit_data_command ldc = *seg;
            
            [linkEdit.memoryMap remapBytesAtOffset:0 fromAddress:ldc.dataoff length:0 requireFull:YES withHandler:^(vm_address_t address, vm_size_t length, NSError * _Nullable error) {
                
                lseek(fd, offset2, SEEK_SET);
                write(fd, (void *)address, ldc.datasize);
            }];
            ldc.dataoff = offset2;
            offset2 += ldc.datasize;
            
            lseek(fd, offset1, SEEK_SET);
            write(fd, &ldc, lc->cmdsize);
        } else {
            lseek(fd, offset1, SEEK_SET);
            write(fd, lc, lc->cmdsize);
        }
        
        offset1 += lc->cmdsize;
    }
}


//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  Mach-O Header Values
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

@dynamic magic;
@dynamic cputype;
@dynamic cpusubtype;
@dynamic filetype;
@dynamic ncmds;
@dynamic sizeofcmds;
@dynamic flags;
@synthesize reserved = _reserved;

//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//
#pragma mark -  MKNode
//◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦//

//|++++++++++++++++++++++++++++++++++++|//
- (mk_vm_size_t)nodeSize
{ return sizeof(struct mach_header_64); }

//|++++++++++++++++++++++++++++++++++++|//
- (MKNodeDescription*)layout
{
    __unused struct mach_header_64 mh;
    
    MKNodeFieldBuilder *reserved = [MKNodeFieldBuilder
        builderWithProperty:MK_PROPERTY(reserved)
        type:MKNodeFieldTypeUnsignedDoubleWord.sharedInstance
        offset:offsetof(typeof(mh), reserved)
    ];
    reserved.description = @"Reserved";
    reserved.options = MKNodeFieldOptionDisplayAsDetail;
    
    return [MKNodeDescription nodeDescriptionWithParentDescription:super.layout fields:@[
        reserved.build
    ]];
}

- (NSString *)description {
    return @"Mach64 Header";
}

@end

void writeSegment(struct segment_command_64 *seg, int fd, uint64_t offset1, uint32_t *offset2_ptr, DyldSharedCache *dsc) {
    uint32_t offset2 = *offset2_ptr;
    struct segment_command_64 tmp_seg = *seg;
    const char *segname = seg->segname;
    BOOL isSegText = strcmp(segname, SEG_TEXT) == 0;
    if (isSegText) {
        tmp_seg.fileoff = 0;
    } else {
        tmp_seg.fileoff = offset2;
    }
    
    // 将segment_command_64信息写入文件
    uint64_t seg_size = sizeof(tmp_seg);
    NSLog(@"写入数据 seg %s, offset %llu", seg->segname, offset1);
    lseek(fd, offset1, SEEK_SET);
    write(fd, &tmp_seg, seg_size);
    offset1 += seg_size;
    
    uint32_t nsects = seg->nsects;
    char *section_start = (char *)seg + sizeof(struct segment_command_64);
    for (uint32_t i = 0; i < nsects; i++) {
        struct section_64 *sec = (void *)section_start;
        uint64_t tmp_size = sizeof(struct section_64);
        
        // 将section_64信息写入文件
        struct section_64 tmp_sec = *sec;
        tmp_sec.offset = offset2;
        NSLog(@"写入数据 sec %s.%s, offset %llu", sec->segname, sec->sectname, offset1);
        lseek(fd, offset1, SEEK_SET);
        write(fd, &tmp_sec, tmp_size);
        offset1 += tmp_size;
        
        // 将section数据写入文件
        bool needFree = false;
        void *sec_data = dsc_find_buffer(dsc, sec->addr, sec->size, &needFree);
        NSLog(@"写入数据 data %s, offset %u", sec->sectname, offset2);
        lseek(fd, offset2, SEEK_SET);
        write(fd, sec_data, sec->size);
        
        section_start += tmp_size;
        offset2 += sec->size;
    }
    
    if (nsects == 0) {
        if (strcmp(segname, "__OBJC_RO") == 0
            || strcmp(segname, "__OBJC_RW") == 0) {
            // 将segment数据整体写入文件
            bool needFree = false;
            void *seg_data = dsc_find_buffer(dsc, seg->vmaddr, seg->filesize, &needFree);
            NSLog(@"写入数据 data %s, offset %u", segname, offset2);
            lseek(fd, offset2, SEEK_SET);
            write(fd, seg_data, seg->filesize);
            
            //offset2 += seg->filesize;
        }
    }
    
    if (isSegText) {
        *offset2_ptr = (uint32_t)seg->filesize;
    } else {
        *offset2_ptr = *offset2_ptr + (uint32_t)seg->filesize;
    }
}
