with GNAT.OS_Lib;

--  Low-level filesystem helpers used by the files application.
--  These mirror the small subset of filesystem helpers the application
--  relies on, implemented directly on Ada.Directories so
--  the executable carries no external tooling-library runtime dependency.
package Files.Fs is

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

end Files.Fs;
