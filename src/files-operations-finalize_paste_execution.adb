separate (Files.Operations)
--  Finalize an armed paste execution: record one undo covering the items
--  actually completed (move reversed by moving back; copy by deleting the
--  created copies), clear the move-mode clipboard, reload, and clear the
--  execution state. A non-empty Error_Key reports a mid-run write failure.
function Finalize_Paste_Execution
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Error_Key : String)
   return Operation_Result
is
   Mode       : constant Files.File_System.Drop_Import_Mode :=
     Files.Model.Paste_Execution_Mode (Model);
   Undo_From  : constant Files.Types.String_Vectors.Vector :=
     Files.Model.Paste_Execution_Undo_From (Model);
   Undo_To    : constant Files.Types.String_Vectors.Vector :=
     Files.Model.Paste_Execution_Undo_To (Model);
   --  Trash locations of destinations a Replace overwrote; undo restores them,
   --  and a paste that replaced anything is undo-only (redo is not attempted).
   Replaced_Trash : constant Files.Types.String_Vectors.Vector :=
     Files.Model.Paste_Execution_Replaced_Trash (Model);
   Redoable   : constant Boolean := Replaced_Trash.Is_Empty;
   First_Dest : constant String := Files.Model.Paste_Execution_First_Dest (Model);
begin
   if not Undo_From.Is_Empty then
      if Mode = Files.File_System.Drop_Move then
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Move, Undo_From, Undo_To,
            Redoable      => Redoable,
            Restore_Trash => Replaced_Trash,
            Original_Restore_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
            Original_Restore_Targets => Files.Model.Paste_Execution_Replaced_Targets (Model),
            Original_Identities => Files.Model.Paste_Execution_Created_Identities (Model),
            Original_Tree_Revisions => Files.Model.Paste_Execution_Created_Tree_Revisions (Model),
            Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Created_Count (Model),
            Retain_Verified_Restores => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
      else
         --  A copy is reversed by deleting the created copies (Undo_From) and
         --  redone by copying each source (Undo_To) back to its destination.
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Undo_From,
            Files.Types.String_Vectors.Empty_Vector,
            Forward       => Undo_To,
            Create_Kind   => Files.Model.Create_Copy,
            Redoable      => Redoable,
            Restore_Trash => Replaced_Trash,
            Original_Restore_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
            Original_Restore_Targets => Files.Model.Paste_Execution_Replaced_Targets (Model),
            Original_Identities => Files.Model.Paste_Execution_Created_Identities (Model),
            Original_Tree_Revisions => Files.Model.Paste_Execution_Created_Tree_Revisions (Model),
            Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Created_Count (Model),
            Retain_Verified_Restores => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
      end if;

      --  A clipboard cut/move consumes the clipboard once the paste has run
      --  (even if it was cancelled part-way, the completed sources have
      --  already moved). A drag-and-drop move never touches the clipboard, so
      --  it must not clear an unrelated clipboard selection.
      if Mode = Files.File_System.Drop_Move
        and then Files.Model.Paste_Execution_Clears_Clipboard (Model)
      then
         Files.Model.Clear_Clipboard (Model);
      end if;
   end if;

   if Undo_From.Is_Empty and then not Replaced_Trash.Is_Empty then
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Replaced_Trash,
         Files.Model.Paste_Execution_Replaced_Targets (Model), Redoable => False,
         Original_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
         Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
   end if;
   Files.Model.Clear_Paste_Execution (Model);

   if Files.Model.Background_Transfers (Model) then
      --  Preserve mutation errors while a nonmodal helper refreshes the view.
      Files.Model.Set_Error (Model, Error_Key);
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Error_Key /= "" then
            return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
         elsif Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;
      return Make_Result (Operation_Success, Path => First_Dest);
   end if;

   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         if Error_Key /= "" then
            Files.Model.Set_Error (Model, Error_Key);
            return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
         end if;
         return Reload;
      end if;
   end;

   if Error_Key /= "" then
      Files.Model.Set_Error (Model, Error_Key);
      return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
   end if;

   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Success, Path => First_Dest);
end Finalize_Paste_Execution;
