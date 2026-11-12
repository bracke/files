separate (Files.File_System)
function Import_Replacing
  (Source, Destination   : String;
   Mode                  : Drop_Import_Mode;
   Replace               : Boolean;
   Replaced              : out Files.Types.UString;
   Replaced_Identity     : out Files.Types.UString;
   Created_Identity      : out Files.Types.UString;
   Created_Tree_Revision : out Files.Types.UString;
   Preserved             : access procedure (Backup, Backup_Identity : String) := null;
   Cancel                : Cancellation_Check := null;
   Batch                 : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   return Mutation_Result
is
   Plans                      : Drop_Import_Plan_Vectors.Vector;
   Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
   Result                     : Mutation_Result;

   --  The import failed after the original was preserved: put it back, so a
   --  failed replace never loses the entry it was to replace. A failed
   --  restore is the action's failure, and Replaced still names the original.
   procedure Roll_Back is
   begin
      if Length (Replaced) > 0 then
         declare
            Restored : constant Mutation_Result :=
              Restore_From_Trash (To_String (Replaced), To_String (Replaced_Identity), Destination);
         begin
            if Restored.Success then
               Replaced := Null_Unbounded_String;
               Replaced_Identity := Null_Unbounded_String;
            else
               Result := Restored;
            end if;
         end;
      end if;
   end Roll_Back;
begin
   Replaced := Null_Unbounded_String;
   Replaced_Identity := Null_Unbounded_String;
   Created_Identity := Null_Unbounded_String;
   Created_Tree_Revision := Null_Unbounded_String;
   --  A target that vanished since planning leaves nothing to preserve, and
   --  a destination that is the source is the entry being pasted.
   if Replace and then Source /= Destination and then Files.Fs_Primitives.Entry_Exists (Destination) then
      Result := Preserve_For_Replace (Destination, Replaced);
      if Length (Replaced) > 0 then
         Replaced_Identity := To_Unbounded_String (Files.File_Identities.Token (To_String (Replaced)));
         if Preserved /= null then
            Preserved.all (To_String (Replaced), To_String (Replaced_Identity));
         end if;
      end if;
      if not Result.Success then
         --  Nothing was imported; an original still held where Replaced
         --  names stays there for the caller to record.
         return Result;
      end if;
   end if;
   Plans.Append
     (Drop_Import_Plan'
        (Source_Path      => To_Unbounded_String (Source),
         Destination_Path => To_Unbounded_String (Destination),
         Mode             => Mode,
         Valid            => True,
         Error_Key        => Null_Unbounded_String));
   Result := Execute_Drop_Import (Plans, Identities, Tree_Revisions, Cancel, Batch);
   if Result.Success then
      if not Identities.Is_Empty then
         Created_Identity := Identities.First_Element;
         Created_Tree_Revision := Tree_Revisions.First_Element;
      end if;
   else
      Roll_Back;
   end if;
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Result := (Success => False, Error_Key => To_Unbounded_String ("error.drop.failed"));
      Roll_Back;
      return Result;
end Import_Replacing;
