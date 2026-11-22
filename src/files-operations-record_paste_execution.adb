with Files.File_System_Types;
with Files.Model.Recent;
with Files.Paste_States;
with Files.Model.Clipboard;
separate (Files.Operations)
--  Record one undo covering the items an armed paste actually completed
--  (move reversed by moving back; copy by deleting the created copies) and
--  the originals a Replace preserved, and clear the move-mode clipboard. The
--  paste stays armed: Finalize_Paste_Execution, or a closing window, ends it.
procedure Record_Paste_Execution
  (Model : in out Files.Model.Window_Model;
   Kept  : Kept_Copy := No_Kept_Copy)
is
   --  Read once: everything recorded below is what the paste gathered.
   Exec       : constant Files.Paste_States.Execution_State := Files.Model.Pasting.Execution_Of (Model);
   Mode       : constant Files.File_System_Types.Drop_Import_Mode :=
     Exec.Mode;
   --  Each write: destination (From) and source (To), with its provenance.
   Written    : Files.Undo.History.Recorded_Item_Vectors.Vector renames Exec.Written;
   --  Destinations a Replace overwrote; undo restores them, and a paste that
   --  replaced anything is undo-only (redo is not attempted).
   Replaced   : Files.Undo.History.Recorded_Original_Vectors.Vector renames Exec.Replaced;
   --  A copy a failed move kept beside its source joins the paste's one
   --  undo entry, which deletes it before anything moves back or any
   --  original returns to its path; so does a paste that kept one, being
   --  undo-only too (its redo would meet the source still in place).
   Has_Kept   : constant Boolean := Length (Kept.Dest_Path) > 0;
   Kept_Copies : constant Files.Undo.History.Kept_Copy_Vectors.Vector :=
     (if Has_Kept
      then Files.Undo.History.Kept_Copy_Vectors.To_Vector
        ((Path => Kept.Dest_Path, Identity => Kept.Identity, Tree_Revision => Kept.Tree_Revision), 1)
      else Files.Undo.History.Kept_Copy_Vectors.Empty_Vector);
   Redoable   : constant Boolean := Replaced.Is_Empty and then not Has_Kept;
begin
   --  Each item a Replace overwrote went to its recovery stage before the
   --  pasted item took its path: its labels, favorite and recent entry go
   --  with it (and come back with it on Undo, Apply_Reverse), noted before
   --  the moves recorded below, so the item now at the path does not end
   --  up with two of each.
   for Given of Replaced loop
      Files.Model.Recent.Note_Path_Move (Model, To_String (Given.Original.Target), To_String (Given.Original.Trash));
   end loop;
   if not Written.Is_Empty or else Has_Kept then
      if Mode = Files.File_System_Types.Drop_Move then
         --  With no moved member, the kept copies alone are recorded (as the
         --  creations they are, by Try_Record_Undo) with the originals.
         Record_Undo
           (Model, Files.Undo.History.Undo_Move, Written,
            Redoable => Redoable,
            Replaced => Replaced,
            Kept     => Kept_Copies);
      else
         --  A copy is reversed by deleting the created copies and redone by
         --  copying each source back to its destination.
         declare
            Copies : Files.Undo.History.Recorded_Item_Vectors.Vector := Written;
         begin
            for Copy of Copies loop
               Copy.Item.Forward := Copy.Item.To;
               Copy.Item.To := Null_Unbounded_String;
            end loop;
            Record_Undo
              (Model, Files.Undo.History.Undo_Delete_Created, Copies,
               Create_Kind => Files.Undo.History.Create_Copy,
               Redoable    => Redoable,
               Replaced    => Replaced);
         end;
      end if;

      --  A clipboard cut/move consumes the clipboard once the paste has run
      --  (even if it was cancelled part-way, the completed sources have
      --  already moved). A drag-and-drop move never touches the clipboard, so
      --  it must not clear an unrelated clipboard selection.
      if Mode = Files.File_System_Types.Drop_Move
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
         Trashed : Files.Undo.History.Recorded_Item_Vectors.Vector;
      begin
         for Given of Replaced loop
            Trashed.Append
              (Files.Undo.History.Recorded_Item'
                 (Item       =>
                    (From     => Given.Original.Trash,
                     To       => Given.Original.Target,
                     Identity => Given.Original.Identity,
                     others   => <>),
                  Provenance => Given.Provenance));
         end loop;
         Record_Undo (Model, Files.Undo.History.Undo_Restore_Trash, Trashed, Redoable => False);
      end;
   end if;
end Record_Paste_Execution;
