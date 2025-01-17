//
//  DSCHelper.c
//  RiskDetection
//
//  Created by bangcle on 2025/1/13.
//

#include "DSCHelper.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>
#include <string.h>
#include "dyld_cache_format.h"

const char *getSharedCacheFile(const char *base) {
    const char *sharedCachePaths[] = {
        "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64",
        "/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64e",
        //        "/System/Library/dyld/dyld_shared_cache_arm64e", // MacOS
        "/usr/share/dyld/dyld_shared_cache_arm64",
    };
    
    bool found = false;
    const char *path = NULL;
    int count = sizeof(sharedCachePaths) / sizeof(char *);
    for (int i = 0; i < count; i++) {
        if (path) {
            free((void *)path);
        }
        const char *cachePath = sharedCachePaths[i];
        if (base) {
            size_t len = strlen(base) + strlen(cachePath) + 1;
            path = calloc(len, sizeof(char));
            snprintf((char *)path, len, "%s%s", base, cachePath);
        } else {
            path = strdup(cachePath);
        }
        
        if (access(path, F_OK) == F_OK) {
            found = true;
            break;
        }
    }
    
    // 释放不需要返回的path
    if (!found && path) {
        free((void *)path);
    }
    
    return found ? path : NULL;
}

const char *findDyldCacheFile(void) {
    const char *path = getSharedCacheFile(NULL);
    if (!path) {
        int count = sizeof(cryptexPrefixes) / sizeof(char *);
        for (int i = 0; i < count; i++) {
            const char *prefix = cryptexPrefixes[i];
            path = getSharedCacheFile(prefix);
            if (path) {
                break;
            }
        }
    }
    
    return path;
}
