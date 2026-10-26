with GNAT.OS_Lib;

--  Low-level filesystem primitives shared across the application: existence
--  and kind probes, no-follow regular-file opens, and a no-follow tree delete,
--  implemented on Ada.Directories and Hostkit. Files.File_System builds the
--  listing and metadata layer on these, but startup, fonts, operations, jobs,
--  and capped reads use them directly too, so they are a public unit rather
--  than a private child of Files.File_System.
package Files.Fs_Primitives is

   --  Whether Path is fit to hand to a helper or write into a record: not
   --  empty, at most Max_Length bytes, no NUL, absolute. One rule, so the
   --  job transports' checks cannot drift apart.
   --
   --  @param Path Candidate path.
   --  @param Max_Length The record's bound.
   --  @return True when Path is such a path.
   function Valid_Absolute_Path (Path : String; Max_Length : Natural := Natural'Last) return Boolean;

   --  @param Path Filesystem path to test.
   --  @return True when Path exists (file or directory).
   function Exists (Path : String) return Boolean;

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
