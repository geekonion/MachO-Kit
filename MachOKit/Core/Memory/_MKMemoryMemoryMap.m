//
//  _MKMemoryMemoryMap.m
//  MachOKit
//
//  Created by bangcle on 2025/1/22.
//  Copyright © 2025 DeVaukz. All rights reserved.
//

#import "_MKMemoryMemoryMap.h"

@implementation _MKMemoryMemoryMap {
    uint64_t _addr;
    uint64_t _fileoff;
    uint64_t _size;
    NSData *_data;
}
- (instancetype)initWithAddress:(uint64_t)addr fileoff:(uint64_t)fileoff size:(uint64_t)size
{
    self = [super init];
    if (self == nil) return nil;
    
    _addr = addr;
    _fileoff = fileoff;
    _size = size;
    
    return self;
}

- (void)remapBytesAtOffset:(mk_vm_offset_t)offset fromAddress:(mk_vm_address_t)contextAddress length:(mk_vm_size_t)length requireFull:(BOOL)requireFull withHandler:(void (^)(vm_address_t, vm_size_t, NSError * _Nullable))handler {
//    NSLog(@"---> %p %p %llu %p %llu %llu", _addr, _fileoff, _fileoff, _size, offset, contextAddress);
    handler((uint64_t)_addr + (contextAddress - _fileoff), length, nil);
}

@end
