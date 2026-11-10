with GNAT.OS_Lib;

--  Low-level filesystem primitives shared across the application: existence
--  and kind probes, no-follow regular-file opens, and a no-follow tree delete,
--  implemented on Ada.Directories and Hostkit. Files.File_System builds the
--  listing and metadata layer on these, but startup, fonts, operations, jobs,
--  and capped reads use them directly too, so they are a public unit rather
--  than a private child of Files.File_System.
package Files.Fs_Primitives is

   --  @param Path Filesystem path to test.
   --  @return True when Path exists (file or directory).
   function Exists (Path : String) return Boolean;

   --  Whether there is an entry at Path at all: Exists follows a link, so a
   --  dangling one looks absent to it, though the name is taken.
   --
   --  @param Path Filesystem path to test.
   --  @return True when Path exists or is a link (dangling or not); False
   --    for an empty or unreadable path.
   function Entry_Exists (Path : String) return Boolean;

   --  Return the parent directory of Path.
   --
   --  @param Path Path whose parent is requested.
   --  @return Parent directory path, or an empty string when Path is a
   --    filesystem root (or otherwise has no parent).
   function Parent_Directory (Path : String) return String;

   --  The names in a directory, read straight from it: no stat per entry
   --  (Ada.Directories' search makes one), links not followed, a dangling
   --  link included, "." and ".." left out. The directory is closed however
   --  this ends.
   --
   --  @param Path Directory to read.
   --  @param Visit Called per name; setting Stop ends the read there.
   --  @param Name (of Visit) One entry's name.
   --  @param Stop (of Visit) Set to end the read after this name.
   --  @raise Ada.Directories.Use_Error when Path cannot be read, or holds a
   --    name longer than any filesystem stores (64 KiB).
   procedure For_Each_Name
     (Path  : String;
      Visit : not null access procedure (Name : String; Stop : in out Boolean));

   --  Path's last component read from its text alone, for a name
   --  Ada.Directories refuses: GNAT's Windows runtime rejects a component
   --  longer than 256 characters, which the filesystem then refuses with a
   --  cause of its own ("too long"), not as an invalid name.
   --
   --  @param Path A path.
   --  @return Its last component without trailing separators, or "" for a
   --    root or an empty path.
   function Leaf_Text (Path : String) return String;

   --  Path less its last component, read from its text alone (Leaf_Text).
   --
   --  @param Path A path.
   --  @return The parent, keeping a root's separator, or "" when there is none.
   function Parent_Text (Path : String) return String;

   --  @param Path Filesystem path to test.
   --  @return True when Path names an ordinary file.
   function File_Exists (Path : String) return Boolean;

   --  @param Path Filesystem path to test.
   --  @return True when Path names a directory.
   function Directory_Exists (Path : String) return Boolean;

   --  Open the entry currently named by Path only when that entry itself is a
   --  regular file. Symbolic links, reparse points, FIFOs, devices, and
   --  directories are refused without blocking.
   --  @param Path Filesystem path to open without following links.
   --  @return Read-only descriptor, or Invalid_FD when the entry is unsafe or
   --    cannot be opened.
   function Open_Regular_Read
     (Path : String) return GNAT.OS_Lib.File_Descriptor;

   --  As Open_Regular_Read, but permit the final path to be a symbolic link
   --  when its resolved target is a regular file. The target is still opened
   --  nonblocking and verified through the returned handle.
   --  @param Path Filesystem path to resolve and open.
   --  @return Read-only descriptor, or Invalid_FD on refusal or failure.
   function Open_Regular_Read_Following_Links
     (Path : String) return GNAT.OS_Lib.File_Descriptor;

   --  Recursively delete Path when it exists, without following symbolic links
   --  or directory reparse points encountered anywhere in the tree.
   --  @param Path File or directory tree to remove.
   procedure Delete_Tree (Path : String);

end Files.Fs_Primitives;
