with Ada.Strings.Unbounded;

--  Low-level filesystem helpers used by the files application.
--  These mirror the small subset of filesystem/text helpers the application
--  relied on, implemented directly on Ada.Directories and standard text I/O so
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

   --  Recursively delete Path when it exists.
   --  @param Path File or directory tree to remove.
   procedure Delete_Tree (Path : String);

   --  @param Path File path to read.
   --  @return File contents with line-feed separators, or an empty string on
   --          read failure.
   function Read_Text_File (Path : String) return Ada.Strings.Unbounded.Unbounded_String;

end Files.Fs;
