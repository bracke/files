separate (Files.File_System)
   function Create_Directory
     (Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Path) then
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

      Ada.Directories.Create_Directory (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Directory;
