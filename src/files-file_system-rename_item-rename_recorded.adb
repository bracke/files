separate (Files.File_System.Rename_Item)
function Rename_Recorded return Mutation_Result is
   Backup : UString;
   Failed : constant Mutation_Result :=
     (Success => False, Error_Key => To_Unbounded_String ("error.rename.failed"));
   Committed : Boolean := False;

   --  Failed, or the cause Step was refused for when one is known.
   function Failed_By (Step : Mutation_Result) return Mutation_Result is
     (if Files.IO.Errors.Is_Cause_Key (Step.Error_Key) then Step else Failed);

   procedure Restore_Source is
      Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
      pragma Unreferenced (Restored);
   begin
      null;
   end Restore_Source;
begin
   if Files.File_Identities.Token (From_Path) /= Expected_Identity then
      return Failed;
   end if;
   if Same_Existing_Path then
      return (Success => True, Error_Key => Null_Unbounded_String);
   end if;
   declare
      Preserved : constant Mutation_Result := Recovery.Preserve (From_Path, Backup);
   begin
      if not Preserved.Success then
         return Failed_By (Preserved);
      end if;
   end;
   --  The source is now private. A substituted entry must be restored,
   --  never moved to the history target or deleted by a copy fallback.
   if Files.File_Identities.Token (To_String (Backup)) /= Expected_Identity then
      Restore_Source;
      return Failed;
   end if;
   declare
      Renamed : Mutation_Result := Failed;

      --  The payload leaves its stage for the history target, the stage
      --  marked first (Recovery.Vacate): a stop now leaves a stage the
      --  sweep finishes, not one kept for good.
      function Move_Out return Boolean is
      begin
         Renamed := Rename_Item (To_String (Backup), To_Path);
         return Renamed.Success;
      end Move_Out;

      Ran : Boolean;
   begin
      if not Recovery.Vacate (To_String (Backup), Move_Out'Access, Ran) then
         Restore_Source;
         return Failed_By (Renamed);
      end if;
   end;
   Committed := True;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      if not Committed and then Length (Backup) > 0 then
         Restore_Source;
      end if;
      return (Success => Committed,
              Error_Key => (if Committed then Null_Unbounded_String else Failed.Error_Key));
end Rename_Recorded;
