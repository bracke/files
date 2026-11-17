separate (Files.File_System)
function Delete_Verified_Entry
  (Path : String;
   Expected_Identity, Expected_Tree_Revision : String;
   Verify_Tree : Boolean) return Mutation_Result
is
   Backup : UString;
   Failed : constant Mutation_Result :=
     (Success => False, Error_Key => To_Unbounded_String ("error.undo.failed"));
begin
   if Expected_Identity = "" or else Files.File_Identities.Token (Path) /= Expected_Identity then
      return Failed;
   end if;
   if Verify_Tree and then not Hostkit.Fs.Is_Link (Path)
     and then (Expected_Tree_Revision = "" or else Tree_Revision (Path) /= Expected_Tree_Revision)
   then
      return Failed;
   end if;
   if not Recovery.Preserve (Path, Backup).Success then
      return Failed;
   end if;
   --  Verify after the atomic rename as well: an entry substituted between
   --  the first check and quarantine must never have its contents deleted.
   if Files.File_Identities.Token (To_String (Backup)) /= Expected_Identity then
      declare
         Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
         pragma Unreferenced (Restored);
      begin
         return Failed;
      end;
   end if;
   if Verify_Tree and then not Hostkit.Fs.Is_Link (To_String (Backup))
     and then Tree_Revision (To_String (Backup)) /= Expected_Tree_Revision
   then
      declare
         Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
         pragma Unreferenced (Restored);
      begin
         return Failed;
      end;
   end if;
   declare
      --  The verified entry is removed from its stage, marked first
      --  (Recovery.Vacate), so a stop part way leaves a stage the sweep
      --  finishes; the stage and its record go once it has.
      function Remove_Payload return Boolean is
      begin
         Support.Delete_Owned_Tree (To_String (Backup));
         return True;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
            return False;
      end Remove_Payload;

      Ran : Boolean;
   begin
      if Recovery.Vacate (To_String (Backup), Remove_Payload'Access, Ran) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      elsif not Ran
        or else (Files.File_Identities.Token (To_String (Backup)) = Expected_Identity
                 and then (not Verify_Tree or else Hostkit.Fs.Is_Link (To_String (Backup))
                           or else Tree_Revision (To_String (Backup)) = Expected_Tree_Revision))
      then
         --  Nothing was removed (it is still the entry, content and all):
         --  it goes back whole.
         declare
            Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
            pragma Unreferenced (Restored);
         begin
            return Failed;
         end;
      end if;
      --  Removed part way: what is left is no longer the entry, so it is
      --  not put back under its name as if it were. It stays in its
      --  registered stage, listed among the recoveries.
      return Failed;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Failed;
end Delete_Verified_Entry;
