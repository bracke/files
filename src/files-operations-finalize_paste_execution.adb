with Files.Model.Clipboard;
separate (Files.Operations)
--  Finalize an armed paste execution: record one undo covering the items
--  actually completed (move reversed by moving back; copy by deleting the
--  created copies), clear the move-mode clipboard, reload, and clear the
--  execution state. A non-empty Error_Key reports a mid-run write failure;
--  Kept names a failed move's copy left beside its still present source.
function Finalize_Paste_Execution
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Error_Key : String;
   Kept      : Kept_Copy := No_Kept_Copy)
   return Operation_Result
is
   --  Read once: everything recorded below is what the paste gathered.
   Exec       : constant Files.Model.Paste_Execution_State := Files.Model.Pasting.Execution_Of (Model);
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
   --  A copy a failed move kept beside its source joins the paste's one
   --  undo entry, which deletes it before anything moves back or any
   --  original returns to its path; so does a paste that kept one, being
   --  undo-only too (its redo would meet the source still in place).
   Has_Kept   : constant Boolean := Length (Kept.Dest_Path) > 0;
   Kept_Paths : constant Files.Types.String_Vectors.Vector :=
     (if Has_Kept then Files.Types.String_Vectors.To_Vector (Kept.Dest_Path, 1)
      else Files.Types.String_Vectors.Empty_Vector);
   Redoable   : constant Boolean := Replaced_Trash.Is_Empty and then not Has_Kept;
   First_Dest : constant String := To_String (Exec.First_Dest);
   --  A kept copy no longer verifiable on a path an original goes back to
   --  makes the whole undo unsafe: Try_Record_Undo records nothing, and the
   --  paste reports it rather than letting the missing Undo pass unnoticed.
   Unsafe_Kept : constant Boolean :=
     Has_Kept
     and then Exec.Replaced_Targets.Contains (Kept.Dest_Path)
     and then not Files.File_System.Creation_Matches
       (To_String (Kept.Dest_Path), To_String (Kept.Identity), To_String (Kept.Tree_Revision), False);
   --  The move's own failure stays the error; the missing Undo is reported
   --  as the error only when nothing else failed (a cancelled paste), and
   --  otherwise joins it as a second message.
   Undo_Unavailable_Key : constant String := "error.paste.undo_unavailable";
   Reported_Key : constant String :=
     (if Unsafe_Kept and then Error_Key = "" then Undo_Unavailable_Key else Error_Key);
   Notice_Key : constant String :=
     (if Unsafe_Kept and then Error_Key /= "" then Undo_Unavailable_Key else "");

   --  Record Reported_Key as the window's error, with Notice_Key beside it.
   procedure Report is
   begin
      Files.Model.Set_Error (Model, Reported_Key);
      if Notice_Key /= "" then
         Files.Model.Set_Error_Notice (Model, Notice_Key);
      end if;
   end Report;
   Kept_Provenance : constant Undo_Provenance :=
     (Kept_Copies              => Kept_Paths,
      Kept_Copy_Identities     =>
        (if Has_Kept then Files.Types.String_Vectors.To_Vector (Kept.Identity, 1)
         else Files.Types.String_Vectors.Empty_Vector),
      Kept_Copy_Tree_Revisions =>
        (if Has_Kept then Files.Types.String_Vectors.To_Vector (Kept.Tree_Revision, 1)
         else Files.Types.String_Vectors.Empty_Vector),
      others                   => <>);
begin
   if not Undo_From.Is_Empty or else Has_Kept then
      if Mode = Files.File_System.Drop_Move then
         --  With no moved member, the kept copies alone are recorded (as the
         --  creations they are, by Try_Record_Undo) with the originals.
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
               Retain_Verified_Restores => Exec.Verified_Replaced_Count,
               Kept_Copies => Kept_Provenance.Kept_Copies,
               Kept_Copy_Identities => Kept_Provenance.Kept_Copy_Identities,
               Kept_Copy_Tree_Revisions => Kept_Provenance.Kept_Copy_Tree_Revisions));
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
               Retain_Verified_Restores => Exec.Verified_Replaced_Count,
               others => <>));
      end if;

      --  A clipboard cut/move consumes the clipboard once the paste has run
      --  (even if it was cancelled part-way, the completed sources have
      --  already moved). A drag-and-drop move never touches the clipboard, so
      --  it must not clear an unrelated clipboard selection.
      if Mode = Files.File_System.Drop_Move
        and then Exec.Clears_Clipboard
        and then not Undo_From.Is_Empty
      then
         Files.Model.Clipboard.Clear (Model);
      end if;
   end if;

   if Undo_From.Is_Empty and then not Has_Kept and then not Replaced_Trash.Is_Empty then
      Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Replaced_Trash,
         Exec.Replaced_Targets, Redoable => False,
         Provenance =>
           (Identities => Exec.Replaced_Identities,
            Retain_Verified_Main => Exec.Verified_Replaced_Count,
            others => <>));
   end if;
   Files.Model.Pasting.Clear_Execution (Model);

   if Files.Model.Background_Transfers (Model) then
      --  Preserve mutation errors while a nonmodal helper refreshes the view.
      Report;
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reported_Key /= "" then
            return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
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
         if Reported_Key /= "" then
            Report;
            return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
         end if;
         return Reload;
      end if;
   end;

   if Reported_Key /= "" then
      Report;
      return Make_Result (Operation_Failed, Reported_Key, Files.Model.Current_Path (Model));
   end if;

   Files.Model.Set_Error (Model, "");
   return Make_Result (Operation_Success, Path => First_Dest);
end Finalize_Paste_Execution;
