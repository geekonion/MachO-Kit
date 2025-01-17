// 来自https://github.com/opa334/ChOma

#include "Util.h"
#include <stdio.h>
#include <unistd.h>
#include <string.h>

int read_string(int fd, char **strOut)
{
    uint32_t sz = 0;
    off_t pos = lseek(fd, 0, SEEK_CUR);
    char c = 0;
    do {
        if (read(fd, &c, sizeof(c)) != sizeof(c)) return -1;
        sz++;
    } while(c != 0);
    
    lseek(fd, pos, SEEK_SET);
    *strOut = malloc(sz);
    read(fd, *strOut, sz);
    
    return 0;
}

bool string_has_prefix(const char *str, const char *prefix)
{
    if (!str || !prefix) {
		return false;
	}

	size_t str_len = strlen(str);
	size_t prefix_len = strlen(prefix);

	if (str_len < prefix_len) {
		return false;
	}

	return !strncmp(str, prefix, prefix_len);
}

bool string_has_suffix(const char *str, const char *suffix)
{
    if (!str || !suffix) {
		return false;
	}

	size_t str_len = strlen(str);
	size_t suffix_len = strlen(suffix);

	if (str_len < suffix_len) {
		return false;
	}

	return !strcmp(str + str_len - suffix_len, suffix);
}
