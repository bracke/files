separate (Files.File_System)
function Delete_Transport_Entry
  (Path : String; Expected_Identity : String) return Mutation_Result
is
   --  A transport is removed for good, never trashed: its failure is a
   --  permanent delete that did not happen.
   Failed : constant Mutation_Result :=
     (Success => False, Error_Key => To_Unbounded_String ("error.permanent_delete.failed"));
begin
   if Expected_Identity = ""
     or else Hostkit.Fs.Is_Link (Path)
     or else Files.File_Identities.Token (Path) /= Expected_Identity
   then
      return Failed;
   end if;
   Support.Delete_Owned_Tree (Path);
   if Files.Fs_Primitives.Entry_Exists (Path) then
      return Failed;
   end if;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Failed;
end Delete_Transport_Entry;
