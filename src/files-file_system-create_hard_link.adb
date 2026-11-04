separate (Files.File_System)
function Create_Hard_Link
  (Source_Path : String;
   Link_Path   : String)
   return Mutation_Result
is
   Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
begin
   if Source_Path = ""
     or else (not Hostkit.Fs.Is_Link (Source_Path)
       and then (not Ada.Directories.Exists (Source_Path)
         or else Ada.Directories.Kind (Source_Path) = Ada.Directories.Directory))
   then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.link.failed"));
   elsif not Validation.Success then
      return Validation;
   end if;
   --  A full disk, a refused permission or a read-only volume is said as
   --  such, not as the generic failure.
   Files.Io_Errors.Reset;
   Files.Io_Errors.Clear_Os_Error;
   if Hostkit.Fs.Create_Hard_Link (Source_Path, Link_Path) then
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;
   Files.Io_Errors.Capture;
   return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.link.failed"));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.link.failed"));
end Create_Hard_Link;
