with Files.Model.Recent;
with Files.File_System.Trash;
with Files.Items;

separate (Files.Operations.Trash)
function Delete_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items      : constant Files.Items.Item_Vectors.Vector := Files.Model.Selection.Selected_Items (Model);
   First_Path : Unbounded_String;
   --  The trashed items (From), where they were (To), and what identifies
   --  them. A record a second keeps a crash's loss to the last second's
   --  items, which stay in the trash, restorable from there; each record is
   --  committed durably.
   Progress   : Progressive_Undo :=
     (Kind => Files.Undo.History.Undo_Restore_Trash, Redoable => False, Durable => True, others => <>);
   --  Set when a native trash took an item without saying where it went:
   --  Undo has nothing to restore it from, so the item is left out of the
   --  entry (an empty path would fail the whole Undo) and the user is told.
   Untracked  : Boolean := False;
begin
   declare
      Refusal : constant Operation_Result := Trash_Refusal (Model);
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   declare
      Refusal : constant Operation_Result := Real_Selection_Refusal (Model);
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if not Files.File_System.Trash.Trash_Is_Available then
      Files.Model.Set_Error (Model, "error.trash.unavailable");
      return Make_Result (Operation_Failed, "error.trash.unavailable");
   end if;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      declare
         Preflight : constant Files.File_System.Mutation_Result :=
           Files.File_System.Trash.Move_To_Trash_Preflight (To_String (Item.Full_Path));
      begin
         if Preflight.Success then
            null;
         else
            Reload_With_Error (Model, Settings, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
            return Make_Result
              (Operation_Failed, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
         end if;
      end;
   end loop;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      --  refusal-safe: a refused lookup refuses the trash
      if not Files.IO.Fs_Primitives.Entry_Exists (To_String (Item.Full_Path)) then
         Reload_With_Error (Model, Settings, "error.trash.failed", To_String (Item.Full_Path));
         return Make_Result (Operation_Failed, "error.trash.failed", To_String (Item.Full_Path));
      end if;
   end loop;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      if Length (First_Path) = 0 then
         First_Path := Item.Full_Path;
      end if;

      declare
         Trashed  : Files.Types.UString;
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Trash.Move_To_Trash (To_String (Item.Full_Path), Trashed);
      begin
         if not Mutation.Success then
            --  Record an undo covering whatever was already trashed before this
            --  mid-batch failure (a race can make a later item fail after
            --  earlier ones moved), so those items remain Ctrl-Z-restorable
            --  instead of being stranded in the trash.
            Finish_Failed_Undo (Model, Progress);
            Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
         end if;
         if Length (Trashed) = 0 then
            Untracked := True;
         else
            Progress.Items.Append
              (Files.Undo.History.Recorded_Item'
                 (Item       =>
                    (From     => Trashed,
                     To       => Item.Full_Path,
                     Identity => To_Unbounded_String (Files.File_Identities.Token (To_String (Trashed))),
                     others   => <>),
                  Provenance => Files.Undo.History.Published));
         end if;
         --  Labels go into the trash with the item and come back with it,
         --  so a new file at the old path inherits none. A native trash
         --  that does not say where the item went keeps them in place.
         Files.Model.Recent.Note_Path_Move (Model, To_String (Item.Full_Path), To_String (Trashed));
         Checkpoint_Undo (Model, Progress);
      end;
   end loop;

   --  Restoring from trash reproduces the original path, but re-trashing
   --  allocates a fresh trash location, so this entry is undo-only.
   declare
      Undo : constant Undo_Outcome := Finish_Undo (Model, Progress);
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         return Reload;
      end if;
      Note_Undo_Outcome (Model, Undo, Reload);
      if Untracked then
         Files.Model.Set_Error (Model, Untracked_Trash_Notice);
      end if;
   end;

   return Make_Result (Operation_Success, Path => To_String (First_Path));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      --  What was trashed before the failure stays restorable by Undo.
      Finish_Failed_Undo (Model, Progress);
      Files.Model.Set_Error (Model, "error.trash.failed");
      return Make_Result (Operation_Failed, "error.trash.failed", Files.Model.Current_Path (Model));
end Delete_Selected;
