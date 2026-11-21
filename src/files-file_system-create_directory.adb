separate (Files.File_System)
function Create_Directory
  (Path : String)
   return Mutation_Result
is
begin
   Files.IO.Errors.Reset;
   declare
      Checked : constant Mutation_Result := Validate_New_Entry (Path, "error.file.parent_missing");
   begin
      if not Checked.Success then
         return Checked;
      end if;
   end;

   begin
      Files.IO.Errors.Clear_Os_Error;
      Files.IO.Fs_Primitives.Create_Directory (Path);
   exception
      when others =>
         Files.IO.Errors.Capture;
         raise;
   end;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => Files.IO.Errors.Error_Key ("error.file.create"));
end Create_Directory;
