separate (Files.File_System)
function Set_Permissions
  (Path : String;
   Mode : Natural)
   return Mutation_Result
is
   function Exists_Safely (Candidate : String) return Boolean is
   begin
      return Candidate /= "" and then Files.Fs_Primitives.Exists (Candidate);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Exists_Safely;
begin
   if not Hostkit.Metadata.Permissions_Supported then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.unsupported"));
   elsif Mode > 8#7777# then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.failed"));
   elsif not Exists_Safely (Path) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.failed"));
   end if;
   --  A full disk, a refused permission or a read-only volume is said as
   --  such, not as the generic failure.
   Files.Io_Errors.Reset;
   Files.Io_Errors.Clear_Os_Error;
   if Hostkit.Metadata.Set_Permissions (Path, Mode) then
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;
   Files.Io_Errors.Capture;
   return (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.permissions.failed"));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.failed"));
end Set_Permissions;
