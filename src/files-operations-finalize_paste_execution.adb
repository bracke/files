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
   --  Each write: destination (From) and source (To).
   Written    : Files.Model.Undo_Item_Vectors.Vector renames Exec.Written;
   --  Destinations a Replace overwrote; undo restores them, and a paste that
   --  replaced anything is undo-only (redo is not attempted).
   Replaced   : Files.Model.Replaced_Original_Vectors.Vector renames Exec.Replaced;
   --  A copy a failed move kept beside its source joins the paste's one
   --  undo entry, which deletes it before anything moves back or any
   --  original returns to its path; so does a paste that kept one, being
   --  undo-only too (its redo would meet the source still in place).
   Has_Kept   : constant Boolean := Length (Kept.Dest_Path) > 0;
   Kept_Copies : constant Files.Model.Kept_Copy_Vectors.Vector :=
     (if Has_Kept
      then Files.Model.Kept_Copy_Vectors.To_Vector
        ((Path => Kept.Dest_Path, Identity => Kept.Identity, Tree_Revision => Kept.Tree_Revision), 1)
      else Files.Model.Kept_Copy_Vectors.Empty_Vector);
   Redoable   : constant Boolean := Replaced.Is_Empty and then not Has_Kept;
   First_Dest : constant String := To_String (Exec.First_Dest);
   --  A kept copy no longer verifiable on a path an original goes back to
   --  makes the whole undo unsafe: Try_Record_Undo records nothing, and the
   --  paste reports it rather than letting the missing Undo pass unnoticed.
   Unsafe_Kept : constant Boolean :=
     Has_Kept
     and then (for some Original of Replaced => Original.Target = Kept.Dest_Path)
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
begin
   --  Each item a Replace overwrote went to its recovery stage before the
   --  pasted item took its path: its labels, favorite and recent entry go
   --  with it (and come back with it on Undo, Apply_Reverse), noted before
   --  the moves recorded below, so the item now at the path does not end
   --  up with two of each.
   for Original of Replaced loop
      Files.Model.Note_Path_Move (Model, To_String (Original.Target), To_String (Original.Trash));
   end loop;
   if not Written.Is_Empty or else Has_Kept then
      if Mode = Files.File_System.Drop_Move then
         --  With no moved member, the kept copies alone are recorded (as the
         --  creations they are, by Try_Record_Undo) with the originals.
         Record_Undo
           (Model, Files.Model.Undo_Move, Written,
            Redoable   => Redoable,
            Replaced   => Replaced,
            Provenance =>
              (Published_Main           => Natural (Written.Length),
               Published_Restores       => Natural (Replaced.Length),
               Retain_Verified_Main     => Exec.Verified_Created_Count,
               Retain_Verified_Restores => Exec.Verified_Replaced_Count,
               Kept                     => Kept_Copies));
      else
         --  A copy is reversed by deleting the created copies and redone by
         --  copying each source back to its destination.
         declare
            Copies : Files.Model.Undo_Item_Vectors.Vector := Written;
         begin
            for Copy of Copies loop
               Copy.Forward := Copy.To;
               Copy.To := Null_Unbounded_String;
            end loop;
            Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Copies,
               Create_Kind => Files.Model.Create_Copy,
               Redoable    => Redoable,
               Replaced    => Replaced,
               Provenance  =>
                 (Published_Main           => Natural (Written.Length),
                  Published_Restores       => Natural (Replaced.Length),
                  Retain_Verified_Main     => Exec.Verified_Created_Count,
                  Retain_Verified_Restores => Exec.Verified_Replaced_Count,
                  others                   => <>));
         end;
      end if;

      --  A clipboard cut/move consumes the clipboard once the paste has run
      --  (even if it was cancelled part-way, the completed sources have
      --  already moved). A drag-and-drop move never touches the clipboard, so
      --  it must not clear an unrelated clipboard selection.
      if Mode = Files.File_System.Drop_Move
        and then Exec.Clears_Clipboard
        and then not Written.Is_Empty
      then
         Files.Model.Clipboard.Clear (Model);
      end if;
   end if;

   if Written.Is_Empty and then not Has_Kept and then not Replaced.Is_Empty then
      --  Nothing was written but originals were preserved: they come back
      --  from the trash as a trash restoration does.
      declare
         Trashed : Files.Model.Undo_Item_Vectors.Vector;
      begin
         for Original of Replaced loop
            Trashed.Append
              (Files.Model.Undo_Item'
                 (From => Original.Trash, To => Original.Target, Identity => Original.Identity, others => <>));
         end loop;
         Record_Undo
           (Model, Files.Model.Undo_Restore_Trash, Trashed, Redoable => False,
            Provenance =>
              (Published_Main       => Natural (Replaced.Length),
               Retain_Verified_Main => Exec.Verified_Replaced_Count,
               others               => <>));
      end;
   end if;
   Files.Model.End_Foreground_Job (Model);

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
