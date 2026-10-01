#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#ifdef _WIN32
#include <windows.h>
#include <winioctl.h>
#include <io.h>

int files_digest_open_noatime(const char *path) { (void)path; return -1; }

int files_copy_skip_zeros(int fd, int count) {
    DWORD returned;
    HANDLE file = (HANDLE)_get_osfhandle(fd);
    if (!DeviceIoControl(file, FSCTL_SET_SPARSE, NULL, 0, NULL, 0, &returned, NULL)) return 0;
    return _lseeki64(fd, count, SEEK_CUR) >= 0;
}
int files_copy_finish_sparse(int fd) {
    __int64 end = _lseeki64(fd, 0, SEEK_CUR);
    return end >= 0 && _chsize_s(fd, end) == 0;
}
#else
#include <unistd.h>
#ifdef __linux__
#include <fcntl.h>
int files_digest_open_noatime(const char *path) {
    return open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NOATIME);
}
#else
int files_digest_open_noatime(const char *path) { (void)path; return -1; }
#endif
int files_copy_skip_zeros(int fd, int count) { return lseek(fd, count, SEEK_CUR) >= 0; }
int files_copy_finish_sparse(int fd) {
    off_t end = lseek(fd, 0, SEEK_CUR);
    return end >= 0 && ftruncate(fd, end) == 0;
}
#endif
