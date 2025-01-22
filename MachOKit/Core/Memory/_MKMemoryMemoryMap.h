//
//  _MKMemoryMemoryMap.h
//  MachOKit
//
//  Created by bangcle on 2025/1/22.
//  Copyright © 2025 DeVaukz. All rights reserved.
//

#import <MachOKit/MachOKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface _MKMemoryMemoryMap : MKMemoryMap
- (instancetype)initWithAddress:(uint64_t)addr fileoff:(uint64_t)fileoff size:(uint64_t)size;
@end

NS_ASSUME_NONNULL_END
