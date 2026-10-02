#define _GNU_SOURCE
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct files_identity {
    uint64_t volume, number, birth_seconds, birth_nanoseconds;
};

int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, const char *owner_name,
    const char *group_name, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity);

#if defined(__linux__) || defined(__APPLE__)
#include <sys/stat.h>
#include <fcntl.h>
#include <limits.h>
#include <unistd.h>
#ifdef __APPLE__
static int files_fchmod_evtonly(int fd, unsigned long value) {
    char held[64];
    snprintf(held, sizeof(held), "/dev/fd/%d", fd);
    return chmod(held, value & 07777) == 0;
}

static int files_fchmod_link(const char *path, const char *expected,
                             unsigned long value, uint64_t *previous,
                             struct files_identity *identity) {
    char parent[PATH_MAX];
    char private_dir[PATH_MAX];
    const char *slash = strrchr(path, '/');
    size_t parent_length = slash ? (size_t)(slash - path) : 0;
    if (!slash) {
        strcpy(parent, ".");
    } else if (parent_length == 0) {
        strcpy(parent, "/");
    } else {
        if (parent_length >= sizeof(parent)) return 0;
        memcpy(parent, path, parent_length);
        parent[parent_length] = '\0';
    }
    if (snprintf(private_dir, sizeof(private_dir),
                 "%s/.files-mode-XXXXXX", parent) >= (int)sizeof(private_dir)
        || !mkdtemp(private_dir)) return 0;

    int directory = open(private_dir, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    int linked = directory >= 0
        && linkat(AT_FDCWD, path, directory, "inode", 0) == 0;
    struct stat info;
    int matches = linked
        && fstatat(directory, "inode", &info, AT_SYMLINK_NOFOLLOW) == 0
        && !S_ISLNK(info.st_mode);
    char token[128];
    if (matches) {
        identity->volume = info.st_dev;
        identity->number = info.st_ino;
        identity->birth_seconds = info.st_birthtimespec.tv_sec;
        identity->birth_nanoseconds = info.st_birthtimespec.tv_nsec;
        snprintf(token, sizeof(token), " %llu %llu %llu %llu",
            (unsigned long long)identity->volume,
            (unsigned long long)identity->number,
            (unsigned long long)identity->birth_seconds,
            (unsigned long long)identity->birth_nanoseconds);
        matches = !*expected || strcmp(expected, token) == 0;
    }
    if (matches) *previous = info.st_mode & 07777;
    int ok = matches && fchmodat(directory, "inode", value & 07777, 0) == 0;
    int saved_errno = errno;
    if (linked) unlinkat(directory, "inode", 0);
    if (directory >= 0) close(directory);
    rmdir(private_dir);
    errno = saved_errno;
    return ok;
}
#endif

int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, const char *owner_name,
    const char *group_name, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity) {
    (void)owner_name;
    (void)group_name;
#ifdef __linux__
    int fd = open(path, O_PATH | O_NOFOLLOW | O_CLOEXEC);
#else
    int fd = open(path, O_EVTONLY | O_NOFOLLOW | O_CLOEXEC);
#endif
    if (fd < 0) {
#ifdef __APPLE__
        /* A normal process cannot opt into permission-independent O_EVTONLY
           descriptors: Darwin reserves that policy for privately entitled
           processes.  A mode-000 regular file can still be pinned without a
           pathname race by creating a hard link inside a private same-volume
           directory, verifying the linked inode, and changing it there. */
        if (!ownership
            && files_fchmod_link(path, expected, value, previous, identity)) {
            *previous_group = 0;
            return 1;
        }
#endif
        return 0;
    }
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
        if (ownership) {
            ok = fchown(fd, value, group) == 0;
        } else {
            /* APFS can reject fchmod on the O_EVTONLY descriptor needed to
               reopen a mode-000 file.  Darwin resolves OP_SETATTR lookups on
               /dev/fd back to the held vnode, retaining the identity binding. */
            if (fchmod(fd, value & 07777) == 0) {
                ok = 1;
            } else {
                ok = files_fchmod_evtonly(fd, value)
                    || files_fchmod_link(path, expected, value, previous, identity);
            }
        }
#endif
    }
    close(fd);
    return ok;
}
#elif defined(_WIN32)
#if !defined(_WIN32_WINNT) || _WIN32_WINNT < 0x0602
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0602
#endif
#include <windows.h>
#include <aclapi.h>
#include <stdlib.h>
#include <wchar.h>

static wchar_t *wide_text(const char *text) {
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                    text, -1, NULL, 0);
    if (!count) return NULL;
    wchar_t *result = malloc((size_t)count * sizeof(wchar_t));
    if (!result) return NULL;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                             text, -1, result, count)) {
        free(result);
        return NULL;
    }
    return result;
}

static int valid_file_id(const FILE_ID_INFO *id) {
    int nonzero = 0, not_all_ones = 0;
    for (size_t i = 0; i < sizeof(id->FileId.Identifier); ++i) {
        nonzero |= id->FileId.Identifier[i];
        not_all_ones |= id->FileId.Identifier[i] != 0xff;
    }
    return nonzero && not_all_ones;
}

static int identity_from_handle(HANDLE file, struct files_identity *identity,
                                BY_HANDLE_FILE_INFORMATION *information) {
    FILE_ID_INFO id;
    if (!GetFileInformationByHandle(file, information)) return 0;
    if (GetFileInformationByHandleEx(file, FileIdInfo, &id, sizeof(id))
        && valid_file_id(&id)) {
        identity->volume = id.VolumeSerialNumber;
        memcpy(&identity->number, id.FileId.Identifier, sizeof(uint64_t));
        memcpy(&identity->birth_seconds,
               id.FileId.Identifier + sizeof(uint64_t), sizeof(uint64_t));
        /* A Windows file ID already identifies the entry.  NTFS may rewrite
           creation time while renaming it, which must not change the token. */
        identity->birth_nanoseconds = 0;
        return 1;
    }
    wchar_t file_system[16];
    if (!GetVolumeInformationByHandleW(file, NULL, 0, NULL, NULL, NULL,
                                       file_system,
                                       sizeof(file_system) / sizeof(file_system[0]))
        || _wcsicmp(file_system, L"NTFS") != 0) return 0;
    uint64_t number = ((uint64_t)information->nFileIndexHigh << 32)
        | information->nFileIndexLow;
    if (!number || number == UINT64_MAX) return 0;
    identity->volume = information->dwVolumeSerialNumber;
    identity->number = number;
    identity->birth_seconds = 0;
    identity->birth_nanoseconds = 0;
    return 1;
}

static unsigned long sid_identity(PSID sid) {
    if (!sid || !IsValidSid(sid)) return 0;
    PUCHAR count = GetSidSubAuthorityCount(sid);
    if (!count || !*count) return 0;
    return *GetSidSubAuthority(sid, (DWORD)(*count - 1));
}

static unsigned long rights_to_triplet(ACCESS_MASK rights) {
    unsigned long result = 0;
    if (rights & FILE_READ_DATA) result |= 4;
    if (rights & FILE_WRITE_DATA) result |= 2;
    if (rights & FILE_EXECUTE) result |= 1;
    return result;
}

static ACCESS_MASK triplet_to_rights(unsigned long triplet) {
    ACCESS_MASK result = 0;
    if (triplet & 4) result |= FILE_GENERIC_READ;
    if (triplet & 2) result |= FILE_GENERIC_WRITE | DELETE;
    if (triplet & 1) result |= FILE_GENERIC_EXECUTE;
    return result;
}

static unsigned long rights_for(PACL acl, PSID sid) {
    TRUSTEE_W trustee;
    ACCESS_MASK rights = 0;
    if (!acl || !sid) return 0;
    memset(&trustee, 0, sizeof(trustee));
    BuildTrusteeWithSidW(&trustee, sid);
    return GetEffectiveRightsFromAclW(acl, &trustee, &rights) == ERROR_SUCCESS
        ? rights_to_triplet(rights) : 0;
}

static int runs_on_windows(const char *path) {
    const char *dot = strrchr(path, '.');
    return dot && (!_stricmp(dot, ".exe") || !_stricmp(dot, ".com")
        || !_stricmp(dot, ".bat") || !_stricmp(dot, ".cmd")
        || !_stricmp(dot, ".ps1") || !_stricmp(dot, ".msi"));
}

static PSID account_sid(const char *name, unsigned long expected) {
    wchar_t *wide = wide_text(name);
    DWORD sid_size = 0, domain_size = 0;
    SID_NAME_USE use;
    if (!wide || !*wide) {
        free(wide);
        return NULL;
    }
    LookupAccountNameW(NULL, wide, NULL, &sid_size, NULL, &domain_size, &use);
    if (!sid_size || GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
        free(wide);
        return NULL;
    }
    PSID sid = malloc(sid_size);
    wchar_t *domain = malloc((size_t)domain_size * sizeof(wchar_t));
    if (!sid || (domain_size && !domain)) {
        free(domain);
        free(sid);
        free(wide);
        return NULL;
    }
    if (!LookupAccountNameW(NULL, wide, sid, &sid_size,
                            domain, &domain_size, &use)
        || sid_identity(sid) != expected) {
        free(sid);
        sid = NULL;
    }
    free(domain);
    free(wide);
    return sid;
}

int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, const char *owner_name,
    const char *group_name, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity) {
    int ok = 0;
    wchar_t *name = wide_text(path);
    if (!name) return 0;
    /* FILE_READ_ATTRIBUTES would make a chmod-from-000 impossible even for
       the owner.  Handle information remains queryable through the control
       handle used to update the security descriptor. */
    DWORD access = READ_CONTROL | (ownership ? WRITE_OWNER : WRITE_DAC);
    HANDLE file = CreateFileW(name, access,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    free(name);
    if (file == INVALID_HANDLE_VALUE) return 0;

    BY_HANDLE_FILE_INFORMATION information;
    if (!identity_from_handle(file, identity, &information)
        || (information.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT))
        goto finished;
    char token[128];
    snprintf(token, sizeof(token), " %llu %llu %llu %llu",
        (unsigned long long)identity->volume,
        (unsigned long long)identity->number,
        (unsigned long long)identity->birth_seconds,
        (unsigned long long)identity->birth_nanoseconds);
    if (*expected && strcmp(expected, token)) goto finished;

    PSID owner = NULL, primary_group = NULL;
    PACL dacl = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    if (GetSecurityInfo(file, SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION
                | DACL_SECURITY_INFORMATION,
            &owner, &primary_group, &dacl, NULL, &descriptor) != ERROR_SUCCESS)
        goto finished;

    if (ownership) {
        *previous = sid_identity(owner);
        *previous_group = sid_identity(primary_group);
        /* Background history runs in a fresh helper process, so Hostkit's
           process-local SID/name cache is deliberately absent there.  The
           current descriptor already owns authoritative SIDs for unchanged
           owner/group ids; reuse them instead of requiring a name round-trip. */
        int borrowed_owner = sid_identity(owner) == value;
        int borrowed_group = sid_identity(primary_group) == group;
        PSID new_owner = borrowed_owner ? owner : account_sid(owner_name, value);
        PSID new_group = borrowed_group ? primary_group : account_sid(group_name, group);
        if (new_owner && new_group)
            ok = SetSecurityInfo(file, SE_FILE_OBJECT,
                    OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION,
                    new_owner, new_group, NULL, NULL) == ERROR_SUCCESS;
        if (!borrowed_group) free(new_group);
        if (!borrowed_owner) free(new_owner);
    } else {
        unsigned char everyone_buffer[SECURITY_MAX_SID_SIZE];
        DWORD everyone_size = sizeof(everyone_buffer);
        if (!CreateWellKnownSid(WinWorldSid, NULL, everyone_buffer,
                                &everyone_size)) {
            LocalFree(descriptor);
            goto finished;
        }
        unsigned long mode = rights_for(dacl, owner) * 64
            + rights_for(dacl, primary_group) * 8
            + rights_for(dacl, everyone_buffer);
        if (!runs_on_windows(path)) mode &= ~0111UL;
        *previous = mode;
        *previous_group = 0;

        EXPLICIT_ACCESS_W entries[3];
        memset(entries, 0, sizeof(entries));
        PSID sids[3] = {owner, primary_group, everyone_buffer};
        unsigned long triplets[3] = {(value >> 6) & 7,
                                     (value >> 3) & 7, value & 7};
        for (int index = 0; index < 3; ++index) {
            entries[index].grfAccessPermissions =
                triplet_to_rights(triplets[index]);
            entries[index].grfAccessMode = GRANT_ACCESS;
            entries[index].grfInheritance = NO_INHERITANCE;
            BuildTrusteeWithSidW(&entries[index].Trustee, sids[index]);
        }
        PACL new_acl = NULL;
        if (SetEntriesInAclW(3, entries, NULL, &new_acl) == ERROR_SUCCESS
            && new_acl) {
            ok = SetSecurityInfo(file, SE_FILE_OBJECT,
                    DACL_SECURITY_INFORMATION
                        | PROTECTED_DACL_SECURITY_INFORMATION,
                    NULL, NULL, new_acl, NULL) == ERROR_SUCCESS;
            LocalFree(new_acl);
        }
    }
    LocalFree(descriptor);

finished:
    CloseHandle(file);
    return ok;
}
#else
int files_metadata_update(const char *path, const char *expected, int ownership,
    unsigned long value, unsigned long group, const char *owner_name,
    const char *group_name, uint64_t *previous,
    uint64_t *previous_group, struct files_identity *identity) {
    (void)path; (void)expected; (void)ownership; (void)value; (void)group;
    (void)owner_name; (void)group_name;
    (void)previous; (void)previous_group; (void)identity;
    return -1; /* Use the host's ACL adapter where POSIX descriptors do not apply. */
}
#endif
