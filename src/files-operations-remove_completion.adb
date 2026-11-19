separate (Files.Operations)
procedure Remove_Completion
  (Action : in out Files.Undo_History.Undo_Entry;
   Path : Files.Types.UString;
   Side : Files.Undo_History.History_Side)
is
   use type Files.Undo_History.History_Side;
begin
   --  Redone steps are recorded as forward completions, undone ones as
   --  reverse completions.
   if Side = Files.Undo_History.Redo_Side then
      for Index in reverse
        Action.Forward_Completed.First_Index .. Action.Forward_Completed.Last_Index
      loop
         if Action.Forward_Completed (Index) = Path then
            Action.Forward_Completed.Delete (Index);
         end if;
      end loop;
   else
      for Index in reverse
        Action.Reverse_Completed.First_Index .. Action.Reverse_Completed.Last_Index
      loop
         if Action.Reverse_Completed (Index) = Path then
            Action.Reverse_Completed.Delete (Index);
         end if;
      end loop;
   end if;
end Remove_Completion;
