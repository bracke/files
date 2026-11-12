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

/* Faults are linked only into the test executable, never the application.
   The flush, copy and restore faults are Ada seams (Files.Durability.Testing,
   Files.File_System.Testing), so that they run on every host. */

/* With FILES_TEST_XATTR_UNSUPPORTED set, setting any extended attribute
   fails as on a volume that holds none (vfat, exFAT): a copy must still
   succeed, without them. All three setters are interposed -- hostkit's
   Linux metadata copy calls lsetxattr -- and each refusal is counted, so a
   test can tell that the fault was reached rather than bypassed. */
static long xattr_refusals;

static int refuse_xattr(void) {
    if (!getenv("FILES_TEST_XATTR_UNSUPPORTED")) return 0;
    __atomic_add_fetch(&xattr_refusals, 1, __ATOMIC_SEQ_CST);
    errno = EOPNOTSUPP;
    return 1;
}

int lsetxattr(const char *path, const char *name, const void *value, size_t size, int flags) {
    if (refuse_xattr()) return -1;
    return (int)syscall(SYS_lsetxattr, path, name, value, size, flags);
}

int setxattr(const char *path, const char *name, const void *value, size_t size, int flags) {
    if (refuse_xattr()) return -1;
    return (int)syscall(SYS_setxattr, path, name, value, size, flags);
}

int fsetxattr(int fd, const char *name, const void *value, size_t size, int flags) {
    if (refuse_xattr()) return -1;
    return (int)syscall(SYS_fsetxattr, fd, name, value, size, flags);
}

/* How many extended-attribute writes the fault above has refused so far. */
long long files_test_xattr_refusal_count(void) {
    return __atomic_load_n(&xattr_refusals, __ATOMIC_SEQ_CST);
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
#elif defined(_WIN32)
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#include <windows.h>
#include <string.h>
#include <wchar.h>

/* Windows keeps in named data streams what Linux keeps in xattrs: the Mark
   of the Web a browser puts on a download is the Zone.Identifier stream. */
static const char zone_value[] = "[ZoneTransfer]\r\nZoneId=3\r\n";
static const char stream_value[] = "metadata retained";

static int widen(const char *path, const wchar_t *suffix, wchar_t *out, int size) {
    int length = MultiByteToWideChar(CP_UTF8, 0, path, -1, out, size);
    if (length <= 0) return 0;
    if (suffix) {
        if ((size_t)length + wcslen(suffix) > (size_t)size) return 0;
        wcscat(out, suffix);
    }
    return 1;
}

static int write_stream(const char *path, const wchar_t *stream, const char *value, DWORD size) {
    wchar_t name[2048];
    DWORD written = 0;
    if (!widen(path, stream, name, 2048)) return 0;
    HANDLE file = CreateFileW(name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = WriteFile(file, value, size, &written, NULL) && written == size;
    return CloseHandle(file) && ok;
}

static int stream_holds(const char *path, const wchar_t *stream, const char *value, DWORD size) {
    wchar_t name[2048];
    char actual[256];
    DWORD count = 0;
    if (!widen(path, stream, name, 2048)) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                              FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = ReadFile(file, actual, sizeof(actual), &count, NULL) && count == size && !memcmp(actual, value, size);
    return CloseHandle(file) && ok;
}

static FILETIME file_time(ULONGLONG unix_seconds, ULONGLONG ticks) {
    ULONGLONG value = (unix_seconds + 11644473600ULL) * 10000000ULL + ticks;
    FILETIME result;
    result.dwLowDateTime = (DWORD)(value & 0xFFFFFFFFULL);
    result.dwHighDateTime = (DWORD)(value >> 32);
    return result;
}

/* A file is left read-only: its streams must be copied before that
   attribute is, or the copy could not take them. Writing a stream moves
   the modification time, so the times are set afterwards, to the Linux
   fixture's (to the 100 ns NTFS keeps). */
int files_test_metadata_prepare(const char *path, int directory) {
    wchar_t name[2048];
    if (!widen(path, NULL, name, 2048)) return 0;
    if (!directory && !SetFileAttributesW(name, FILE_ATTRIBUTE_NORMAL)) return 0;
    if (!write_stream(path, L":Zone.Identifier", zone_value, sizeof(zone_value) - 1) ||
        !write_stream(path, L":files.test", stream_value, sizeof(stream_value) - 1)) return 0;
    HANDLE entry = CreateFileW(name, FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                               NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (entry == INVALID_HANDLE_VALUE) return 0;
    FILETIME accessed = file_time(1577836800ULL, 1234567), modified = file_time(1609459200ULL, 9876543);
    int ok = SetFileTime(entry, NULL, &accessed, &modified);
    if (!CloseHandle(entry) || !ok) return 0;
    return directory || SetFileAttributesW(name, FILE_ATTRIBUTE_READONLY);
}

int files_test_metadata_check(const char *path, int directory) {
    wchar_t name[2048];
    if (!widen(path, NULL, name, 2048)) return 0;
    DWORD attributes = GetFileAttributesW(name);
    if (attributes == INVALID_FILE_ATTRIBUTES) return 0;
    if (!directory && !(attributes & FILE_ATTRIBUTE_READONLY)) return 0;
    return stream_holds(path, L":Zone.Identifier", zone_value, sizeof(zone_value) - 1) &&
           stream_holds(path, L":files.test", stream_value, sizeof(stream_value) - 1);
}

long long files_test_supplementary_group(void) { return -1; }
int files_test_set_copy_group(const char *path) { (void)path; return 0; }
long long files_test_entry_group(const char *path) { (void)path; return -1; }
int files_test_default_acl(const char *path, int owner) { (void)path; (void)owner; return 0; }

static int write_byte_at(HANDLE file, LONGLONG offset, char value) {
    LARGE_INTEGER position;
    DWORD written = 0;
    position.QuadPart = offset;
    return SetFilePointerEx(file, position, NULL, FILE_BEGIN) &&
           WriteFile(file, &value, 1, &written, NULL) && written == 1;
}

/* The Linux fixture's shape, made sparse the Windows way: FSCTL_SET_SPARSE,
   then an end of file 16 MiB + 3 out that allocates nothing. */
int files_test_sparse_prepare(const char *path, int mixed) {
    wchar_t name[2048];
    DWORD returned = 0;
    LARGE_INTEGER end;
    if (!widen(path, NULL, name, 2048)) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    end.QuadPart = 16 * 1024 * 1024 + 3;
    int ok = DeviceIoControl(file, FSCTL_SET_SPARSE, NULL, 0, NULL, 0, &returned, NULL) &&
             SetFilePointerEx(file, end, NULL, FILE_BEGIN) && SetEndOfFile(file);
    if (ok && mixed) ok = write_byte_at(file, 1024 * 1024 + 7, 'A') &&
                          write_byte_at(file, 12 * 1024 * 1024 + 3, 'Z');
    return CloseHandle(file) && ok;
}

/* Every byte, and an allocation (GetCompressedFileSizeW: what a sparse file
   really holds, in 64 KiB units on NTFS) under 1 MiB. */
int files_test_sparse_check(const char *path, int mixed) {
    wchar_t name[2048];
    static unsigned char buffer[65536];
    LARGE_INTEGER size;
    DWORD high = 0, count = 0;
    LONGLONG offset = 0;
    if (!widen(path, NULL, name, 2048)) return 0;
    SetLastError(NO_ERROR);
    DWORD low = GetCompressedFileSizeW(name, &high);
    if (low == INVALID_FILE_SIZE && GetLastError() != NO_ERROR) return 0;
    if ((((ULONGLONG)high << 32) | low) >= 1024 * 1024) return 0;
    HANDLE file = CreateFileW(name, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    int ok = GetFileSizeEx(file, &size) && size.QuadPart == 16 * 1024 * 1024 + 3;
    while (ok && offset < size.QuadPart) {
        if (!ReadFile(file, buffer, sizeof(buffer), &count, NULL) || count == 0) { ok = 0; break; }
        for (DWORD i = 0; i < count; ++i) {
            LONGLONG position = offset + i;
            unsigned char expected = mixed && position == 1024 * 1024 + 7 ? 'A' :
                                     mixed && position == 12 * 1024 * 1024 + 3 ? 'Z' : 0;
            if (buffer[i] != expected) { ok = 0; break; }
        }
        offset += count;
    }
    return CloseHandle(file) && ok;
}
#else
int files_test_metadata_prepare(const char *path, int directory) { (void)path; (void)directory; return 0; }
int files_test_metadata_check(const char *path, int directory) { (void)path; (void)directory; return 0; }
long long files_test_supplementary_group(void) { return -1; }
int files_test_set_copy_group(const char *path) { (void)path; return 0; }
long long files_test_entry_group(const char *path) { (void)path; return -1; }
int files_test_default_acl(const char *path, int owner) { (void)path; (void)owner; return 0; }
int files_test_sparse_prepare(const char *path, int mixed) { (void)path; (void)mixed; return 0; }
int files_test_sparse_check(const char *path, int mixed) { (void)path; (void)mixed; return 0; }
#endif
#ifndef __linux__
long long files_test_xattr_refusal_count(void) { return -1; }
#endif

/* Windows-only fixtures: streams, EFS and inherited ACEs. Elsewhere they
   answer "not done", and the tests that call them run only on Windows. */
#if defined(_WIN32)
#include <aclapi.h>
#include <sddl.h>

/* How many named data streams the entry has (its unnamed ::$DATA left out);
   a volume without streams has none to list. */
int files_test_named_stream_count(const char *path) {
    wchar_t name[2048];
    WIN32_FIND_STREAM_DATA data;
    int count = 0;
    if (!widen(path, NULL, name, 2048)) return -1;
    HANDLE find = FindFirstStreamW(name, FindStreamInfoStandard, &data, 0);
    if (find == INVALID_HANDLE_VALUE) return 0;
    do {
        if (wcscmp(data.cStreamName, L"::$DATA")) ++count;
    } while (FindNextStreamW(find, &data));
    FindClose(find);
    return count;
}

int files_test_encrypt(const char *path) {
    wchar_t name[2048];
    return widen(path, NULL, name, 2048) && EncryptFileW(name);
}

int files_test_is_encrypted(const char *path) {
    wchar_t name[2048];
    if (!widen(path, NULL, name, 2048)) return 0;
    DWORD attributes = GetFileAttributesW(name);
    return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_ENCRYPTED) != 0;
}

/* Give a folder an extra ACE its contents inherit: Everyone may read. */
int files_test_add_inherited_ace(const char *path) {
    wchar_t name[2048];
    PACL old = NULL, acl = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    PSID everyone = NULL;
    EXPLICIT_ACCESS_W grant;
    if (!widen(path, NULL, name, 2048)) return 0;
    if (GetNamedSecurityInfoW(name, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION, NULL, NULL, &old, NULL,
                              &descriptor) != ERROR_SUCCESS) return 0;
    DWORD result = ConvertStringSidToSidW(L"S-1-1-0", &everyone) ? ERROR_SUCCESS : GetLastError();
    if (result == ERROR_SUCCESS) {
        memset(&grant, 0, sizeof(grant));
        grant.grfAccessPermissions = FILE_GENERIC_READ;
        grant.grfAccessMode = GRANT_ACCESS;
        grant.grfInheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT;
        grant.Trustee.TrusteeForm = TRUSTEE_IS_SID;
        grant.Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP;
        grant.Trustee.ptstrName = (LPWSTR)everyone;
        result = SetEntriesInAclW(1, &grant, old, &acl);
    }
    if (result == ERROR_SUCCESS)
        result = SetNamedSecurityInfoW(name, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION, NULL, NULL, acl, NULL);
    if (acl) LocalFree(acl);
    if (everyone) LocalFree(everyone);
    LocalFree(descriptor);
    return result == ERROR_SUCCESS;
}

/* Whether the entry inherited that ACE, and carries no OWNER RIGHTS
   (S-1-3-4) ACE: the one a private staging folder hands down. */
int files_test_inherits_ace(const char *path) {
    wchar_t name[2048];
    PACL dacl = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    PSID everyone = NULL, owner_rights = NULL;
    int inherited = 0, owner_only = 0;
    if (!widen(path, NULL, name, 2048)) return 0;
    if (GetNamedSecurityInfoW(name, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION, NULL, NULL, &dacl, NULL,
                              &descriptor) != ERROR_SUCCESS) return 0;
    if (dacl && ConvertStringSidToSidW(L"S-1-1-0", &everyone) &&
        ConvertStringSidToSidW(L"S-1-3-4", &owner_rights)) {
        for (DWORD index = 0; index < dacl->AceCount; ++index) {
            LPVOID raw = NULL;
            if (!GetAce(dacl, index, &raw)) continue;
            ACE_HEADER *header = (ACE_HEADER *)raw;
            if (header->AceType != ACCESS_ALLOWED_ACE_TYPE) continue;
            ACCESS_ALLOWED_ACE *ace = (ACCESS_ALLOWED_ACE *)header;
            PSID sid = (PSID)&ace->SidStart;
            if (EqualSid(sid, everyone) && (header->AceFlags & INHERITED_ACE) && (ace->Mask & FILE_READ_DATA))
                inherited = 1;
            if (EqualSid(sid, owner_rights)) owner_only = 1;
        }
    }
    if (everyone) LocalFree(everyone);
    if (owner_rights) LocalFree(owner_rights);
    LocalFree(descriptor);
    return inherited && !owner_only;
}

/* Switch off the backup and restore privileges in this process's token.
   A shell such as MSYS2's bash turns them on for an administrator, and the
   suite inherits them: CreateDirectoryW, MoveFileExW and DeleteFileW open
   with backup intent, so with them on every DACL a permission test sets
   is passed over (only the CRT's _wopen, which does not ask for backup
   intent, was refused). A user starting the app never has them on.
   Returns 1 when the token was adjusted (or had nothing to adjust). */
int files_test_drop_backup_privileges(void) {
    static const wchar_t *const names[] = { L"SeBackupPrivilege", L"SeRestorePrivilege" };
    HANDLE token = NULL;
    int ok = 1;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token)) return 0;
    for (size_t i = 0; i < sizeof names / sizeof names[0]; ++i) {
        TOKEN_PRIVILEGES change;
        change.PrivilegeCount = 1;
        change.Privileges[0].Attributes = 0;
        if (!LookupPrivilegeValueW(NULL, names[i], &change.Privileges[0].Luid)) continue;
        if (!AdjustTokenPrivileges(token, FALSE, &change, 0, NULL, NULL)) ok = 0;
    }
    CloseHandle(token);
    return ok;
}

/* Make the file read-only as Windows means it: the read-only attribute,
   which a copy keeps. GNAT.OS_Lib.Set_Read_Only first denies its caller
   FILE_WRITE_ATTRIBUTES and then sets the attribute, which only the
   backup intent of SetFileAttributesW let through while the suite held
   the backup privilege. Returns 1 when the attribute is set. */
int files_test_set_read_only_attribute(const char *path) {
    wchar_t name[2048];
    if (!widen(path, NULL, name, 2048)) return 0;
    DWORD attributes = GetFileAttributesW(name);
    if (attributes == INVALID_FILE_ATTRIBUTES) return 0;
    return SetFileAttributesW(name, attributes | FILE_ATTRIBUTE_READONLY) != 0;
}
#else
int files_test_drop_backup_privileges(void) { return 1; }
int files_test_set_read_only_attribute(const char *path) { (void)path; return 0; }
#ifdef __linux__
/* Linux's counterpart of named streams: the entry's user.* attributes. */
int files_test_named_stream_count(const char *path) {
    char names[4096];
    ssize_t length = llistxattr(path, names, sizeof(names));
    int count = 0;
    if (length < 0) return errno == ENOTSUP ? 0 : -1;
    for (ssize_t at = 0; at < length; at += (ssize_t)strlen(names + at) + 1)
        if (!strncmp(names + at, "user.", 5)) ++count;
    return count;
}
#else
int files_test_named_stream_count(const char *path) { (void)path; return -1; }
#endif
int files_test_encrypt(const char *path) { (void)path; return 0; }
int files_test_is_encrypted(const char *path) { (void)path; return 0; }
int files_test_add_inherited_ace(const char *path) { (void)path; return 0; }
int files_test_inherits_ace(const char *path) { (void)path; return 0; }
#endif

/* A FIFO for the non-blocking checks; Windows has none. */
#if defined(_WIN32)
int files_test_make_fifo(const char *path) { (void)path; return -1; }
#else
#include <sys/types.h>
#include <sys/stat.h>
int files_test_make_fifo(const char *path) { return mkfifo(path, 0600); }
#endif
