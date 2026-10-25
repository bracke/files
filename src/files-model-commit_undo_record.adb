separate (Files.Model)
function Commit_Undo_Record
  (Model  : in out Window_Model;
   Action : Undo_Entry) return Boolean is
   --  Cap the undo history so a session doing thousands of operations does not
   --  grow it without bound: each entry retains the full source and destination
   --  path lists (and permission/ownership images), so an unbounded stack pins
   --  that data for the life of the window. Past the cap the oldest entry --
   --  least likely to ever be undone -- is dropped; LIFO undo only touches the
   --  newest, so the reachable history is unaffected.
   Max_Undo_Depth : constant := 200;
begin
   --  Payloads are queued only once their entry has left both stacks; the
   --  operations layer deletes them when it drains Take_Retired_History.
   Retire_Payloads (Model.Retired_Discards, Model.Redo_Stack);
   Model.Redo_Stack.Clear;
   Model.History_Journal_Dirty := True;
   if Action.From.Is_Empty then
      return False;
   end if;

   Model.Undo_Stack.Append (Action);
   while Natural (Model.Undo_Stack.Length) > Max_Undo_Depth loop
      for Payload of Model.Undo_Stack.First_Element.Restore_Trash loop
         Model.Retired_Discards.Append (Payload);
      end loop;
      Model.Undo_Stack.Delete_First;
   end loop;
   return True;
end Commit_Undo_Record;
