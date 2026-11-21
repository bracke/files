separate (Files.Job_Drivers.Operation.Advance)
function Report_In_View return Files.Operation_Results.Operation_Result is
begin
   if Cancelled then
      Files.Model.Set_Error (Model, "");
      return Reported;
   end if;
   Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
   Note_History_Lost (Done.Kind);
   Files.Window_Polls.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
   return Done.Result;
end Report_In_View;
