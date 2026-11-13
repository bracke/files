separate (Files.Model)
procedure Merge_History
  (Model : in out Window_Model;
   Undo, Redo : Undo_Entry_Vectors.Vector;
   State : History_Journal_State)
is
   package Sequence_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Positive);

   Next : Positive := Positive'Max (State.Next_Sequence, Model.History_Journal.Next_Sequence);
   Journal_Undo, Journal_Redo : Undo_Entry_Vectors.Vector;
   Merged_Undo, Merged_Redo : Undo_Entry_Vectors.Vector;
   Journaled, Unjournaled : Sequence_Sets.Set;

   --  Whether the window's Action is still in the history although the
   --  journal does not hold it: the journal lists it as left out.
   function Left_Out (Action : Undo_Entry) return Boolean is
     (Action.Sequence > 0
      and then not Journaled.Contains (Action.Sequence)
      and then Unjournaled.Contains (Action.Sequence));

   --  The entry of Stack whose Sequence is Sequence, if any.
   function Index_Of (Stack : Undo_Entry_Vectors.Vector; Sequence : Natural) return Natural is
   begin
      for Index in Stack.First_Index .. Stack.Last_Index loop
         if Stack (Index).Sequence = Sequence then
            return Index;
         end if;
      end loop;
      return 0;
   end Index_Of;

   --  Merge one stack: the window's entries in their order, each as the
   --  journal now has it, kept as they are when left out of the journal
   --  (Keep_Left_Out False retires those instead), dropped when the helper
   --  retired them; then the journal's entries the window's stack did not
   --  hold (new records, or entries undone or redone onto this stack).
   procedure Merge_Stack
     (Window, Journal : Undo_Entry_Vectors.Vector;
      Keep_Left_Out   : Boolean;
      Merged          : out Undo_Entry_Vectors.Vector) is
   begin
      Merged.Clear;
      for Action of Window loop
         declare
            Index : constant Natural := Index_Of (Journal, Action.Sequence);
         begin
            if Action.Sequence > 0 and then Index > 0 then
               Merged.Append (Journal (Index));
            elsif Left_Out (Action) and then Keep_Left_Out then
               Merged.Append (Action);
            elsif Left_Out (Action) then
               --  The helper's new record retired the redo stack, and this
               --  entry, which it never held, with it.
               for Payload of Action.Restore_Trash loop
                  Model.Retired_Discards.Append (Payload);
               end loop;
            end if;
         end;
      end loop;
      for Action of Journal loop
         if Index_Of (Window, Action.Sequence) = 0 then
            Merged.Append (Action);
         end if;
      end loop;
   end Merge_Stack;
begin
   Sanitize_History (Undo, Redo, Next, Journal_Undo, Journal_Redo);
   for Action of Journal_Undo loop
      Journaled.Include (Action.Sequence);
   end loop;
   for Action of Journal_Redo loop
      Journaled.Include (Action.Sequence);
   end loop;
   for Sequence of State.Unjournaled loop
      Unjournaled.Include (Sequence);
   end loop;

   --  An entry the journal neither holds nor lists the helper retired,
   --  payloads and all; one it lists stays where the window had it.
   Merge_Stack (Model.Undo_Stack, Journal_Undo, True, Merged_Undo);
   Merge_Stack (Model.Redo_Stack, Journal_Redo, not State.Redo_Retired, Merged_Redo);

   while Natural (Merged_Undo.Length) > Max_Undo_Depth loop
      --  As Commit_Undo_Record: a dropped entry could still have been
      --  undone, so its originals go to the system trash.
      for Payload of Merged_Undo.First_Element.Restore_Trash loop
         Model.Retired_Releases.Append (Payload);
      end loop;
      Merged_Undo.Delete_First;
   end loop;

   Model.Undo_Stack := Merged_Undo;
   Model.Redo_Stack := Merged_Redo;
   Model.History_Journal :=
     (Next_Sequence => Next,
      Unjournaled   => Sequence_Vectors.Empty_Vector,
      Redo_Retired  => Model.History_Journal.Redo_Retired or else State.Redo_Retired);
   Model.History_Journal_Dirty := True;
   Support.Touch (Model);
end Merge_History;
