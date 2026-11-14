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
      Removed : Boolean := False;
   begin
      begin
         Support.Delete_Owned_Tree (To_String (Backup));
         Removed := True;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end;
      if not Removed then
         declare
            Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
            pragma Unreferenced (Restored);
         begin
            return Failed;
         end;
      end if;
   end;
   declare
      Stage : constant String := Files.Fs_Primitives.Parent_Directory (To_String (Backup));
      Removed : constant Mutation_Result := Delete_Permanently (Stage);
      pragma Unreferenced (Removed);
   begin
      --  Preserve registered the backup; once its stage is gone the record
      --  would otherwise leak and slowly exhaust the registry.
      if Files.Fs_Primitives.Entry_Is_Absent (Stage) then
         Recovery.Unregister (To_String (Backup));
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Failed;
end Delete_Verified_Entry;
