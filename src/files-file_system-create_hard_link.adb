separate (Files.File_System)
   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
   is
      Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
   begin
      if Source_Path = ""
        or else not Ada.Directories.Exists (Source_Path)
        or else Ada.Directories.Kind (Source_Path) = Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Validation.Success then
         return Validation;
      elsif Files.Platform.Metadata.Create_Hard_Link (Source_Path, Link_Path) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
   end Create_Hard_Link;
