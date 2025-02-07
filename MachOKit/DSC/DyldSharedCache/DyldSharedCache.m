// 来自https://github.com/opa334/ChOma

#include "DyldSharedCache.h"
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <mach-o/nlist.h>
#include "Util.h"

DyldSharedCacheMapping *dsc_lookup_mapping(DyldSharedCache *sharedCache, uint64_t vmaddr, uint64_t size)
{
    int32_t count = (int32_t)sharedCache->mappingCount;
    for (int32_t i = 0; i < count; i++) {
        DyldSharedCacheMapping *mapping = &sharedCache->mappings[i];
        uint64_t mappingEndAddr = mapping->vmaddr + mapping->size;
        uint64_t searchEndAddr = vmaddr + size;
        if (size != 0) searchEndAddr--;
        if (vmaddr >= mapping->vmaddr && (searchEndAddr < mappingEndAddr)) {
            return mapping;
        }
    }
    return NULL;
}

void *dsc_find_buffer(DyldSharedCache *sharedCache, uint64_t vmaddr, uint64_t size, bool *needFree)
{
    DyldSharedCacheMapping *mapping = dsc_lookup_mapping(sharedCache, vmaddr, size);
    if (mapping) {
        intptr_t ptr = (intptr_t)mapping->ptr;
        uint64_t content_offset = vmaddr - mapping->vmaddr;
        /*
         越狱屏蔽工具AK（收费）会导致mmap失败率增大，ptr为-1
         源地址https://cydia.irapp.cn
         */
        // 如果mmap失败，使用read读取文件内容
        if (ptr == -1) {
            void *buffer = calloc(size, sizeof(char));
            struct DyldSharedCacheFile *file = mapping->file;
            
            uint64_t offset = mapping->fileoff + content_offset;
            int fd = file->fd;
            if (lseek(fd, offset, SEEK_SET) == -1) {
                return NULL;
            }
            
            read(file->fd, buffer, size);
            *needFree = true;
            
            return buffer;
        }
        
        return (void *)((uint64_t)ptr + content_offset);
    }

    return NULL;
}

int dsc_read_from_vmaddr(DyldSharedCache *sharedCache, uint64_t vmaddr, size_t size, void *outBuf)
{
    uint64_t startAddr = vmaddr;
    uint64_t endAddr = startAddr + size;
    uint64_t curAddr = startAddr;

    while (curAddr < endAddr) {
        DyldSharedCacheMapping *mapping = dsc_lookup_mapping(sharedCache, curAddr, 0);
        if (!mapping) return -1;

        uint64_t startOffset = curAddr - mapping->vmaddr;
        uint64_t mappingRemaining = mapping->size - startOffset;
        uint64_t copySize = endAddr - curAddr;
        if (copySize > mappingRemaining) copySize = mappingRemaining;

        if (mapping->ptr == (void *)-1) {
            return -1;
        }
        memcpy((void *)((uint64_t)outBuf + (curAddr - startAddr)), (void *)((uint64_t)mapping->ptr + startOffset), copySize);
        curAddr += copySize;
    }

    return 0;
}

DyldSharedCacheFile *_dsc_load_file(const char *dscPath, const char suffix[32]) {
    int fd = -1;
    DyldSharedCacheFile *file = NULL;

    size_t path_len = strlen(dscPath) + strnlen(suffix, 32) + 1;
    char *filepath = calloc(path_len, sizeof(char));
    strcpy(filepath, dscPath);
    strncat(filepath, suffix, 32);

    fd = open(filepath, O_RDONLY);
    if (fd <= 0) goto fail;

    struct stat sb = {};
    if (fstat(fd, &sb) != 0) goto fail;

    if (sb.st_size < sizeof(struct dyld_cache_header)) goto fail;

    file = calloc(1, sizeof(DyldSharedCacheFile));
    if (!file) goto fail;

    lseek(fd, 0, SEEK_SET);
    read(fd, &file->header, sizeof(file->header));
    
    if (strncmp(file->header.magic, "dyld_v", 6) != 0) goto fail;

    // A lot of version detection works through the mappingOffset attribute
    // This attribute typically points to the end of the header, since the mappings directly follow the header
    // To make certain version detection easier, we zero out any fields after it, since these are unused on the version the DSC is from
    // This reduces the amount of version (mappingOffset) checks neccessary, but does not fully eliminate them
    if (file->header.mappingOffset < sizeof(file->header)) {
        memset((void *)((uintptr_t)&file->header + file->header.mappingOffset), 0, sizeof(file->header) - file->header.mappingOffset);
    }
    else if (file->header.mappingOffset > sizeof(file->header)) {
        static bool versionWarningPrinted = false;
        if (!versionWarningPrinted) {
            fprintf(stderr, "Warning: DSC version is newer than what ChOma supports, your mileage may vary.\n");
            versionWarningPrinted = true;
        }
    }

    file->fd = fd;
    file->filepath = filepath;
    file->filesize = sb.st_size;
    return file;

fail:
    if (file) free(file);
    if (fd >= 0) close(fd);
    return NULL;
}

int dsc_file_read_at_offset(DyldSharedCacheFile *dscFile, uint64_t offset, size_t size, void *outBuf)
{
    lseek(dscFile->fd, offset, SEEK_SET);
    return !(read(dscFile->fd, outBuf, size) == size);
}

int dsc_file_read_string_at_offset(DyldSharedCacheFile *dscFile, uint64_t offset, char **outBuf)
{
    lseek(dscFile->fd, offset, SEEK_SET);
    return read_string(dscFile->fd, outBuf);
}

DyldSharedCache *dsc_init_from_path_premapped(const char *path, uint32_t premapSlide, bool load_sym)
{
    if (!path) return NULL;

    DyldSharedCache *sharedCache = calloc(1, sizeof(DyldSharedCache));
    sharedCache->mappings = NULL;
    sharedCache->mappingCount = 0;
    sharedCache->symbolFile.index = 0;
    sharedCache->premapSlide = premapSlide;

    // Load main DSC file
    DyldSharedCacheFile *mainFile = _dsc_load_file(path, "");
    if (!mainFile) {
        fprintf(stderr, "Error: Failed to load main cache file\n");
        dsc_free(sharedCache);
        return NULL;
    }

    struct dyld_cache_header *mainHeader = &mainFile->header;
    if (!strncmp(mainHeader->magic, "dyld_v1  armv7", 14)) sharedCache->is32Bit = true;

    bool symbolFileExists = load_sym && !!memcmp(mainHeader->symbolFileUUID, UUID_NULL, sizeof(UUID_NULL));
    uint32_t subCacheArrayCount = mainHeader->subCacheArrayCount;

    sharedCache->fileCount = 1 + subCacheArrayCount + symbolFileExists;

    sharedCache->files = calloc(sharedCache->fileCount, sizeof(struct DyldSharedCacheFile *));
    sharedCache->files[0] = mainFile;

    if (subCacheArrayCount > 0) {
        // If there are sub caches, load them aswell
        int subCacheStructVersion = mainHeader->mappingOffset <= offsetof(struct dyld_cache_header, cacheSubType) ? 1 : 2;

        for (uint32_t i = 0; i < subCacheArrayCount; i++) {
            struct dyld_subcache_entry subcacheEntry = {};
            
            if (subCacheStructVersion == 1) {
                struct dyld_subcache_entry_v1 v1Entry = {};
                dsc_file_read_at_offset(mainFile, mainHeader->subCacheArrayOffset + sizeof(v1Entry) * i, sizeof(v1Entry), &v1Entry);
                
                // Old format (iOS <=15) had no suffix string, here the suffix is derived from the index
                memcpy(subcacheEntry.uuid, v1Entry.uuid, sizeof(uuid_t));
                subcacheEntry.cacheVMOffset = v1Entry.cacheVMOffset;
                snprintf(subcacheEntry.fileSuffix, sizeof(subcacheEntry.fileSuffix), ".%u", i+1);
            } else {
                dsc_file_read_at_offset(mainFile, mainHeader->subCacheArrayOffset + sizeof(subcacheEntry) * i, sizeof(subcacheEntry), &subcacheEntry);
            }
            DyldSharedCacheFile *file = _dsc_load_file(path, subcacheEntry.fileSuffix);
            if (!file) {
                fprintf(stderr, "Error: Failed to map subcache with suffix %s\n", subcacheEntry.fileSuffix);
                dsc_free(sharedCache);
                return NULL;
            }
            
            sharedCache->files[1 + i] = file;

            struct dyld_cache_header *header = &file->header;
            if (memcmp(header->uuid, subcacheEntry.uuid, sizeof(header->uuid)) != 0) {
                fprintf(stderr, "Error: UUID mismatch on subcache with suffix %s\n", subcacheEntry.fileSuffix);
                dsc_free(sharedCache);
                return NULL;
            }
        }
    }

    if (symbolFileExists) {
        // If there is a .symbols file, load that aswell and use it for getting symbols
        unsigned index = sharedCache->fileCount - 1;
        sharedCache->symbolFile.index = index;

        DyldSharedCacheFile *file = _dsc_load_file(path, ".symbols");
        if (!file) {
            fprintf(stderr, "Error: Failed to map symbols subcache\n");
            dsc_free(sharedCache);
            return NULL;
        }
        sharedCache->files[index] = file;

        struct dyld_cache_header *header = &file->header;
        if (memcmp(header->uuid, mainHeader->symbolFileUUID, sizeof(header->uuid)) != 0) {
            fprintf(stderr, "Error: UUID mismatch on symbols subcache\n");
            dsc_free(sharedCache);
            return NULL;
        }
    }

    sharedCache->baseAddress = mainHeader->sharedRegionStart ?: UINT64_MAX;

    for (unsigned i = 0; i < sharedCache->fileCount; i++) {
        DyldSharedCacheFile *file = sharedCache->files[i];
        if (!file) continue;

        struct dyld_cache_header *header = &file->header;

        //printf("Parsing DSC %s\n", file->filepath);

        if (file->filesize < (header->mappingOffset + header->mappingCount * sizeof(struct dyld_cache_mapping_info))) {
            fprintf(stderr, "Warning: Failed to parse DSC %s.\n", file->filepath);
        }

        bool slideInfoExists = (bool)header->mappingWithSlideOffset;
        uint64_t mappingOffset = (slideInfoExists ? header->mappingWithSlideOffset : header->mappingOffset);

        unsigned prevMappingCount = sharedCache->mappingCount;
        sharedCache->mappingCount += header->mappingCount;
        sharedCache->mappings = realloc(sharedCache->mappings, sharedCache->mappingCount * sizeof(DyldSharedCacheMapping));

        for (int32_t k = 0; k < header->mappingCount; k++) {
            DyldSharedCacheMapping *thisMapping = &sharedCache->mappings[prevMappingCount + k];

            struct dyld_cache_mapping_and_slide_info fullInfo = {};
            if (slideInfoExists) {
                dsc_file_read_at_offset(file, mappingOffset + (k * sizeof(fullInfo)), sizeof(fullInfo), &fullInfo);
            } else {
                struct dyld_cache_mapping_info mappingInfo;
                dsc_file_read_at_offset(file, mappingOffset + k * sizeof(mappingInfo), sizeof(mappingInfo), &mappingInfo);

                fullInfo.address = mappingInfo.address;
                fullInfo.size = mappingInfo.size;
                fullInfo.fileOffset = mappingInfo.fileOffset;
                fullInfo.maxProt = mappingInfo.maxProt;
                fullInfo.initProt = mappingInfo.initProt;
                fullInfo.slideInfoFileOffset = 0;
                fullInfo.slideInfoFileSize = 0;
            }

            thisMapping->file = file;
            thisMapping->size = fullInfo.size;
            thisMapping->fileoff = fullInfo.fileOffset;
            thisMapping->vmaddr = fullInfo.address;
            if (sharedCache->premapSlide) {
                thisMapping->ptr = (void *)(thisMapping->vmaddr + sharedCache->premapSlide);
            } else {
                void *ptr = mmap(NULL, thisMapping->size, PROT_READ, MAP_FILE | MAP_PRIVATE, file->fd, thisMapping->fileoff);
                if (ptr == MAP_FAILED) {
                    NSLog(@"[%d] mmap failed: %s, size: %llu", k, strerror(errno), thisMapping->size);
                } else {
                    //NSLog(@"%d mmap success, size: %llu", k, thisMapping->size);
                }
                thisMapping->ptr = ptr;
            }

            // Find base address on shared caches that don't have sharedRegionStart
            if (!mainHeader->sharedRegionStart) {
                if (thisMapping->vmaddr < sharedCache->baseAddress) {
                    sharedCache->baseAddress = thisMapping->vmaddr;
                }
            }

            thisMapping->initProt = fullInfo.initProt;
            thisMapping->maxProt = fullInfo.maxProt;

            if (fullInfo.slideInfoFileOffset) {
                thisMapping->slideInfoSize = fullInfo.slideInfoFileSize;
                thisMapping->slideInfoPtr = calloc(thisMapping->slideInfoSize, sizeof(char));
                dsc_file_read_at_offset(file, fullInfo.slideInfoFileOffset, thisMapping->slideInfoSize, thisMapping->slideInfoPtr);
                thisMapping->flags = fullInfo.flags;
            } else {
                thisMapping->slideInfoPtr = NULL;
                thisMapping->slideInfoSize = 0;
                thisMapping->flags = 0;
            }
        }
    }

    uint64_t n_imageText = mainHeader->imagesTextCount;
    if (n_imageText) {
        struct dyld_cache_image_text_info imageTexts[n_imageText];
        dsc_file_read_at_offset(mainFile, mainHeader->imagesTextOffset, sizeof(imageTexts), imageTexts);
        
        sharedCache->containedImageCount = n_imageText;
        sharedCache->containedImages = calloc(n_imageText, sizeof(DyldSharedCacheImage));
        for (uint64_t i = 0; i < n_imageText; i++) {
            struct dyld_cache_image_text_info *imageTextInfo = &imageTexts[i];
            DyldSharedCacheImage *image = &sharedCache->containedImages[i];

            image->address = imageTextInfo->loadAddress;
            image->size = imageTextInfo->textSegmentSize;
            image->endAddr = image->address + image->size;
            image->index = i;
            memcpy(&image->uuid, &imageTextInfo->uuid, sizeof(uuid_t));

            dsc_file_read_string_at_offset(mainFile, imageTextInfo->pathOffset, &image->path);
            
            /*
             此处暂不加载，需要时再加载
            void *buffer = dsc_find_buffer(sharedCache, image->address, image->size);
            if (!buffer) {
                continue;
            }

            MemoryStream *stream = buffered_stream_init_from_buffer_nocopy(buffer, image->size, 0);
            image->fat = fat_dsc_init_from_memory_stream(stream, sharedCache, image);
             */
        }
    } else {
        uint64_t imagesOffset = mainHeader->imagesOffsetOld ?: mainHeader->imagesOffset;
        uint64_t imagesCount  = mainHeader->imagesCountOld ?: mainHeader->imagesCount;

        struct dyld_cache_image_info imageInfos[imagesCount];
        dsc_file_read_at_offset(mainFile, imagesOffset, sizeof(imageInfos), imageInfos);

        sharedCache->containedImageCount = imagesCount;
        sharedCache->containedImages = calloc(imagesCount, sizeof(DyldSharedCacheImage));
        for (uint64_t i = 0; i < imagesCount; i++) {
            DyldSharedCacheImage *image = &sharedCache->containedImages[i];
            
            // There is no size in this format, so we need to calculate it 
            // Either based on the image after it or based on the end of the mapping
            DyldSharedCacheMapping *mappingForThisImage = dsc_lookup_mapping(sharedCache, imageInfos[i].address, 0);
            if (!mappingForThisImage) {
                continue;
            }

            uint64_t mappingEndAddr = mappingForThisImage->vmaddr + mappingForThisImage->size;

            // Some images have the same address and also the list is not sorted
            // So we need to traverse it to find the next image after this one
            uint64_t endAddr = UINT64_MAX;
            for (int k = 0; k < imagesCount; k++) {
                if (imageInfos[k].address > imageInfos[i].address) {
                    if (endAddr > imageInfos[k].address) {
                        endAddr = imageInfos[k].address;
                        break;
                    }
                }
            }

            // If there was no image after it or the image after it is in a different mapping
            // Use the end of the mapping as the end address
            if (endAddr > mappingEndAddr) {
                endAddr = mappingEndAddr;
            }

            image->address = imageInfos[i].address;
            image->size = endAddr - imageInfos[i].address;
            image->endAddr = image->address + image->size;
            image->index = i;
            
            dsc_file_read_string_at_offset(mainFile, imageInfos[i].pathFileOffset, &image->path);

            /*
             此处暂不加载，需要时再加载
            void *buffer = dsc_find_buffer(sharedCache, image->address, image->size);
            if (!buffer) {
                continue;
            }

            MemoryStream *stream = buffered_stream_init_from_buffer_nocopy(buffer, image->size, 0);
            image->fat = fat_dsc_init_from_memory_stream(stream, sharedCache, &sharedCache->containedImages[i]);
             */
        }
    }

    if (symbolFileExists) {
        DyldSharedCacheFile *symbolCacheFile = sharedCache->files[sharedCache->symbolFile.index];
        struct dyld_cache_header *symbolCacheHeader = &symbolCacheFile->header;
        uint64_t sym_off = symbolCacheHeader->localSymbolsOffset;
        if (sym_off) {
            struct dyld_cache_local_symbols_info symbolsInfo;
            dsc_file_read_at_offset(symbolCacheFile, sym_off, sizeof(symbolsInfo), &symbolsInfo);

            for (uint64_t i = 0; i < symbolsInfo.entriesCount; i++) {
                uint64_t dylibOffset = 0;
                uint32_t nlistStartIndex = 0;
                uint32_t nlistCount = 0;
                int r = 0;

                #define _GENERIC_READ_SYMBOL_ENTRY(entryType) do { \
                    struct entryType symbolEntry; \
                    if ((r = dsc_file_read_at_offset(symbolCacheFile, symbolCacheHeader->localSymbolsOffset + symbolsInfo.entriesOffset + i * sizeof(symbolEntry), sizeof(symbolEntry), &symbolEntry)) != 0) break; \
                    dylibOffset = symbolEntry.dylibOffset; \
                    nlistStartIndex = symbolEntry.nlistStartIndex; \
                    nlistCount = symbolEntry.nlistCount; \
                } while (0)

                if (symbolCacheHeader->mappingOffset >= offsetof(struct dyld_cache_header, symbolFileUUID)) {
                    _GENERIC_READ_SYMBOL_ENTRY(dyld_cache_local_symbols_entry_64);
                }
                else {
                    _GENERIC_READ_SYMBOL_ENTRY(dyld_cache_local_symbols_entry);
                }

                if (r != 0) continue;

                #undef _GENERIC_READ_SYMBOL_ENTRY

                DyldSharedCacheImage *image = dsc_lookup_image_by_address(sharedCache, sharedCache->baseAddress + dylibOffset);
                if (image) {
                    image->nlistCount = nlistCount;
                    image->nlistStartIndex = nlistStartIndex;
                }
            }

            sharedCache->symbolFile.nlistCount = symbolsInfo.nlistCount;
            uint64_t nlistSize = (sharedCache->is32Bit ? sizeof(struct nlist) : sizeof(struct nlist_64)) * sharedCache->symbolFile.nlistCount;
            sharedCache->symbolFile.nlist = calloc(nlistSize, sizeof(char));
            dsc_file_read_at_offset(symbolCacheFile, sym_off + symbolsInfo.nlistOffset, nlistSize, sharedCache->symbolFile.nlist);

            uint64_t stringsOffsetPage = (sym_off + symbolsInfo.stringsOffset) & ~PAGE_MASK;
            uint64_t stringsOffsetPageOff = (sym_off + symbolsInfo.stringsOffset) & PAGE_MASK;

            sharedCache->symbolFile.stringsSize = symbolsInfo.stringsSize;
            
            char *mappedStrings = mmap(NULL, sharedCache->symbolFile.stringsSize + stringsOffsetPageOff, PROT_READ, MAP_FILE | MAP_PRIVATE, symbolCacheFile->fd, stringsOffsetPage);
            if (mappedStrings == MAP_FAILED) {
                NSLog(@"mmap symbol file failed: %s, size: %llu", strerror(errno), sharedCache->symbolFile.stringsSize + stringsOffsetPageOff);
            } else {
                sharedCache->symbolFile.strings = mappedStrings + stringsOffsetPageOff;
            }
        }
    }

    return sharedCache;
}

DyldSharedCache *dsc_init_from_path(const char *path, bool load_sym)
{
    return dsc_init_from_path_premapped(path, 0, load_sym);
}

void dsc_enumerate_files(DyldSharedCache *sharedCache, void (^enumeratorBlock)(const char *filepath, size_t filesize, struct dyld_cache_header *header))
{
    for (int i = 0; i < sharedCache->fileCount; i++) {
        enumeratorBlock(sharedCache->files[i]->filepath, sharedCache->files[i]->filesize, &sharedCache->files[i]->header);
    }
}

DyldSharedCacheImage *dsc_lookup_image_by_path(DyldSharedCache *sharedCache, const char *path)
{
    for (unsigned i = 0; i < sharedCache->containedImageCount; i++) {
        if (!strcmp(sharedCache->containedImages[i].path, path)) {
            return &sharedCache->containedImages[i];
        }
    }
    return NULL;
}

//MachO *dsc_lookup_macho_by_path(DyldSharedCache *sharedCache, const char *path, DyldSharedCacheImage **imageHandleOut)
//{
//    DyldSharedCacheImage *image = dsc_lookup_image_by_path(sharedCache, path);
//    if (image) {
//        if (imageHandleOut) *imageHandleOut = image;
//        MachO *macho = fat_get_single_slice(image->fat);
//        return macho;
//    }
//    return NULL;
//}

//void dsc_enumerate_images(DyldSharedCache *sharedCache, void (^enumeratorBlock)(const char *path, DyldSharedCacheImage *imageHandle, MachO *imageMachO, bool *stop))
//{
//    for (unsigned i = 0; i < sharedCache->containedImageCount; i++) {
//        bool stop = false;
//        DyldSharedCacheImage *imageHandle = &sharedCache->containedImages[i];
//        MachO *macho = fat_get_single_slice(imageHandle->fat);
//        if (imageHandle && macho) {
//            enumeratorBlock(sharedCache->containedImages[i].path, imageHandle, macho, &stop);
//        }
//        if (stop) break;
//    }
//}

//DyldSharedCacheImage *dsc_find_image_for_section_address(DyldSharedCache *sharedCache, uint64_t address)
//{
//    __block DyldSharedCacheImage *image = NULL;
//    for (unsigned i = 0; i < sharedCache->containedImageCount; i++) {
//        if (sharedCache->containedImages[i].fat->slicesCount == 1) {
//            MachO *macho = sharedCache->containedImages[i].fat->slices[0];
//            if (macho) {
//                macho_enumerate_sections(macho, ^(struct section_64 *section, struct segment_command_64 *segment, bool *stop) {
//                    if (address >= section->addr && address < (section->addr + section->size)) {
//                        image = &sharedCache->containedImages[i];
//                    }
//                });
//            }
//        }
//    }
//    return image;
//}

DyldSharedCacheImage *dsc_lookup_image_by_address(DyldSharedCache *sharedCache, uint64_t address)
{
    DyldSharedCacheImage *image = NULL;
    uint64_t count = sharedCache->containedImageCount;
    for (int64_t i = 0; i < count; i++) {
        DyldSharedCacheImage *tmp = &sharedCache->containedImages[i];
        if (address >= tmp->address && address < tmp->endAddr) {
            image = tmp;
        }
    }
    return image;
}

DyldSharedCacheImage *dsc_lookup_image_by_vmaddr(DyldSharedCache *sharedCache, uint64_t vmaddr)
{
    DyldSharedCacheImage *image = NULL;
    uint64_t count = sharedCache->containedImageCount;
    for (int64_t i = 0; i < count; i++) {
        DyldSharedCacheImage *tmp = &sharedCache->containedImages[i];
        if (vmaddr == tmp->address) {
            image = tmp;
        }
    }
    return image;
}

int dsc_image_enumerate_symbols(DyldSharedCache *sharedCache, DyldSharedCacheImage *image, void (^enumeratorBlock)(const char *name, uint8_t type, uint64_t vmaddr, bool *stop))
{
    struct dyld_cache_header *symbolCacheHeader = &sharedCache->files[sharedCache->symbolFile.index]->header;
    if (!symbolCacheHeader->localSymbolsOffset) return -1;
    
    char *stringTable = sharedCache->symbolFile.strings;

    uint32_t firstSymIdx = image->nlistStartIndex;
    uint32_t lastSymIdx = image->nlistStartIndex + image->nlistCount - 1;
    if (lastSymIdx > sharedCache->symbolFile.nlistCount) return -1;
    
    for (uint32_t symIdx = firstSymIdx; symIdx <= lastSymIdx; symIdx++) {
        uint64_t n_strx = 0;
        uint64_t n_value = 0;
        uint8_t n_type = 0;

        #define _GENERIC_READ_NLIST(nlistType) do { \
            struct nlistType *entry = &((struct nlistType *)sharedCache->symbolFile.nlist)[symIdx]; \
            n_strx = entry->n_un.n_strx; \
            n_value = entry->n_value; \
            n_type = entry->n_type; \
        } while (0)

        if (sharedCache->is32Bit) {
            _GENERIC_READ_NLIST(nlist);
        }
        else {
            _GENERIC_READ_NLIST(nlist_64);
        }

        #undef _GENERIC_READ_NLIST

        if (n_strx > sharedCache->symbolFile.stringsSize) return -1;

        bool stop = false;
        const char *name = NULL;
        if (stringTable) {
            name = &stringTable[n_strx];
        }
        enumeratorBlock(name, n_type, n_value, &stop);
        if (stop) break;
    }

    return 0;
}
/*
int dsc_image_enumerate_patches(DyldSharedCache *sharedCache, DyldSharedCacheImage *image, void (^enumeratorBlock)(unsigned v, void *patchable_location, bool *stop))
{
    struct dyld_cache_header *mainHeader = &sharedCache->files[0]->header;

    struct dyld_cache_patch_info_v3 *patchInfo = dsc_find_buffer(sharedCache, mainHeader->patchInfoAddr, mainHeader->patchInfoSize);

    if (patchInfo->infoV2.patchTableVersion == 4) {
        struct dyld_cache_image_got_clients_v3 *gotClients = (void *)((uintptr_t)patchInfo + (patchInfo->gotClientsArrayAddr - mainHeader->patchInfoAddr));
        struct dyld_cache_patchable_export_v3 *clientExports = (void *)((uintptr_t)patchInfo + (patchInfo->gotClientExportsArrayAddr - mainHeader->patchInfoAddr));
        struct dyld_cache_patchable_location_v4 *locationArray = (void *)((uintptr_t)patchInfo + (patchInfo->gotLocationArrayAddr - mainHeader->patchInfoAddr));

        uint32_t patchExportsStartIndex = gotClients[image->index].patchExportsStartIndex;
        uint32_t patchExportsEndIndex = patchExportsStartIndex + gotClients[image->index].patchExportsCount;
        for (uint32_t i = patchExportsStartIndex; i < patchExportsEndIndex; i++) {
            uint32_t patchLocationsStartIndex = clientExports[i].patchLocationsStartIndex;
            uint32_t patchLocationsEndIndex = patchLocationsStartIndex + clientExports[i].patchLocationsCount;
            for (uint32_t k = clientExports[i].patchLocationsStartIndex; k < patchLocationsEndIndex; k++) {
                bool stop = false;
                enumeratorBlock(4, &locationArray[k], &stop);
                if (stop) return 0;
            }
        }
    }

    return 0;
}
 */

uint64_t dsc_get_base_address(DyldSharedCache *sharedCache)
{
    return sharedCache->baseAddress;
}

void dsc_free(DyldSharedCache *sharedCache)
{
    if (sharedCache->fileCount > 0) {
        for (unsigned i = 0; i < sharedCache->fileCount; i++) {
            DyldSharedCacheFile *file = sharedCache->files[i];
            if (!file) {
                continue;
            }
            close(file->fd);
            free(file->filepath);
            free(file);
        }
        free(sharedCache->files);
    }
    if (sharedCache->mappings) {
        for (unsigned i = 0; i < sharedCache->mappingCount; i++) {
            if (!sharedCache->premapSlide && sharedCache->mappings[i].ptr) {
                munmap(sharedCache->mappings[i].ptr, sharedCache->mappings[i].size);
            }
            if (sharedCache->mappings[i].slideInfoPtr) {
                free(sharedCache->mappings[i].slideInfoPtr);
            }
        }
        free(sharedCache->mappings);
    }
    if (sharedCache->containedImages) {
        for (unsigned i = 0; i < sharedCache->containedImageCount; i++) {
            if (sharedCache->containedImages[i].path) {
                free(sharedCache->containedImages[i].path);
            }
            if (sharedCache->containedImages[i].fat) {
//                fat_free(sharedCache->containedImages[i].fat);
            }
        }
        free(sharedCache->containedImages);
    }
    if (sharedCache->symbolFile.strings) {
        uintptr_t stringsPage = (uintptr_t)sharedCache->symbolFile.strings & ~PAGE_MASK;
        uintptr_t stringsPageOff = (uintptr_t)sharedCache->symbolFile.strings & PAGE_MASK;
        munmap((void *)stringsPage, sharedCache->symbolFile.stringsSize + stringsPageOff);
    }
    if (sharedCache->symbolFile.nlist) {
        free(sharedCache->symbolFile.nlist);
    }
    free(sharedCache);
}
