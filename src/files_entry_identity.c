#define _GNU_SOURCE
#include <stdint.h>

struct files_identity {
    uint64_t volume, number, birth_seconds, birth_nanoseconds;
};

#ifdef _WIN32
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0602
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0602
#endif
#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static int files_valid_file_id(const FILE_ID_INFO *id) {
    int nonzero = 0, not_all_ones = 0;
    for (size_t i = 0; i < sizeof(id->FileId.Identifier); ++i) {
        nonzero |= id->FileId.Identifier[i];
        not_all_ones |= id->FileId.Identifier[i] != 0xff;
    }
    return nonzero && not_all_ones;
}

static int files_identity_from_handle(HANDLE file, struct files_identity *value) {
    BY_HANDLE_FILE_INFORMATION info;
    FILE_ID_INFO id;
    if (!GetFileInformationByHandle(file, &info)) return 0;
    if (GetFileInformationByHandleEx(file, FileIdInfo, &id, sizeof(id))
        && files_valid_file_id(&id)) {
        value->volume = id.VolumeSerialNumber;
        /* Preserve all 128 ID bits; ReFS may map distinct files to one 64-bit
           legacy file index. */
        memcpy(&value->number, id.FileId.Identifier, sizeof(uint64_t));
        memcpy(&value->birth_seconds,
               id.FileId.Identifier + sizeof(uint64_t), sizeof(uint64_t));
        value->birth_nanoseconds =
            ((uint64_t)info.ftCreationTime.dwHighDateTime << 32)
            | info.ftCreationTime.dwLowDateTime;
        return 1;
    }

    /* Some NTFS hosts reject FileIdInfo while still supplying the documented
       stable 64-bit file index. Never use this narrower fallback on ReFS. */
    wchar_t file_system[16];
    if (!GetVolumeInformationByHandleW(file, NULL, 0, NULL, NULL, NULL,
                                       file_system,
                                       sizeof(file_system) / sizeof(file_system[0]))
        || _wcsicmp(file_system, L"NTFS") != 0) return 0;
    uint64_t number = ((uint64_t)info.nFileIndexHigh << 32) | info.nFileIndexLow;
    if (!number || number == UINT64_MAX) return 0;
    value->volume = info.dwVolumeSerialNumber;
    value->number = number;
    value->birth_seconds = ((uint64_t)info.ftCreationTime.dwHighDateTime << 32)
        | info.ftCreationTime.dwLowDateTime;
    value->birth_nanoseconds = 0;
    return 1;
}

int files_entry_identity(const char *path, struct files_identity *value) {
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return 0;
    wchar_t *name = malloc((size_t)count * sizeof(wchar_t));
    if (!name) return 0;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, name, count)) {
        free(name);
        return 0;
    }
    HANDLE file = CreateFileW(name, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = files_identity_from_handle(file, value);
    CloseHandle(file);
    return ok;
}
#elif defined(__linux__)
#include <sys/stat.h>
#include <fcntl.h>

int files_entry_identity(const char *path, struct files_identity *value) {
    struct statx info;
    if (!statx(AT_FDCWD, path, AT_SYMLINK_NOFOLLOW, STATX_INO | STATX_BTIME, &info)
        && (info.stx_mask & (STATX_INO | STATX_BTIME)) ==
            (STATX_INO | STATX_BTIME)) {
        value->volume = ((uint64_t)info.stx_dev_major << 32) | info.stx_dev_minor;
        value->number = info.stx_ino;
        value->birth_seconds = (uint64_t)info.stx_btime.tv_sec;
        value->birth_nanoseconds = info.stx_btime.tv_nsec;
        return 1;
    }
    /* An inode and a copyable nonce cannot distinguish a replacement after
       inode reuse. Refuse identity-based mutations without birth time. */
    return 0;
}
#elif defined(__APPLE__)
#include <sys/stat.h>

int files_entry_identity(const char *path, struct files_identity *value) {
    struct stat info;
    if (lstat(path, &info)) return 0;
    value->volume = (uint64_t)info.st_dev;
    value->number = info.st_ino;
    value->birth_seconds = (uint64_t)info.st_birthtimespec.tv_sec;
    value->birth_nanoseconds = (uint64_t)info.st_birthtimespec.tv_nsec;
    return 1;
}
#else
int files_entry_identity(const char *path, struct files_identity *value) {
    (void)path;
    (void)value;
    return 0;
}
#endif

int files_entry_revision(const char *path, uint64_t value[8]) {
#ifdef _WIN32
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return 0;
    wchar_t *name = malloc((size_t)count * sizeof(wchar_t));
    if (!name) return 0;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, name, count)) {
        free(name);
        return 0;
    }
    HANDLE file = CreateFileW(name, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;
    BY_HANDLE_FILE_INFORMATION info;
    FILE_BASIC_INFO basic;
    int ok = GetFileInformationByHandle(file, &info)
        && GetFileInformationByHandleEx(file, FileBasicInfo, &basic, sizeof(basic));
    CloseHandle(file);
    if (!ok) return 0;
    value[0] = basic.LastWriteTime.QuadPart;
    value[1] = value[3] = 0;
    value[2] = basic.ChangeTime.QuadPart;
    value[4] = ((uint64_t)info.nFileSizeHigh << 32) | info.nFileSizeLow;
    value[5] = info.dwFileAttributes;
    value[6] = value[7] = 0;
    return 1;
#elif defined(__linux__) || defined(__APPLE__)
    struct stat info;
    if (lstat(path, &info)) return 0;
#ifdef __APPLE__
    value[0] = info.st_mtimespec.tv_sec;
    value[1] = info.st_mtimespec.tv_nsec;
    value[2] = info.st_ctimespec.tv_sec;
    value[3] = info.st_ctimespec.tv_nsec;
#else
    value[0] = info.st_mtim.tv_sec;
    value[1] = info.st_mtim.tv_nsec;
    value[2] = info.st_ctim.tv_sec;
    value[3] = info.st_ctim.tv_nsec;
#endif
    value[4] = info.st_size;
    value[5] = info.st_mode;
    value[6] = info.st_uid;
    value[7] = info.st_gid;
    return 1;
#else
    (void)path;
    (void)value;
    return 0;
#endif
}
