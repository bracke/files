separate (Files.Operations)
procedure Remove_Completion
  (Action : in out Files.Model.Undo_Entry;
   Path : Files.Types.UString;
   Forward : Boolean)
is
begin
   if Forward then
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
