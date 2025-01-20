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

void writeSegment(struct segment_command_64 *seg, int fd, uint64_t slide, uint64_t offset, uint64_t base_offset);

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
    uint64_t offset = sizeof(struct mach_header_64);
    
    NSLog(@"写入数据 header");
    write(fd, header, offset);
    
    uint64_t slide = 0;
    uint64_t text_fileoff = 0;
    for (int i = 0; i < header->ncmds; ++i) {
        struct load_command *lc = (void *)(base + offset);
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *segment = (void *)lc;
            if (strcmp(segment->segname, SEG_TEXT) == 0) {
                text_fileoff = segment->fileoff;
                slide = (uint64_t)header - segment->vmaddr;
            }
            writeSegment(segment, fd, slide, offset, text_fileoff);
        } else {
            lseek(fd, offset, SEEK_SET);
            write(fd, lc, lc->cmdsize);
        }
        
        offset += lc->cmdsize;
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

void writeSegment(struct segment_command_64 *seg, int fd, uint64_t slide, uint64_t offset, uint64_t base_offset) {
    static uint64_t last_data_addr = 0;
    
    struct segment_command_64 tmp_seg = *seg;
    tmp_seg.fileoff -= base_offset;
    
    // 将segment_command_64信息写入文件
    uint64_t seg_size = sizeof(tmp_seg);
    NSLog(@"写入数据 seg %s, offset %d", seg->segname, offset);
    lseek(fd, offset, SEEK_SET);
    write(fd, &tmp_seg, seg_size);
    offset += seg_size;
    
    uint32_t nsects = seg->nsects;
    char *section_start = (char *)seg + sizeof(struct segment_command_64);
    for (uint32_t i = 0; i < nsects; i++) {
        struct section_64 *sec = (void *)section_start;
        uint64_t sec_size = sizeof(struct section_64);
        
        // 将section_64信息写入文件
        struct section_64 tmp_sec = *sec;
        tmp_sec.offset -= base_offset;
        NSLog(@"写入数据 sec %s.%s, offset %d", sec->segname, sec->sectname, offset);
        lseek(fd, offset, SEEK_SET);
        write(fd, &tmp_sec, sec_size);
        offset += sec_size;
        
        // 将section数据写入文件
        int64_t data_off = sec->offset - base_offset;
        if (data_off > last_data_addr) {
            last_data_addr = slide + sec->addr;
            void *sec_data = (void *)last_data_addr;
            NSLog(@"写入数据 data %s, offset %d", sec->sectname, data_off);
            lseek(fd, data_off, SEEK_SET);
            write(fd, sec_data, sec->size);
        }
        
        section_start += sec_size;
    }
}
