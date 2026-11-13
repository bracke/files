separate (Files.Model)
function Commit_Undo_Record
  (Model  : in out Window_Model;
   Action : Undo_Entry) return Boolean is
   Numbered : Undo_Entry := Action;
begin
   --  Payloads are queued only once their entry has left both stacks; the
   --  operations layer deletes them when it drains Take_Retired_History.
   Retire_Payloads (Model.Retired_Discards, Model.Redo_Stack);
   Model.Redo_Stack.Clear;
   --  Redo entries a background helper's journal left out go too.
   Model.History_Journal.Redo_Retired := True;
   --  Undo and Redo availability is drawn and enables commands.
   Touch (Model);
   Model.History_Journal_Dirty := True;
   if Action.From.Is_Empty then
      --  Nothing to record, but originals a replace preserved must not stay
      --  in hidden stages with no way back: they go to the system trash.
      for Payload of Action.Restore_Trash loop
         Model.Retired_Releases.Append (Payload);
      end loop;
      return False;
   end if;

   Numbered.Sequence := Model.History_Journal.Next_Sequence;
   Model.History_Journal.Next_Sequence := Model.History_Journal.Next_Sequence + 1;
   Model.Undo_Stack.Append (Numbered);
   while Natural (Model.Undo_Stack.Length) > Max_Undo_Depth loop
      --  The dropped entry could still have been undone, so the originals it
      --  holds go to the system trash, as on window close, not to deletion.
      for Payload of Model.Undo_Stack.First_Element.Restore_Trash loop
         Model.Retired_Releases.Append (Payload);
      end loop;
      Model.Undo_Stack.Delete_First;
   end loop;
   return True;
end Commit_Undo_Record;
