separate (Files.File_System)
   function Create_Empty_File
     (Path : String)
      return Mutation_Result
   is
      File    : Ada.Text_IO.File_Type;
      Created : Boolean := False;

      procedure Delete_Created_File_If_Present is
      begin
         if Created
           and then Files.Fs.File_Exists (Path)
         then
            Ada.Directories.Delete_File (Path);
         end if;
      exception
         when others =>
            null;
      end Delete_Created_File_If_Present;

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

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Created := True;
      Ada.Text_IO.Close (File);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         Delete_Created_File_If_Present;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Empty_File;
