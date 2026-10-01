#define _GNU_SOURCE
#include <stdint.h>
#include <string.h>

static const unsigned char witness_preparing[8] =
    {'p', 'r', 'e', 'p', 'a', 'r', 'e', '4'};
static const unsigned char witness_published[8] =
    {'p', 'u', 'b', 'l', 'i', 's', 'h', '4'};

enum claim_outcome {
    CLAIM_ERROR = 0,
    CLAIM_ACQUIRED = 1,
    CLAIM_BUSY = 2,
    CLAIM_REFUSED = 3
};

#ifdef _WIN32
#include <windows.h>
#include <stdlib.h>

static wchar_t *wide_name(const char *path) {
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    if (!count) return NULL;
    wchar_t *name = malloc((size_t)count * sizeof(wchar_t));
    if (!name) return NULL;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, name, count)) {
        free(name);
        return NULL;
    }
    return name;
}

static int valid_file_id(const FILE_ID_INFO *id) {
    int nonzero = 0, not_all_ones = 0;
    for (size_t i = 0; i < sizeof(id->FileId.Identifier); ++i) {
        nonzero |= id->FileId.Identifier[i];
        not_all_ones |= id->FileId.Identifier[i] != 0xff;
    }
    return nonzero && not_all_ones;
}

long long files_transport_lease_create(const char *path) {
    wchar_t *name = wide_name(path);
    if (!name) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ,
                              NULL, CREATE_NEW,
                              FILE_ATTRIBUTE_HIDDEN | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;
    OVERLAPPED position = {0};
    position.Offset = 16;
    if (!LockFileEx(file, LOCKFILE_FAIL_IMMEDIATELY,
                    0, 1, 0, &position)) {
        CloseHandle(file);
        return 0;
    }
    return (long long)(intptr_t)file;
}

int files_transport_lease_set_nonce(long long value, const unsigned char nonce[16]) {
    HANDLE file = (HANDLE)(intptr_t)value;
    LARGE_INTEGER start = {0};
    DWORD written;
    return file != INVALID_HANDLE_VALUE
        && SetFilePointerEx(file, start, NULL, FILE_BEGIN)
        && WriteFile(file, nonce, 16, &written, NULL) && written == 16
        && FlushFileBuffers(file);
}

static int write_witness(long long value, const unsigned char state[8]) {
    HANDLE file = (HANDLE)(intptr_t)value;
    LARGE_INTEGER start = {0};
    DWORD written;
    return file != INVALID_HANDLE_VALUE
        && SetFilePointerEx(file, start, NULL, FILE_BEGIN)
        && WriteFile(file, state, 8, &written, NULL) && written == 8
        && FlushFileBuffers(file);
}

int files_transport_lease_prepare_witness(long long value) {
    return write_witness(value, witness_preparing);
}

int files_transport_lease_publish_witness(long long value) {
    return write_witness(value, witness_published);
}

int files_transport_lease_witness_state(long long value) {
    HANDLE file = (HANDLE)(intptr_t)value;
    LARGE_INTEGER start = {0}, size;
    DWORD read_count;
    unsigned char state[8];
    if (file == INVALID_HANDLE_VALUE || !GetFileSizeEx(file, &size) || size.QuadPart != 8
        || !SetFilePointerEx(file, start, NULL, FILE_BEGIN)
        || !ReadFile(file, state, 8, &read_count, NULL) || read_count != 8) return 0;
    if (!memcmp(state, witness_preparing, 8)) return 1;
    if (!memcmp(state, witness_published, 8)) return 2;
    return 0;
}

long long files_transport_lease_claim(const char *path, int *outcome) {
    *outcome = CLAIM_ERROR;
    wchar_t *name = wide_name(path);
    if (!name) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ,
                              NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        if (error == ERROR_SHARING_VIOLATION || error == ERROR_LOCK_VIOLATION)
            *outcome = CLAIM_BUSY;
        else if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND
                 || error == ERROR_INVALID_NAME)
            *outcome = CLAIM_REFUSED;
        else
            *outcome = CLAIM_ERROR;
        return 0;
    }
    BY_HANDLE_FILE_INFORMATION info;
    OVERLAPPED position = {0};
    position.Offset = 16;
    if (!GetFileInformationByHandle(file, &info)) {
        CloseHandle(file);
        return 0;
    }
    if (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
        *outcome = CLAIM_REFUSED;
        CloseHandle(file);
        return 0;
    }
    if (!LockFileEx(file, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
                    0, 1, 0, &position)) {
        DWORD error = GetLastError();
        *outcome = error == ERROR_SHARING_VIOLATION || error == ERROR_LOCK_VIOLATION
          ? CLAIM_BUSY : CLAIM_ERROR;
        CloseHandle(file);
        return 0;
    }
    *outcome = CLAIM_ACQUIRED;
    return (long long)(intptr_t)file;
}

long long files_transport_lease_join(const char *path) {
    wchar_t *name = wide_name(path);
    if (!name) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                              NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;
    BY_HANDLE_FILE_INFORMATION info;
    OVERLAPPED position = {0};
    position.Offset = 16;
    if (!GetFileInformationByHandle(file, &info)
        || (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)
        || !LockFileEx(file, LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &position)) {
        CloseHandle(file);
        return 0;
    }
    return (long long)(intptr_t)file;
}

int files_transport_lease_identity(long long value, uint64_t result[5]) {
    HANDLE file = (HANDLE)(intptr_t)value;
    FILE_ID_INFO id;
    if (file == INVALID_HANDLE_VALUE
        || !GetFileInformationByHandleEx(file, FileIdInfo, &id, sizeof(id))
        || !valid_file_id(&id)) return 0;
    result[0] = id.VolumeSerialNumber;
    memcpy(&result[1], id.FileId.Identifier, sizeof(uint64_t));
    memcpy(&result[2], id.FileId.Identifier + sizeof(uint64_t), sizeof(uint64_t));
    LARGE_INTEGER start = {0};
    DWORD read_count;
    if (!SetFilePointerEx(file, start, NULL, FILE_BEGIN)
        || !ReadFile(file, &result[3], 16, &read_count, NULL)
        || read_count != 16) return 0;
    return 1;
}

int files_transport_lease_path_matches(long long value, const char *path) {
    HANDLE held = (HANDLE)(intptr_t)value;
    FILE_ID_INFO original, current;
    BY_HANDLE_FILE_INFORMATION attributes;
    wchar_t *name = wide_name(path);
    if (!name) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                              NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int matches = GetFileInformationByHandle(file, &attributes)
        && !(attributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)
        && GetFileInformationByHandleEx(held, FileIdInfo, &original, sizeof(original))
        && GetFileInformationByHandleEx(file, FileIdInfo, &current, sizeof(current))
        && valid_file_id(&original) && valid_file_id(&current)
        && original.VolumeSerialNumber == current.VolumeSerialNumber
        && !memcmp(original.FileId.Identifier, current.FileId.Identifier,
                   sizeof(original.FileId.Identifier));
    CloseHandle(file);
    return matches;
}

void files_transport_lease_release(long long value) {
    HANDLE file = (HANDLE)(intptr_t)value;
    if (file != INVALID_HANDLE_VALUE) {
        OVERLAPPED position = {0};
        position.Offset = 16;
        UnlockFileEx(file, 0, 1, 0, &position);
        CloseHandle(file);
    }
}

#else
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

int files_transport_lease_set_nonce(long long value, const unsigned char nonce[16]) {
    if (value <= 0) return 0;
    int fd = (int)(value - 1);
    return pwrite(fd, nonce, 16, 0) == 16 && fsync(fd) == 0;
}

static int write_witness(long long value, const unsigned char state[8]) {
    if (value <= 0) return 0;
    int fd = (int)(value - 1);
    return pwrite(fd, state, 8, 0) == 8 && fsync(fd) == 0;
}

int files_transport_lease_prepare_witness(long long value) {
    return write_witness(value, witness_preparing);
}

int files_transport_lease_publish_witness(long long value) {
    return write_witness(value, witness_published);
}

int files_transport_lease_witness_state(long long value) {
    if (value <= 0) return 0;
    int fd = (int)(value - 1);
    struct stat info;
    unsigned char state[8];
    if (fstat(fd, &info) || info.st_size != 8 || pread(fd, state, 8, 0) != 8) return 0;
    if (!memcmp(state, witness_preparing, 8)) return 1;
    if (!memcmp(state, witness_published, 8)) return 2;
    return 0;
}

long long files_transport_lease_create(const char *path) {
    int fd = open(path, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) return 0;
    struct stat info;
    if (fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_uid != geteuid()
        || info.st_nlink != 1 || fchmod(fd, 0600) || flock(fd, LOCK_SH | LOCK_NB)) {
        close(fd);
        unlink(path);
        return 0;
    }
    return (long long)fd + 1;
}

long long files_transport_lease_claim(const char *path, int *outcome) {
    *outcome = CLAIM_ERROR;
    int fd = open(path, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        *outcome = errno == ENOENT || errno == ELOOP
          ? CLAIM_REFUSED : CLAIM_ERROR;
        return 0;
    }
    struct stat info;
    if (fstat(fd, &info)) {
        close(fd);
        return 0;
    }
    if (!S_ISREG(info.st_mode) || info.st_uid != geteuid() || info.st_nlink != 1) {
        *outcome = CLAIM_REFUSED;
        close(fd);
        return 0;
    }
    if (flock(fd, LOCK_EX | LOCK_NB)) {
        *outcome = errno == EWOULDBLOCK || errno == EAGAIN ? CLAIM_BUSY : CLAIM_ERROR;
        close(fd);
        return 0;
    }
    *outcome = CLAIM_ACQUIRED;
    return (long long)fd + 1;
}

long long files_transport_lease_join(const char *path) {
    int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return 0;
    struct stat info;
    if (fstat(fd, &info) || !S_ISREG(info.st_mode)
        || info.st_uid != geteuid() || info.st_nlink != 1
        || flock(fd, LOCK_SH | LOCK_NB)) {
        close(fd);
        return 0;
    }
    return (long long)fd + 1;
}

int files_transport_lease_identity(long long value, uint64_t result[5]) {
    if (value <= 0) return 0;
    int fd = (int)(value - 1);
    struct stat info;
    if (fstat(fd, &info)) return 0;
    result[0] = (uint64_t)info.st_dev;
    result[1] = info.st_ino;
    result[2] = 0;
    return pread(fd, &result[3], 16, 0) == 16;
}

int files_transport_lease_path_matches(long long value, const char *path) {
    if (value <= 0) return 0;
    int file = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (file < 0) return 0;
    struct stat held_info, path_info;
    int matches = !fstat((int)(value - 1), &held_info)
        && !fstat(file, &path_info)
        && S_ISREG(path_info.st_mode)
        && path_info.st_uid == geteuid()
        && path_info.st_nlink == 1
        && held_info.st_dev == path_info.st_dev
        && held_info.st_ino == path_info.st_ino;
    close(file);
    return matches;
}

void files_transport_lease_release(long long value) {
    if (value > 0) close((int)(value - 1));
}
#endif
