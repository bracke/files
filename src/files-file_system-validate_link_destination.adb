separate (Files.File_System)
   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Link_Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Link_Path);
   begin
      if Link_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Link_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Validate_Link_Destination;
