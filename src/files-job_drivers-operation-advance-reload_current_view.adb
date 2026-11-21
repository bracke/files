separate (Files.Job_Drivers.Operation.Advance)
procedure Reload_Current_View (Select_Name : String := "") is
   Reload : constant Files.Operation_Results.Operation_Result :=
     Files.Refresh.Start (Model, Settings, True, Select_Name);
   pragma Unreferenced (Reload);
begin
   null;
end Reload_Current_View;
