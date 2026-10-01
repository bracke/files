#define _GNU_SOURCE
#ifdef _WIN32
#include <windows.h>
#include <sddl.h>
#include <stdlib.h>

int files_private_directory(const char *path) {
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return -1;
    wchar_t *name = malloc((size_t)count * sizeof(wchar_t));
    if (!name) return -1;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    int ok = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, name, count) != 0;
    /* Protected DACL: access only through the directory owner's rights. */
    if (ok) ok = ConvertStringSecurityDescriptorToSecurityDescriptorW(
        L"D:P(A;OICI;FA;;;OW)", SDDL_REVISION_1, &descriptor, NULL) != 0;
    if (ok) {
        SECURITY_ATTRIBUTES attributes = {sizeof(attributes), descriptor, FALSE};
        ok = CreateDirectoryW(name, &attributes) != 0;
        if (!ok) {
            DWORD error = GetLastError();
            if (descriptor) LocalFree(descriptor);
            free(name);
            return error == ERROR_ALREADY_EXISTS || error == ERROR_FILE_EXISTS ? 0 : -1;
        }
    }
    if (descriptor) LocalFree(descriptor);
    free(name);
    return ok ? 1 : -1;
}
#else
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#ifdef __linux__
#include <sys/xattr.h>
#endif
#ifdef __APPLE__
#include <sys/acl.h>
#endif

int files_private_directory(const char *path) {
    /* The inherited ACL's group mask is zero from the instant of creation. */
    if (mkdir(path, 0700)) return errno == EEXIST ? 0 : -1;
#ifdef __linux__
    int fd = open(path, O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
#else
    int fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
#endif
    if (fd < 0) { rmdir(path); return -1; }
    struct stat info;
    int ok = !fstat(fd, &info) && info.st_uid == geteuid();
#ifdef __linux__
    char held[64];
    snprintf(held, sizeof(held), "/proc/self/fd/%d", fd);
    /* O_PATH works even if the inherited owner entry has no access. */
    if (ok) ok = chmod(held, 0700) == 0;
    /* Payloads must not inherit the destination's restrictive default ACL. */
    if (ok && removexattr(held, "system.posix_acl_default") &&
        errno != ENODATA && errno != ENOTSUP && errno != EOPNOTSUPP) ok = 0;
#elif defined(__APPLE__)
    if (ok) ok = fchmod(fd, 0700) == 0;
    /* Drop inherited extended ACL entries before any payload is created. */
    acl_t empty_acl = acl_init(0);
    if (ok) ok = empty_acl != NULL;
    if (ok) ok = acl_set_fd_np(fd, empty_acl, ACL_TYPE_EXTENDED) == 0;
    if (empty_acl) acl_free(empty_acl);
#else
    if (ok) ok = fchmod(fd, 0700) == 0;
#endif
    close(fd);
    if (!ok) rmdir(path);
    return ok ? 1 : -1;
}
#endif
