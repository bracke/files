with Zlib;

--  Archive writers that preserve selected directory entries as well as files.
package Files.Archive_Writing is
   --  Whether every entry name in Entries can be extracted without escaping
   --  the destination or overwriting another entry.
   --
   --  @param Entries Catalogue returned by Zlib before extraction.
   --  @param Dos_Rules Whether each name segment must be one Windows can
   --    store (a FAT, exFAT or NTFS destination): no device names such as nul
   --    or aux.c, no trailing dot or space, none of \ : < > " | ? *.
   --  @param Case_Insensitive Whether two files whose names differ only in
   --    case would land on the same file there, and so count as duplicates.
   --  @return True when no name is unsafe, unstorable or a duplicate.
   function Names_Are_Extractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return Boolean;

   --  Check that an archive catalogue can be extracted without exhausting the
   --  destination volume or crossing the application's structural limits.
   --  Unknown volume figures still receive conservative absolute and expansion
   --  bounds.  Known figures retain headroom for the running system.
   --
   --  @param Entries Catalogue returned by Zlib before extraction.
   --  @param Free_Bytes Bytes currently available on the destination volume.
   --  @param Free_Bytes_Known True when Free_Bytes is authoritative.
   --  @param Free_Inodes Inodes currently available on the destination volume.
   --  @param Free_Inodes_Known True when Free_Inodes is authoritative.
   --  @param Destination Folder the entries are extracted into, or "" when
   --    unknown. On a DOS-rules filesystem (FAT, exFAT, NTFS) every name
   --    segment must be one Windows can store -- no device names such as nul
   --    or aux.c, no trailing dot -- and on a case-insensitive one (those, and
   --    macOS volumes) two files whose names differ only in case would
   --    overwrite each other, so they count as duplicates.
   --  @return True only when every resource bound is satisfied.
   function Extraction_Is_Within_Limits
     (Entries            : Zlib.Archive_Entry_Array;
      Free_Bytes         : Long_Long_Integer;
      Free_Bytes_Known   : Boolean;
      Free_Inodes        : Long_Long_Integer;
      Free_Inodes_Known  : Boolean;
      Destination        : String := "") return Boolean;

   --  Whether an archive entry name can be stored: ZIP and 7z entry names use
   --  '/' as their only separator and readers treat '\' and ':' as path
   --  syntax, so names holding those (valid on POSIX) are refused.
   --
   --  @param Name Relative entry name, '/'-separated.
   --  @return True when no component holds a backslash, colon or NUL.
   function Portable_Entry_Name (Name : String) return Boolean is
     (for all C of Name => C not in ASCII.NUL | '\' | ':');

   --  @param Input_Paths Source files and directories, without following links.
   --  @param Output_Path Staged output archive, published by the caller.
   --  @param Entry_Names Distinct relative names parallel to Input_Paths.
   --  @param Status Ok only when every source has been included.
   procedure ZIP_Files
     (Input_Paths : Zlib.Text_Array;
      Output_Path : String;
      Entry_Names : Zlib.Text_Array;
      Status : out Zlib.Status_Code);
end Files.Archive_Writing;
