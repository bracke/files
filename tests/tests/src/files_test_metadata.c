/* Native fixtures for metadata the Ada directory API cannot inspect. */
#ifdef __linux__
#define _GNU_SOURCE
#include <sys/stat.h>
#include <sys/xattr.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <stdlib.h>
#include <errno.h>
#include <stdio.h>

static int trash_fault_applied;
void files_test_fault_reset(void) { trash_fault_applied = 0; }

/* Faults are linked only into the test executable, never the application. */
int chmod(const char *path, mode_t mode) {
    const char *trigger = getenv("FILES_TEST_DIRECTORY_RESTORE_FAULT");
    if (trigger && mode == 0555 && !strncmp(path, "/proc/self/fd/", 14)) {
        char actual[4096];
        ssize_t count = readlink(path, actual, sizeof(actual)-1);
        if (count >= 0) {
            actual[count] = 0;
            if (!strcmp(actual, trigger)) {
                const char *block = getenv("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
                if (block && mkdir(block, 0700) == 0) {
                    char child[4096];
                    snprintf(child, sizeof(child), "%s/replacement", block);
                    int output = open(child, O_WRONLY | O_CREAT | O_EXCL, 0600);
                    if (output >= 0) { (void)write(output, "replacement bytes", 17); close(output); }
                }
                errno = EIO;
                return -1;
            }
        }
    }
    return (int)syscall(SYS_fchmodat, AT_FDCWD, path, mode);
}

int utimensat(int fd, const char *path, const struct timespec times[2], int flags) {
    int result = (int)syscall(SYS_utimensat, fd, path, times, flags);
    const char *trigger = getenv("FILES_TEST_TRASH_TRIGGER");
    const char *source = getenv("FILES_TEST_TRASH_SOURCE");
    const char *fault = getenv("FILES_TEST_TRASH_FAULT");
    if (!result && !trash_fault_applied && trigger && source && fault &&
        !strncmp(path, trigger, strlen(trigger)) && strlen(path) >= 8 &&
        !strcmp(path + strlen(path) - 8, "/payload")) {
        trash_fault_applied = 1;
        char changed[4096];
        if (!strcmp(fault, "replace")) {
            snprintf(changed, sizeof(changed), "%s.saved", source);
            if (rename(source, changed)) return result;
        }
        snprintf(changed, sizeof(changed), "%s%s", source, !strcmp(fault, "folder") ? "/child" : "");
        int output = open(changed, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (output >= 0) { (void)write(output, "new edits", 9); close(output); }
    }
    return result;
}

static const unsigned char access_acl[] = {
    2, 0, 0, 0,                         /* POSIX ACL version, little endian */
    1, 0, 4, 0, 255, 255, 255, 255,    /* owner: read-only */
    2, 0, 4, 0, 254, 255, 0, 0,        /* uid 65534: read */
    4, 0, 0, 0, 255, 255, 255, 255,    /* owning group: no access */
    16, 0, 4, 0, 255, 255, 255, 255,   /* mask: read */
    32, 0, 0, 0, 255, 255, 255, 255    /* others: no access */
};
static const char value[] = "metadata retained";

int files_test_metadata_prepare(const char *path, int directory) {
    if (chmod(path, directory ? 0700 : 0600)) return 0;
    if (lsetxattr(path, "user.files_test", value, sizeof(value) - 1, 0) ||
        lsetxattr(path, "user.files_empty", "", 0, 0)) return 0;
    if (!directory && lsetxattr(path, "system.posix_acl_access", access_acl, sizeof(access_acl), 0)) return 0;
    if (chmod(path, directory ? 0700 : 0440)) return 0;
    const struct timespec times[2] = {{1577836800, 123456789}, {1609459200, 987654321}};
    return utimensat(AT_FDCWD, path, times, AT_SYMLINK_NOFOLLOW) == 0;
}

int files_test_metadata_check(const char *path, int directory) {
    char actual[sizeof(value)];
    if (lgetxattr(path, "user.files_test", actual, sizeof(actual)) != sizeof(value) - 1 ||
        memcmp(actual, value, sizeof(value) - 1) ||
        lgetxattr(path, "user.files_empty", NULL, 0) != 0) return 0;
    if (!directory) {
        unsigned char acl[sizeof(access_acl)];
        if (lgetxattr(path, "system.posix_acl_access", acl, sizeof(acl)) != sizeof(acl) ||
            memcmp(acl, access_acl, sizeof(acl))) return 0;
    }
    return 1;
}
long long files_test_supplementary_group(void) {
    gid_t groups[256];
    int count = getgroups(256, groups);
    if (count < 0) return -1;
    for (int i = 0; i < count; ++i)
        if (groups[i] != getegid()) return (long long)groups[i];
    return -1;
}

int files_test_set_copy_group(const char *path) {
    long long group = files_test_supplementary_group();
    return group >= 0 && lchown(path, (uid_t)-1, (gid_t)group) == 0;
}

long long files_test_entry_group(const char *path) {
    struct stat value;
    return lstat(path, &value) ? -1 : (long long)value.st_gid;
}

int files_test_default_acl(const char *path, int owner) {
    unsigned char acl[] = {
        2, 0, 0, 0,
        1, 0, 0, 0, 255, 255, 255, 255,
        4, 0, 0, 0, 255, 255, 255, 255,
        32, 0, 0, 0, 255, 255, 255, 255
    };
    acl[6] = (unsigned char)owner;
    return lsetxattr(path, "system.posix_acl_default", acl, sizeof(acl), 0) == 0;
}
int files_test_sparse_prepare(const char *path, int mixed) {
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return 0;
    int ok = ftruncate(fd, 16 * 1024 * 1024 + 3) == 0;
    if (ok && mixed) ok = pwrite(fd, "A", 1, 1024 * 1024 + 7) == 1 &&
                          pwrite(fd, "Z", 1, 12 * 1024 * 1024 + 3) == 1;
    return close(fd) == 0 && ok;
}
int files_test_sparse_check(const char *path, int mixed) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;
    struct stat info;
    unsigned char buffer[65536];
    off_t offset = 0;
    int ok = fstat(fd, &info) == 0 && info.st_size == 16 * 1024 * 1024 + 3 &&
             info.st_blocks * 512 < 1024 * 1024;
    while (ok && offset < info.st_size) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count <= 0) { ok = 0; break; }
        for (ssize_t i = 0; i < count; ++i) {
            off_t position = offset + i;
            unsigned char expected = mixed && position == 1024 * 1024 + 7 ? 'A' :
                                     mixed && position == 12 * 1024 * 1024 + 3 ? 'Z' : 0;
            if (buffer[i] != expected) { ok = 0; break; }
        }
        offset += count;
    }
    return close(fd) == 0 && ok;
}
#else
void files_test_fault_reset(void) {}
int files_test_metadata_prepare(const char *path, int directory) { (void)path; (void)directory; return 0; }
int files_test_metadata_check(const char *path, int directory) { (void)path; (void)directory; return 0; }
long long files_test_supplementary_group(void) { return -1; }
int files_test_set_copy_group(const char *path) { (void)path; return 0; }
long long files_test_entry_group(const char *path) { (void)path; return -1; }
int files_test_default_acl(const char *path, int owner) { (void)path; (void)owner; return 0; }
int files_test_sparse_prepare(const char *path, int mixed) { (void)path; (void)mixed; return 0; }
int files_test_sparse_check(const char *path, int mixed) { (void)path; (void)mixed; return 0; }
#endif
