separate (Files.File_System)
   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
   is
      function Exists_Safely (Candidate : String) return Boolean is
      begin
         return Candidate /= "" and then Files.Fs.Exists (Candidate);
      exception
         when others =>
            return False;
      end Exists_Safely;
   begin
      if not Files.Platform.Metadata.Ownership_Supported then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.unsupported"));
      elsif not Exists_Safely (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      elsif Files.Platform.Metadata.Set_Ownership (Path, User_Id, Group_Id) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
   end Set_Ownership;
