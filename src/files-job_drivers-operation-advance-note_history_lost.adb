separate (Files.Job_Drivers.Operation.Advance)
procedure Note_History_Lost (Kind : Operation_Kind) is
begin
   if History_Lost and then Kind not in Search_Names | Search_Contents then
      if Files.Model.Last_Error_Key (Model) = "" then
         Files.Model.Set_Error (Model, Undo_Lost_Key);
      else
         Files.Model.Set_Error_Notice (Model, Undo_Lost_Key);
      end if;
   end if;
end Note_History_Lost;
