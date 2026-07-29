with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Interfaces.C;

--  Shared low-level helpers of Files.File_System (safe close / end-search,
--  environment access, small text formatting), extracted so the concern
--  children and the parent can all use them. A private child.
private package Files.File_System.Support is

   --  End a directory search, swallowing any exception and doing nothing when
   --  it was never started; Started is reset to False.
   --
   --  @param Search The directory search to end.
   --  @param Started Whether Search was started; set to False.
   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean);

   --  Close a text file if it is open, ignoring any error from the close.
   --
   --  @param File The text file to close.
   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   --  Close a stream file if it is open, ignoring any error from the close.
   --
   --  @param File The stream file to close.
   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type);

   --  The value of environment variable Name, or "" when it is unset or cannot
   --  be read.
   --
   --  @param Name Environment variable name.
   --  @return Its value, or "" when unset/unreadable.
   function Safe_Environment_Value
     (Name : String)
      return String;

   --  Whether environment variable Name equals Expected, compared
   --  case-insensitively.
   --
   --  @param Name Environment variable name.
   --  @param Expected Value to compare against.
   --  @return True when the variable's value equals Expected.
   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

   --  Natural'Image with the leading space GNAT prefixes to a non-negative
   --  number stripped.
   --
   --  @param Value Number to format.
   --  @return Value's decimal text, without a leading space.
   function Image_No_Space (Value : Natural) return String;

   --  Whether Value begins with Prefix.
   --
   --  @param Value String to test.
   --  @param Prefix Candidate leading substring.
   --  @return True when Value starts with Prefix.
   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean;

   --  Decimal text of Value: Natural'Image with the leading space guarded off.
   --
   --  @param Value Number to format.
   --  @return Value's decimal text, without a leading space.
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

   --  Recursively delete a file, directory, or symlink. A symlink -- even one
   --  whose target is a directory -- is unlinked as a link and never followed,
   --  so deleting a link (or a folder that merely contains one) can never
   --  reach through into the link target's real contents. This is the safe
   --  replacement for Ada.Directories.Delete_Tree, which follows links; it
   --  mirrors Copy_Tree's link handling.
   --
   --  @param Path File, directory, or symlink to remove.
   procedure Delete_Tree (Path : String);

   --  Shared Interfaces.C aliases for the native (statvfs / gdk-pixbuf) bindings.
   subtype C_Int is Interfaces.C.int;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;
   subtype C_Size is Interfaces.C.size_t;
   subtype C_ULong is Interfaces.C.unsigned_long;
   subtype C_Char is Interfaces.C.char;
   type U64_Array is array (Positive range <>) of C_U64
     with Convention => C;

end Files.File_System.Support;
