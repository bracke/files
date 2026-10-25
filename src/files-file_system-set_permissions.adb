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
      when others =>
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
   elsif Hostkit.Metadata.Set_Permissions (Path, Mode) then
      return (Success => True, Error_Key => Null_Unbounded_String);
   else
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.failed"));
   end if;
exception
   when others =>
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permissions.failed"));
end Set_Permissions;
