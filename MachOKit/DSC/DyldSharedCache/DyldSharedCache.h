// 来自https://github.com/opa334/ChOma

#ifndef DYLD_SHARED_CACHE_H
#define DYLD_SHARED_CACHE_H

#include <MachOKit/dyld_cache_format.h>
#include <stddef.h>
#include <stdbool.h>
#include <uuid/uuid.h>
#include <mach/vm_prot.h>

typedef struct MachO MachO;
typedef struct Fat Fat;

#define UUID_NULL (uuid_t){0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

typedef struct DyldSharedCacheFile {
	char *filepath;
    uint64_t filesize;
	int fd;
	struct dyld_cache_header header;
} DyldSharedCacheFile;

typedef struct DyldSharedCacheMapping {
	uint64_t vmaddr;
	uint64_t fileoff;
	void *ptr;
	uint64_t size;
	struct DyldSharedCacheFile *file;
    vm_prot_t maxProt;
    vm_prot_t initProt;
	void *slideInfoPtr;
	uint64_t slideInfoSize;
	uint64_t flags;
} DyldSharedCacheMapping;

typedef struct DyldSharedCacheImage {
	uint64_t address;
	uint64_t size;
    uint64_t endAddr;
	uint64_t index;
	uuid_t uuid;
	char *path;
	uint32_t nlistStartIndex;
	uint32_t nlistCount;
	Fat *fat;
} DyldSharedCacheImage;

typedef struct DyldSharedCache {
	unsigned fileCount;
	DyldSharedCacheFile **files;

	struct {
		unsigned index;
		void *nlist;
		uint32_t nlistCount;
		char *strings;
		uint32_t stringsSize;
	} symbolFile;

	unsigned mappingCount;
	DyldSharedCacheMapping *mappings;
	uint64_t baseAddress;
	uint32_t premapSlide;
    bool is32Bit;

	uint64_t containedImageCount;
	DyldSharedCacheImage *containedImages;
} DyldSharedCache;

/*
typedef struct DyldSharedCachePointer {
	uint64_t location;
	uint64_t target;

	bool authenticated;
	uint8_t key;
	uint16_t diversifier;
	bool hasAddressDiversity;
} DyldSharedCachePointer;
 */

DyldSharedCache *dsc_init_from_path_premapped(const char *path, uint32_t premapSlide, bool load_sym);
DyldSharedCache *dsc_init_from_path(const char *path, bool load_sym);
void dsc_enumerate_files(DyldSharedCache *sharedCache, void (^enumeratorBlock)(const char *filepath, size_t filesize, struct dyld_cache_header *header));

DyldSharedCacheMapping *dsc_lookup_mapping(DyldSharedCache *sharedCache, uint64_t vmaddr, uint64_t size);
void *dsc_find_buffer(DyldSharedCache *sharedCache, uint64_t vmaddr, uint64_t size, bool *needFree);

int dsc_read_from_vmaddr(DyldSharedCache *sharedCache, uint64_t vmaddr, size_t size, void *outBuf);

//void dsc_enumerate_images(DyldSharedCache *sharedCache, void (^enumeratorBlock)(const char *path, DyldSharedCacheImage *imageHandle, MachO *imageMachO, bool *stop));
//DyldSharedCacheImage *dsc_find_image_for_section_address(DyldSharedCache *sharedCache, uint64_t address);
DyldSharedCacheImage *dsc_lookup_image_by_address(DyldSharedCache *sharedCache, uint64_t address);
DyldSharedCacheImage *dsc_lookup_image_by_vmaddr(DyldSharedCache *sharedCache, uint64_t vmaddr);
DyldSharedCacheImage *dsc_lookup_image_by_path(DyldSharedCache *sharedCache, const char *path);
//MachO *dsc_lookup_macho_by_path(DyldSharedCache *sharedCache, const char *path, DyldSharedCacheImage **imageHandleOut);
//int dsc_enumerate_chained_fixups(DyldSharedCache *sharedCache, void (^enumeratorBlock)(DyldSharedCachePointer *pointer, bool *stop));

int dsc_image_enumerate_symbols(DyldSharedCache *sharedCache, DyldSharedCacheImage *image, void (^enumeratorBlock)(const char *name, uint8_t type, uint64_t vmaddr, bool *stop));
//int dsc_image_enumerate_patches(DyldSharedCache *sharedCache, DyldSharedCacheImage *image, void (^enumeratorBlock)(unsigned v, void *patchable_location, bool *stop));
//int dsc_image_enumerate_chained_fixups(DyldSharedCache *sharedCache, DyldSharedCacheImage *image, void (^enumeratorBlock)(DyldSharedCachePointer *pointer, bool *stop));

uint64_t dsc_get_base_address(DyldSharedCache *sharedCache);

void dsc_free(DyldSharedCache *sharedCache);

#endif
