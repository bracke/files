#define _GNU_SOURCE
#include <stdlib.h>
#if defined(__linux__) || defined(__APPLE__)
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

typedef struct { int fd; mode_t mode; } directory_access;
static int set_mode(int fd, mode_t mode) {
#ifdef __linux__
    char held[64];
    snprintf(held, sizeof(held), "/proc/self/fd/%d", fd);
    return chmod(held, mode);
#else
    return fchmod(fd, mode);
#endif
}

int files_directory_rename_begin(const char *path, void **context) {
    *context = NULL;
    struct stat info;
    if (lstat(path, &info)) return 0;
    if (!S_ISDIR(info.st_mode)) return 1;
#ifdef __linux__
    int fd = open(path, O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
#else
    int fd = open(path, O_EVTONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
#endif
    if (fd < 0) return 0;
    if (fstat(fd, &info)) { close(fd); return 0; }
    if (info.st_uid != geteuid() || (info.st_mode & S_IWUSR)) { close(fd); return 1; }
    directory_access *access = malloc(sizeof(*access));
    if (!access) { close(fd); return 0; }
    access->fd = fd;
    access->mode = info.st_mode & 07777;
    /* Changing '..' while moving a directory requires write access to it.
       Only the owner's entry changes; peer access and the ACL mask stay intact. */
    if (set_mode(fd, access->mode | S_IWUSR)) { close(fd); free(access); return 0; }
    *context = access;
    return 1;
}
int files_directory_rename_finish(void *context) {
    if (!context) return 1;
    directory_access *access = context;
    int ok = set_mode(access->fd, access->mode) == 0;
    if (ok) { close(access->fd); free(access); }
    return ok;
}
void files_directory_rename_release(void *context) {
    if (!context) return;
    directory_access *access = context;
    close(access->fd);
    free(access);
}
#else
int files_directory_rename_begin(const char *path, void **context) { (void)path; *context = NULL; return 1; }
int files_directory_rename_finish(void *context) { (void)context; return 1; }
void files_directory_rename_release(void *context) { (void)context; }
#endif
