//----------------------------------------------------------------------------//
//|
//|             MachOKit - A Lightweight Mach-O Parsing Library
//|             Binary.h
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

#import <Foundation/Foundation.h>

//----------------------------------------------------------------------------//
@interface Architecture : NSObject

- (instancetype)initWithURL:(NSURL*)url offset:(uint32_t)offset name:(NSString*)name;

@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) uint32_t offset;

@property (nonatomic, strong, readonly) NSDictionary *machHeader;
@property (nonatomic, strong, readonly) NSArray *loadCommands;
@property (nonatomic, strong, readonly) NSArray *dependentLibraries;
@property (nonatomic, strong, readonly) NSArray *rebaseCommands;
@property (nonatomic, strong, readonly) NSArray *bindCommands;
@property (nonatomic, strong, readonly) NSArray *weakBindCommands;
@property (nonatomic, strong, readonly) NSArray *lazybindCommands;
@property (nonatomic, strong, readonly) NSArray *fixupAddresses;
@property (nonatomic, strong, readonly) NSArray *bindings;
@property (nonatomic, strong, readonly) NSArray *weakBindings;
@property (nonatomic, strong, readonly) NSArray *lazyBindings;
@property (nonatomic, strong, readonly) NSArray *exports;
@property (nonatomic, strong, readonly) NSArray *functionStarts;
@property (nonatomic, strong, readonly) NSArray *dataInCodeEntries;
@property (nonatomic, strong, readonly) NSArray *bsdSymbols;
@property (nonatomic, strong, readonly) NSArray *darwinSymbols;
@property (nonatomic, strong, readonly) NSArray *indirectSymbols;
@property (nonatomic, strong, readonly) NSDictionary *objcInfo;

@end



//----------------------------------------------------------------------------//
@interface Binary : NSObject

+ (instancetype)binaryAtURL:(NSURL*)url;

- (instancetype)initWithURL:(NSURL*)url;

@property (nonatomic, strong, readonly) NSURL *url;

@property (nonatomic, strong, readonly) NSDictionary<NSString*, id> *fatHeader;
@property (nonatomic, strong, readonly) NSDictionary *fatHeader_verbose;
@property (nonatomic, strong, readonly) NSArray /*Architecture*/ *architectures;

@end
