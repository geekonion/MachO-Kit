//
//  MKExtractProtocol.h
//  MachOKit
//
//  Created by bangcle on 2025/1/23.
//  Copyright © 2025 DeVaukz. All rights reserved.
//

#ifndef MKExtractable_h
#define MKExtractable_h

@protocol MKExtractable <NSObject>
- (BOOL)extractable;
- (void)extractTo:(NSString *)path;

@end
#endif /* MKExtractable_h */
