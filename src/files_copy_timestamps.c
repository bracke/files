#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>

typedef struct {
    int64_t times[4];
    uint64_t links;
} copy_metadata;

static HANDLE open_entry(const char *path, DWORD access) {
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return INVALID_HANDLE_VALUE;
    wchar_t *name = malloc((size_t)count * sizeof(wchar_t));
    if (!name) return INVALID_HANDLE_VALUE;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, name, count)) {
        free(name);
        return INVALID_HANDLE_VALUE;
    }
    HANDLE file = CreateFileW(name, access,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    return file;
}

int files_copy_times_capture(const char *source, int64_t times[4]) {
    HANDLE file = open_entry(source, FILE_READ_ATTRIBUTES);
    if (file == INVALID_HANDLE_VALUE) return 0;
    FILETIME accessed, modified;
    int ok = GetFileTime(file, NULL, &accessed, &modified);
    CloseHandle(file);
    if (ok) {
        times[0] = ((int64_t)accessed.dwHighDateTime << 32) | accessed.dwLowDateTime;
        times[1] = 0;
        times[2] = ((int64_t)modified.dwHighDateTime << 32) | modified.dwLowDateTime;
        times[3] = 0;
    }
    return ok;
}

int files_copy_times_apply(const char *path, const int64_t times[4]) {
    HANDLE file = open_entry(path, FILE_WRITE_ATTRIBUTES);
    if (file == INVALID_HANDLE_VALUE) return 0;
    FILETIME accessed = {(DWORD)times[0], (DWORD)((uint64_t)times[0] >> 32)};
    FILETIME modified = {(DWORD)times[2], (DWORD)((uint64_t)times[2] >> 32)};
    int ok = SetFileTime(file, NULL, &accessed, &modified);
    CloseHandle(file);
    return ok;
}

void *files_copy_metadata_capture(const char *source) {
    copy_metadata *data = calloc(1, sizeof(*data));
    if (!data) return NULL;
    if (!files_copy_times_capture(source, data->times)) {
        free(data);
        return NULL;
    }
    HANDLE file = open_entry(source, FILE_READ_ATTRIBUTES);
    BY_HANDLE_FILE_INFORMATION info;
    if (file == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(file, &info)) {
        if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
        free(data);
        return NULL;
    }
    data->links = info.nNumberOfLinks;
    CloseHandle(file);
    return data;
}

int files_copy_metadata_apply(const copy_metadata *data, const char *destination, int preserve_ownership) {
    (void)preserve_ownership;
    HANDLE file = open_entry(destination, FILE_WRITE_ATTRIBUTES);
    if (file == INVALID_HANDLE_VALUE) return 0;
    FILETIME accessed = {(DWORD)data->times[0], (DWORD)((uint64_t)data->times[0] >> 32)};
    FILETIME modified = {(DWORD)data->times[2], (DWORD)((uint64_t)data->times[2] >> 32)};
    int ok = SetFileTime(file, NULL, &accessed, &modified);
    CloseHandle(file);
    return ok;
}

void files_copy_metadata_release(copy_metadata *data) { free(data); }

#elif defined(__linux__) || defined(__APPLE__)
#include <sys/stat.h>
#include <sys/xattr.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>

typedef struct copy_attribute {
    char *name;
    void *value;
    size_t size;
    struct copy_attribute *next;
} copy_attribute;

typedef struct {
    int64_t times[4];
    uint64_t links;
    mode_t mode;
    uid_t owner;
    gid_t group;
    copy_attribute *attributes;
} copy_metadata;

static ssize_t list_attributes(const char *path, char *names, size_t size) {
#ifdef __APPLE__
    return listxattr(path, names, size, XATTR_NOFOLLOW);
#else
    return llistxattr(path, names, size);
#endif
}

static ssize_t get_attribute(const char *path, const char *name, void *value, size_t size) {
#ifdef __APPLE__
    return getxattr(path, name, value, size, 0, XATTR_NOFOLLOW);
#else
    return lgetxattr(path, name, value, size);
#endif
}

static int set_attribute(const char *path, const copy_attribute *attribute) {
#ifdef __APPLE__
    return setxattr(path, attribute->name, attribute->value, attribute->size, 0, XATTR_NOFOLLOW);
#else
    return lsetxattr(path, attribute->name, attribute->value, attribute->size, 0);
#endif
}

static void stat_times(const struct stat *info, int64_t times[4]) {
#ifdef __APPLE__
    times[0] = info->st_atimespec.tv_sec;
    times[1] = info->st_atimespec.tv_nsec;
    times[2] = info->st_mtimespec.tv_sec;
    times[3] = info->st_mtimespec.tv_nsec;
#else
    times[0] = info->st_atim.tv_sec;
    times[1] = info->st_atim.tv_nsec;
    times[2] = info->st_mtim.tv_sec;
    times[3] = info->st_mtim.tv_nsec;
#endif
}

int files_copy_times_capture(const char *source, int64_t times[4]) {
    struct stat info;
    if (lstat(source, &info)) return 0;
    stat_times(&info, times);
    return 1;
}

int files_copy_times_apply(const char *path, const int64_t times[4]) {
    struct timespec values[2] = {
        {(time_t)times[0], (long)times[1]},
        {(time_t)times[2], (long)times[3]}
    };
    return utimensat(AT_FDCWD, path, values, AT_SYMLINK_NOFOLLOW) == 0;
}

void files_copy_metadata_release(copy_metadata *data) {
    if (!data) return;
    copy_attribute *attribute = data->attributes;
    while (attribute) {
        copy_attribute *next = attribute->next;
        free(attribute->name);
        free(attribute->value);
        free(attribute);
        attribute = next;
    }
    free(data);
}

void *files_copy_metadata_capture(const char *source) {
    struct stat info;
    if (lstat(source, &info)) return NULL;
    copy_metadata *data = calloc(1, sizeof(*data));
    if (!data) return NULL;
    data->mode = info.st_mode;
    data->owner = info.st_uid;
    data->group = info.st_gid;
    data->links = info.st_nlink;
    stat_times(&info, data->times);
    ssize_t size = list_attributes(source, NULL, 0);
    if (size < 0 && (errno == ENOTSUP || errno == EOPNOTSUPP)) return data;
    if (size < 0 || size > 64 * 1024 * 1024) goto failed;
    if (!size) return data;
    char *names = malloc((size_t)size);
    if (!names) goto failed;
    ssize_t actual = list_attributes(source, names, (size_t)size);
    if (actual < 0) { free(names); goto failed; }
    size_t total = (size_t)actual;
    for (size_t offset = 0; offset < (size_t)actual;) {
        const char *name = names + offset;
        size_t length = strnlen(name, (size_t)actual - offset);
        if (length == (size_t)actual - offset) { free(names); goto failed; }
        offset += length + 1;
        /* A copy can have different ownership; never grant file capabilities. */
        if (!strcmp(name, "security.capability")) continue;
        copy_attribute *attribute = calloc(1, sizeof(*attribute));
        if (!attribute) { free(names); goto failed; }
        attribute->next = data->attributes;
        data->attributes = attribute;
        attribute->name = strdup(name);
        ssize_t value_size = get_attribute(source, name, NULL, 0);
        if (!attribute->name || value_size < 0 || (size_t)value_size > 64 * 1024 * 1024 - total) {
            free(names);
            goto failed;
        }
        total += (size_t)value_size;
        attribute->size = (size_t)value_size;
        attribute->value = malloc(attribute->size ? attribute->size : 1);
        if (!attribute->value || get_attribute(source, name, attribute->value, attribute->size) != value_size) {
            free(names);
            goto failed;
        }
    }
    free(names);
    return data;
failed:
    files_copy_metadata_release(data);
    return NULL;
}

int files_copy_metadata_apply(const copy_metadata *data, const char *destination, int preserve_ownership) {
    if (preserve_ownership) {
        struct stat current;
        if (lstat(destination, &current)) return 0;
        if ((current.st_uid != data->owner || current.st_gid != data->group) &&
            lchown(destination, data->owner, data->group)) return 0;
    }
#ifdef __linux__
    /* An inherited ACL must not add access absent from the source. */
    const char *acl_names[] = {"system.posix_acl_access", "system.posix_acl_default"};
    if (!S_ISLNK(data->mode)) {
        for (size_t i = 0; i < 2; ++i) {
            int present = 0;
            for (copy_attribute *attribute = data->attributes; attribute; attribute = attribute->next)
                if (!strcmp(attribute->name, acl_names[i])) present = 1;
            if (!present && lremovexattr(destination, acl_names[i]) &&
                errno != ENODATA && errno != ENOTSUP && errno != EOPNOTSUPP) return 0;
        }
    }
#endif
    /* A read-only access ACL can prevent later user-attribute writes. */
    for (int acl_pass = 0; acl_pass < 2; ++acl_pass) {
        for (copy_attribute *attribute = data->attributes; attribute; attribute = attribute->next) {
            int is_acl = !strcmp(attribute->name, "system.posix_acl_access") ||
                         !strcmp(attribute->name, "system.posix_acl_default");
            if (is_acl == acl_pass && set_attribute(destination, attribute)) return 0;
        }
    }
    /* Set attributes while our private copy is writable, then its final mode. */
    if (!S_ISLNK(data->mode) && chmod(destination, data->mode & 01777)) return 0;
    struct timespec times[2] = {
        {(time_t)data->times[0], (long)data->times[1]},
        {(time_t)data->times[2], (long)data->times[3]}
    };
    return utimensat(AT_FDCWD, destination, times, AT_SYMLINK_NOFOLLOW) == 0;
}
#else
typedef struct { int64_t times[4]; uint64_t links; } copy_metadata;
int files_copy_times_capture(const char *source, int64_t times[4]) {
    (void)source; (void)times; return 0;
}
int files_copy_times_apply(const char *path, const int64_t times[4]) {
    (void)path; (void)times; return 0;
}
void *files_copy_metadata_capture(const char *source) { (void)source; return NULL; }
int files_copy_metadata_apply(const copy_metadata *data, const char *destination, int preserve_ownership) {
    (void)data; (void)destination; (void)preserve_ownership; return 0;
}
void files_copy_metadata_release(copy_metadata *data) { free(data); }
#endif

void files_copy_metadata_set_times(copy_metadata *data, const int64_t times[4]) {
    memcpy(data->times, times, sizeof(data->times));
}

uint64_t files_copy_metadata_link_count(const copy_metadata *data) { return data->links; }
