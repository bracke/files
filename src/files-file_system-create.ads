--  The create operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Create is

   --  Create an empty regular file without replacing an existing entry.
   --
   --  @param Path File path to create.
   --  @return Mutation result.
   function Create_Empty_File
     (Path : String)
      return Mutation_Result;

   --  Create a directory without replacing an existing entry.
   --
   --  @param Path Directory path to create.
   --  @return Mutation result.
   function Create_Directory
     (Path : String)
      return Mutation_Result;

   --  Rename a filesystem entry after caller-side validation.
   --
   --  @param From_Path Existing path.
   --  @param To_Path Destination path.
   --  @return Mutation result.
   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result;

   --  Create a symbolic link at Link_Path that refers to Source_Path.
   --
   --  Link_Path must not already exist and its parent directory must exist.
   --  The link stores Source_Path verbatim as its target. Used by the
   --  create-symlink command.
   --
   --  @param Source_Path Existing item the link should point at.
   --  @param Link_Path New symbolic link path to create.
   --  @return Mutation result with a localized error key on failure.
   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result;

   --  Create a hard link at Link_Path that shares Source_Path's inode.
   --
   --  Source_Path must name an existing file, Link_Path must not already exist,
   --  and its parent directory must exist. Used by the create-hard-link command.
   --
   --  @param Source_Path Existing file the link should share an inode with.
   --  @param Link_Path New hard link path to create.
   --  @return Mutation result with a localized error key on failure.
   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result;

end Files.File_System.Create;
