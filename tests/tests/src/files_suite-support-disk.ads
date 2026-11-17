
--  The suite's on-disk fixtures: the scratch root, files written and read
--  byte for byte, links, access the host refuses, and the companion
--  executables the open and launch tests run.
package Files_Suite.Support.Disk is

   --  The scratch directory every fixture builds under.
   --
   --  This is deliberately not a hardcoded "/tmp/...": on macOS /tmp is a
   --  symlink into /private, so the application's canonicalised paths never
   --  string-compare equal to a path spelled through it, and Windows has no /tmp
   --  at all. Test_Root resolves the platform's real temporary directory,
   --  following links, so a path built here matches the one the model reports.
   --  A function, not a constant: a spec-level constant cannot call into the
   --  body before that body is elaborated.
   --  @return the resolved, link-followed scratch directory path
   function Root return String;

   --  Does a mode bit decide what runs here? On POSIX, yes: chmod +x makes a file
   --  executable whatever it is called. Windows decides from the extension alone
   --  -- every ordinary file carries FILE_EXECUTE in its DACL, so the bit says
   --  nothing -- and GNAT.OS_Lib.Set_Executable is a no-op there.
   --
   --  So "run.sh, chmod +x" is an executable on POSIX and a plain file on Windows,
   --  and that is the product being right on both, not a gap. Tests that make a
   --  file executable branch on this; the ones that want an executable on Windows
   --  name it .bat.
   --  @return True on hosts where the executable mode bit governs execution
   function Honours_Executable_Bit return Boolean;

   --  A real executable that succeeds and does nothing, for tests that need an
   --  action to actually run. It is NOT /bin/true everywhere: macOS has no
   --  /bin/true at all -- true lives in /usr/bin there -- so the path is probed
   --  rather than assumed.
   --  @return an absolute path to an executable that exits 0 and does nothing
   function No_Op_Executable return String;

   --  Does this path exist? False, rather than an exception, for a name the host
   --  cannot even represent.
   --
   --  Ada.Directories.Exists raises Name_Error on Windows for a name containing
   --  ':' or '\\', which are ordinary characters on POSIX. Tests that check an
   --  invalid name was REFUSED then ask whether the file exists -- and a path the
   --  operating system cannot name certainly does not.
   --  @param Path the path to test
   --  @return True when Path exists; False for a name the host cannot represent
   function Path_Exists (Path : String) return Boolean;

   --  The root of the filesystem the scratch root lives on: "/" on POSIX, and the
   --  drive -- "C:\" -- on Windows, where "/" is not a root at all.
   --  @return the filesystem root containing the scratch root
   function Filesystem_Root return String;

   --  A real executable that fails, for tests that check a non-zero exit is not
   --  surfaced. Like true, false lives in /usr/bin on macOS, not /bin.
   --  @return an absolute path to an executable that exits non-zero
   function Failing_Executable return String;

   --  A real executable that records having run, by creating the file named as its
   --  first argument. Lets a test prove an action did not merely *report* that it
   --  was never launched, but genuinely never ran.
   --  @return an absolute path to an executable that creates its first argument
   function Marker_Executable return String;

   --  True when the filesystem under Root treats "A.txt" and "a.txt" as the same
   --  file, as macOS does by default. Fixtures that rely on both existing at once
   --  cannot be built there, and must say so rather than quietly measure the
   --  wrong thing.
   --  @return True when the filesystem under Root is case-insensitive
   function Case_Insensitive_Filesystem return Boolean;

   --  Create a symbolic link.
   --
   --  @param Target Path the link points to.
   --  @param Linkpath Path of the link to create.
   --  @return True when the link was created.
   function Create_Symlink (Target : String; Linkpath : String) return Boolean;

   --  The kinds of link a fixture makes.
   type Link_Kind is (Symbolic_Link, Hard_Link);

   --  Report that Test could not make the link its fixture needs, instead of
   --  passing without checking anything. On Linux both kinds of link always
   --  work in the test root, so there it is a failure. Elsewhere it is a
   --  recorded skip -- a symbolic link is a privilege on Windows (Developer
   --  Mode or the create-symbolic-link right), and a file another handle holds
   --  may refuse a second name there -- which CI's per-host skip ceiling still
   --  turns red if it starts happening.
   --
   --  @param Test The test routine.
   --  @param Kind The link that could not be made.
   procedure Link_Not_Made (Test : String; Kind : Link_Kind := Symbolic_Link);

   --  Delete and recreate the temporary test root directory.
   procedure Reset_Root;

   --  Make Path one its owner cannot delete, where locking its folder alone
   --  does not stop that. On POSIX a mode-555 folder refuses every unlink in
   --  it, so this does nothing there. On Windows deleting needs DELETE on the
   --  entry itself or FILE_DELETE_CHILD on its folder, and an entry made
   --  before its folder was locked keeps DELETE through the ACE it inherited;
   --  there Path's own DACL is made read-only (444, 555 for a folder), which
   --  binds an elevated process too. Allow_Deletion undoes it.
   --
   --  @param Path An existing file or folder.
   procedure Forbid_Deletion (Path : String);

   --  Path's access as the host reports it, for a failure message: icacls'
   --  listing on Windows, "" elsewhere.
   --
   --  @param Path An existing file or folder.
   --  @param Tree Whether to list everything under Path as well.
   --  @return The listing.
   function Access_Report (Path : String; Tree : Boolean := False) return String;

   --  Give Path's owner write and delete access back after Forbid_Deletion
   --  (644, 755 for a folder). Nothing on POSIX, nor when nothing is there.
   --
   --  @param Path A file or folder Forbid_Deletion was given.
   procedure Allow_Deletion (Path : String);

   --  Create or replace a text file holding Content and a line terminator
   --  after it (Text_IO closes the line): "x" is written as "x" & LF, or
   --  "x" & CR & LF on Windows. Check it with File_Has_Bytes, not File_Is; a
   --  test that needs the exact bytes writes them with Write_Binary_File.
   --
   --  @param Path File to create.
   --  @param Content Text to write.
   procedure Write_File (Path : String; Content : String := "x");

   --  Create or replace a file with byte-for-byte Content, through
   --  Hostkit.Fs.Create_Stream, which reaches past Windows' 260-character
   --  path limit where GNAT's own file calls stop.
   --
   --  @param Path File to create.
   --  @param Content Raw bytes represented as String characters.
   procedure Write_Binary_File (Path : String; Content : String);

   --  Does the file hold this exact byte sequence anywhere in it?
   --
   --  Byte-exact, so it works on binary artifacts that a line- and
   --  encoding-aware text search cannot read: the thumbnail cache is binary P6,
   --  where a pixel is three raw bytes rather than three ASCII numbers.
   --
   --  @param Path File to search.
   --  @param Bytes Sequence to look for, one Character per byte.
   --  @return True when the sequence appears; False when nothing (or a
   --  folder) is at Path. A file that cannot be read raises.
   function File_Has_Bytes (Path : String; Bytes : String) return Boolean;

   --  Does the file hold exactly these bytes, and nothing else? Read through
   --  Hostkit.Fs.Open_Stream, past Windows' path limit. Where a test
   --  knows a file's whole content, this is the check: File_Has_Bytes also
   --  passes for an append instead of a truncate, or a torn replace that left
   --  old and new together.
   --
   --  @param Path File to read.
   --  @param Bytes Its whole expected content, one Character per byte.
   --  @return True when the file exists and holds exactly Bytes; False when
   --  nothing (or a folder) is at Path. A file that cannot be read raises.
   function File_Is (Path : String; Bytes : String) return Boolean;

   --  Create a file of Filler_Count copies of one byte followed by Trailer,
   --  written in chunks so the caller need not build a multi-megabyte String.
   --  For exercising the metadata readers' byte-scan caps, which only engage on
   --  files larger than several megabytes.
   --
   --  @param Path File to create.
   --  @param Filler Byte repeated Filler_Count times.
   --  @param Filler_Count How many copies of Filler to write first.
   --  @param Trailer Bytes written after the filler run.
   procedure Write_Filler_File
     (Path         : String;
      Filler       : Character;
      Filler_Count : Natural;
      Trailer      : String := "");

   --  Join a parent directory and a name into a path.
   --
   --  @param Parent Parent directory path.
   --  @param Name Entry name to append.
   --  @return The joined path.
   function Join (Parent : String; Name : String) return String;

   --  The N-th file of a numbered paste fixture (Arm_Numbered_Paste).
   --
   --  @param Directory Directory the fixture's files are in.
   --  @param N Number of the file.
   --  @return The path of "f<N>.txt" in Directory.
   function Numbered_File (Directory : String; N : Positive) return String;

end Files_Suite.Support.Disk;
