with Ada.Calendar;

--  Per-OS native filesystem metadata syscalls.
--
--  This package isolates the Linux-only system calls (statx, readlink,
--  statvfs) behind a neutral contract so that the shared file-system code no
--  longer references platform-specific symbols. Bodies are provided per OS;
--  non-Linux bodies are safe stubs that report no metadata.
package Files.Platform.Metadata is

   --  Neutral volume-capacity result, independent of Files.File_System types.
   --
   --  All byte and inode counts are saturating: values that exceed the host
   --  range are clamped to the corresponding 'Last. Boolean *_Known fields
   --  indicate whether the matching value was actually obtained.
   type Volume_Capacity is record
      Available        : Boolean := False;
      Capacity_Bytes   : Long_Long_Integer := 0;
      Free_Bytes       : Long_Long_Integer := 0;
      Inode_Count      : Long_Long_Integer := 0;
      Free_Inode_Count : Long_Long_Integer := 0;
      Name_Max         : Natural := 0;
      Read_Only        : Boolean := False;
      Inodes_Known     : Boolean := False;
      Name_Max_Known   : Boolean := False;
      Read_Only_Known  : Boolean := False;
   end record;

   --  Return the file creation (birth) time for Path.
   --
   --  @param Path Filesystem path to inspect.
   --  @param Available Set True when a creation time was obtained.
   --  @return Birth time when Available, otherwise a sentinel past date.
   function File_Creation_Time
     (Path      : String;
      Available : out Boolean)
      return Ada.Calendar.Time;

   --  Return the symbolic-link target token for Path.
   --
   --  @param Path Symbolic link path to resolve.
   --  @return "symlink.target|<target>" token, or an empty string on failure.
   function Symlink_Target_Token (Path : String) return String;

   --  Return the volume-capacity metadata for the filesystem holding Path.
   --
   --  @param Path Filesystem path located on the volume to query.
   --  @return Neutral capacity record; Available is False when unavailable.
   function Volume_Capacity_Of (Path : String) return Volume_Capacity;

   --  Create a symbolic link at Link_Path pointing at Target.
   --
   --  Target is stored verbatim as the link contents and is not required to
   --  exist. Non-Linux bodies are stubs that report failure.
   --
   --  @param Target Link contents (path the symlink refers to).
   --  @param Link_Path New symbolic link path to create.
   --  @return True when the link was created.
   function Create_Symbolic_Link
     (Target    : String;
      Link_Path : String)
      return Boolean;

   --  Create a hard link at New_Path referring to the same inode as Existing.
   --
   --  Existing must name an existing file. Non-Linux bodies are stubs that
   --  report failure.
   --
   --  @param Existing_Path Existing file to link to.
   --  @param New_Path New hard link path to create.
   --  @return True when the link was created.
   function Create_Hard_Link
     (Existing_Path : String;
      New_Path      : String)
      return Boolean;

   --  Return the POSIX permission bits (the low 12 mode bits: setuid, setgid,
   --  sticky, and the nine rwxrwxrwx bits) for Path.
   --
   --  Non-Linux bodies are stubs that report no metadata (Available => False).
   --
   --  @param Path Filesystem path to inspect.
   --  @param Available Set True when permission bits were obtained.
   --  @return Permission bits in 0 .. 8#7777#, or 0 when Available is False.
   function File_Permission_Bits
     (Path      : String;
      Available : out Boolean)
      return Natural;

   --  Change the POSIX permission bits of Path through chmod(2).
   --
   --  Mode carries the numeric POSIX permission bits (typically the low 12
   --  bits). Non-Linux bodies are stubs that report failure.
   --
   --  @param Path Filesystem path whose mode is changed.
   --  @param Mode New permission bits to apply.
   --  @return True when the mode was changed.
   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Boolean;

   --  Return whether this platform can read and change permission bits.
   --
   --  @return True on the Linux adapter, False on the stub adapters.
   function Permissions_Supported return Boolean;

end Files.Platform.Metadata;
