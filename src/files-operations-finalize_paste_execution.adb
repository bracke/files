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
   --  Read once: everything recorded below is what the paste gathered.
   Exec       : constant Files.Model.Paste_Execution_State := Files.Model.Paste_Execution_Of (Model);
   Mode       : constant Files.File_System.Drop_Import_Mode :=
     Exec.Mode;
   Undo_From  : constant Files.Types.String_Vectors.Vector :=
     Exec.Undo_From;
   Undo_To    : constant Files.Types.String_Vectors.Vector :=
     Exec.Undo_To;
   --  Trash locations of destinations a Replace overwrote; undo restores them,
   --  and a paste that replaced anything is undo-only (redo is not attempted).
   Replaced_Trash : constant Files.Types.String_Vectors.Vector :=
     Exec.Replaced_Trash;
   Redoable   : constant Boolean := Replaced_Trash.Is_Empty;
   First_Dest : constant String := To_String (Exec.First_Dest);
begin
   if not Undo_From.Is_Empty then
      if Mode = Files.File_System.Drop_Move then
         Record_Undo
           (Model, Files.Model.Undo_Move, Undo_From, Undo_To,
            Redoable      => Redoable,
            Restore_Trash => Replaced_Trash,
            Provenance =>
              (Restore_Identities => Exec.Replaced_Identities,
               Restore_Targets => Exec.Replaced_Targets,
               Identities => Exec.Identities,
               Tree_Revisions => Exec.Tree_Revisions,
               Retain_Verified_Main => Exec.Verified_Created_Count,
               Retain_Verified_Restores => Exec.Verified_Replaced_Count));
      else
         --  A copy is reversed by deleting the created copies (Undo_From) and
         --  redone by copying each source (Undo_To) back to its destination.
         Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Undo_From,
            Files.Types.String_Vectors.Empty_Vector,
            Forward       => Undo_To,
            Create_Kind   => Files.Model.Create_Copy,
            Redoable      => Redoable,
            Restore_Trash => Replaced_Trash,
            Provenance =>
              (Restore_Identities => Exec.Replaced_Identities,
               Restore_Targets => Exec.Replaced_Targets,
               Identities => Exec.Identities,
               Tree_Revisions => Exec.Tree_Revisions,
               Retain_Verified_Main => Exec.Verified_Created_Count,
               Retain_Verified_Restores => Exec.Verified_Replaced_Count));
      end if;

      --  A clipboard cut/move consumes the clipboard once the paste has run
      --  (even if it was cancelled part-way, the completed sources have
      --  already moved). A drag-and-drop move never touches the clipboard, so
      --  it must not clear an unrelated clipboard selection.
      if Mode = Files.File_System.Drop_Move
        and then Exec.Clears_Clipboard
      then
         Files.Model.Clear_Clipboard (Model);
      end if;
   end if;

   if Undo_From.Is_Empty and then not Replaced_Trash.Is_Empty then
      Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Replaced_Trash,
         Exec.Replaced_Targets, Redoable => False,
         Provenance =>
           (Identities => Exec.Replaced_Identities,
            Retain_Verified_Main => Exec.Verified_Replaced_Count,
            others => <>));
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
