separate (Files.Operations)
function Delete_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   First_Path : Unbounded_String;
   Undo_From  : Files.Types.String_Vectors.Vector;
   Undo_To    : Files.Types.String_Vectors.Vector;
   Identities : Files.Types.String_Vectors.Vector;
   Progress_Recorded : Boolean := False;
   Verified_Count : Natural := 0;
   procedure Record_Progress is
      Previous : Files.Model.Undo_Entry;
      Found : Boolean;
   begin
      if Progress_Recorded then
         Files.Model.Take_Undo (Model, Previous, Found);
      end if;
      Progress_Recorded := Try_Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To, Redoable => False,
         Original_Identities => Identities,
         Retain_Verified_Main => Verified_Count);
      if Progress_Recorded
        and then Natural (Files.Model.Undo_From_Paths (Model).Length) =
          Natural (Undo_From.Length)
      then
         Verified_Count := Natural (Undo_From.Length);
      end if;
      Files.History_Journal.Save (Model, Required => True);
   end Record_Progress;
begin
   if Is_Trash_Directory (Files.Model.Current_Path (Model)) then
      return Disabled (Model, "error.trash.failed");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Trash);
   end if;
   if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.selection.empty");
   elsif not Files.File_System.Trash_Is_Available then
      Files.Model.Set_Error (Model, "error.trash.unavailable");
      return Make_Result (Operation_Failed, "error.trash.unavailable");
   end if;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      declare
         Preflight : constant Files.File_System.Mutation_Result :=
           Files.File_System.Move_To_Trash_Preflight (To_String (Item.Full_Path));
      begin
         if Preflight.Success then
            null;
         else
            Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
            declare
               Reload : constant Operation_Result :=
                 Reload_With_Error (Model, Settings, To_String (Preflight.Error_Key));
               pragma Unreferenced (Reload);
            begin
               null;
            end;
            return Make_Result
              (Operation_Failed, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
         end if;
      end;
   end loop;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      if not Exists_Safely (To_String (Item.Full_Path)) then
         Files.Model.Set_Error (Model, "error.trash.failed");
         declare
            Reload : constant Operation_Result := Reload_With_Error (Model, Settings, "error.trash.failed");
            pragma Unreferenced (Reload);
         begin
            null;
         end;
         return Make_Result (Operation_Failed, "error.trash.failed", To_String (Item.Full_Path));
      end if;
   end loop;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      if Length (First_Path) = 0 then
         First_Path := Item.Full_Path;
      end if;

      declare
         Trashed  : Files.Types.UString;
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Move_To_Trash (To_String (Item.Full_Path), Trashed);
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            --  Record an undo covering whatever was already trashed before this
            --  mid-batch failure (a race can make a later item fail after
            --  earlier ones moved), so those items remain Ctrl-Z-restorable
            --  instead of being stranded in the trash.
            if not Undo_From.Is_Empty then
               if not Progress_Recorded then
                  Record_Progress;
               end if;
            end if;
            declare
               Reload : constant Operation_Result :=
                 Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key));
               pragma Unreferenced (Reload);
            begin
               null;
            end;
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
         end if;
         Undo_From.Append (Trashed);
         Undo_To.Append (Item.Full_Path);
         Identities.Append
           (To_Unbounded_String (Files.File_Identities.Token (To_String (Trashed))));
         --  Labels go into the trash with the item and come back with it,
         --  so a new file at the old path inherits none. A native trash
         --  that does not say where the item went keeps them in place.
         Files.Model.Note_Path_Move (Model, To_String (Item.Full_Path), To_String (Trashed));
         Record_Progress;
      end;
   end loop;

   --  Restoring from trash reproduces the original path, but re-trashing
   --  allocates a fresh trash location, so this entry is undo-only.
   if not Progress_Recorded and then not Undo_From.Is_Empty then
      Record_Progress;
   end if;

   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         return Reload;
      end if;
   end;

   return Make_Result (Operation_Success, Path => To_String (First_Path));
exception
   when others =>
      Files.Model.Set_Error (Model, "error.trash.failed");
      return Make_Result (Operation_Failed, "error.trash.failed", Files.Model.Current_Path (Model));
end Delete_Selected;
