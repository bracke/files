--  The path operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Path is

   --  Normalize an existing filesystem path to a directory path.
   --
   --  @param Path Path supplied by a user or command line.
   --  @return Path validation result and normalized directory path when valid.
   function Normalize_Path
     (Path : String)
      return Path_Result;

   --  Return the parent directory of Path.
   --
   --  @param Path Directory path whose parent is requested.
   --  @return Parent directory path, or an empty string when Path is a
   --    filesystem root (or otherwise has no parent).
   function Parent_Directory
     (Path : String)
      return String;

   --  Join a parent directory path and a simple child name.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Child name.
   --  @return Joined path using the host directory separator.
   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String;

   --  Return whether Name is a safe leaf filename for create or rename.
   --
   --  @param Name Candidate filename without parent path components.
   --  @return True when Name can be used as a direct child filename.
   function Valid_Leaf_Name
     (Name : String)
      return Boolean;

   --  Return a deterministic available untitled file name in Directory_Path.
   --
   --  @param Directory_Path Directory to inspect.
   --  @return Available name such as untitled.txt or untitled 2.txt.
   function Next_Untitled_Name
     (Directory_Path : String)
      return String;

end Files.File_System.Path;
