// 来自https://github.com/opa334/ChOma

#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct s_optional_uint64 {
	bool isSet;
	uint64_t value;
} optional_uint64_t;
#define OPT_UINT64_IS_SET(x) (x.isSet)
#define OPT_UINT64_GET_VAL(x) (x.value)
#define OPT_UINT64_NONE (optional_uint64_t){.isSet = false, .value = 0}
#define OPT_UINT64(x) (optional_uint64_t){.isSet = true, .value = x}


typedef struct s_optional_bool {
	bool isSet;
	bool value;
} optional_bool;
#define OPT_BOOL_IS_SET(x) (x.isSet)
#define OPT_BOOL_GET_VAL(x) (x.value)
#define OPT_BOOL_NONE (optional_bool){.isSet = false, .value = false}
#define OPT_BOOL(x) (optional_bool){.isSet = true, .value = x}

int read_string(int fd, char **strOut);
bool string_has_prefix(const char *str, const char *prefix);
bool string_has_suffix(const char *str, const char *suffix);
#endif
