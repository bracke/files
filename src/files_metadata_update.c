#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct files_identity {
    uint64_t volume, number, birth_seconds, birth_nanoseconds;
};

int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity);

#if defined(__linux__) || defined(__APPLE__)
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity) {
#ifdef __linux__
    int fd = open(path, O_PATH | O_NOFOLLOW | O_CLOEXEC);
#else
    int fd = open(path, O_EVTONLY | O_NOFOLLOW | O_CLOEXEC);
#endif
    if (fd < 0) return 0;
    struct stat info;
    int ok = fstat(fd, &info) == 0 && !S_ISLNK(info.st_mode);
#ifdef __linux__
    struct statx extra;
    ok = ok && statx(fd, "", AT_EMPTY_PATH | AT_SYMLINK_NOFOLLOW, STATX_INO | STATX_BTIME, &extra) == 0
        && (extra.stx_mask & (STATX_INO | STATX_BTIME)) == (STATX_INO | STATX_BTIME);
    if (ok) {
        identity->volume = ((uint64_t)extra.stx_dev_major << 32) | extra.stx_dev_minor;
        identity->number = extra.stx_ino;
        identity->birth_seconds = extra.stx_btime.tv_sec;
        identity->birth_nanoseconds = extra.stx_btime.tv_nsec;
    }
#else
    if (ok) {
        identity->volume = info.st_dev;
        identity->number = info.st_ino;
        identity->birth_seconds = info.st_birthtimespec.tv_sec;
        identity->birth_nanoseconds = info.st_birthtimespec.tv_nsec;
    }
#endif
    char token[128];
    if (ok) {
        snprintf(token, sizeof(token), " %llu %llu %llu %llu",
            (unsigned long long)identity->volume, (unsigned long long)identity->number,
            (unsigned long long)identity->birth_seconds, (unsigned long long)identity->birth_nanoseconds);
        ok = !*expected || strcmp(expected, token) == 0;
    }
    if (ok) {
        *previous = ownership ? info.st_uid : info.st_mode & 07777;
        *previous_group = ownership ? info.st_gid : 0;
#ifdef __linux__
        if (ownership) {
            ok = fchownat(fd, "", value, group, AT_EMPTY_PATH | AT_SYMLINK_NOFOLLOW) == 0;
        } else {
            /* O_PATH also opens mode-000 files; this magic link names the held
               inode even if its original pathname has since been replaced. */
            char held[64];
            snprintf(held, sizeof(held), "/proc/self/fd/%d", fd);
            ok = chmod(held, value & 07777) == 0;
        }
#else
        ok = ownership ? fchown(fd, value, group) == 0 : fchmod(fd, value & 07777) == 0;
#endif
    }
    close(fd);
    return ok;
}
#else
int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity) {
    (void)path; (void)expected; (void)ownership; (void)value; (void)group;
    (void)previous; (void)previous_group; (void)identity;
    return -1; /* Use the host's ACL adapter where POSIX descriptors do not apply. */
}
#endif
