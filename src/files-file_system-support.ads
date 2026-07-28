with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;

--  Shared low-level helpers of Files.File_System (safe close / end-search,
--  environment access, small text formatting), extracted so the concern
--  children and the parent can all use them. A private child.
private package Files.File_System.Support is

   --  Internal helper: safe end search.
   --
   --  @param Search search.
   --  @param Started started.
   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean);

   --  Internal helper: safe close.
   --
   --  @param File file.
   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   --  Internal helper: safe close.
   --
   --  @param File file.
   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type);

   --  Internal helper: safe environment value.
   --
   --  @param Name name.
   --  @return Result of safe environment value.
   function Safe_Environment_Value
     (Name : String)
      return String;

   --  Internal helper: environment equals.
   --
   --  @param Name name.
   --  @param Expected expected.
   --  @return Result of environment equals.
   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

   --  Internal helper: image no space.
   --
   --  @param Value value.
   --  @return Result of image no space.
   function Image_No_Space (Value : Natural) return String;

   --  Internal helper: starts with.
   --
   --  @param Value value.
   --  @param Prefix prefix.
   --  @return Result of starts with.
   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean;

   --  Internal helper: natural text.
   --
   --  @param Value value.
   --  @return Result of natural text.
   function Natural_Text (Value : Natural) return String;

   --  Recursively copy a file or directory tree from Source_Path to
   --  Destination_Path (Depth guards against symlink cycles). The shared
   --  worker behind the public Copy_Tree function and the cross-device
   --  trash/restore fallbacks.
   --
   --  @param Source_Path Source file or directory.
   --  @param Destination_Path Destination path to create.
   --  @param Depth Current recursion depth (0 at the top).
   procedure Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural := 0);

end Files.File_System.Support;
