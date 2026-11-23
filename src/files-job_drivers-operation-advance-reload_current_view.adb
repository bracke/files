separate (Files.Job_Drivers.Operation.Advance)
--  Reload the view the operation ran in, in the background: a folder's
--  listing, or, while the window shows search results, the search again
--  (Files.Refresh.Start's Search_Again), never on the window's thread. The
--  operation's diagnostic, set before, is kept.
procedure Reload_Current_View (Select_Name : String := ""; Select_Path : String := "") is
   Reload : constant Files.Operation_Results.Operation_Result :=
     Files.Refresh.Start
       (Model, Settings, Force => True, Select_Name => Select_Name, Select_Path => Select_Path,
        Search_Again => True);
   pragma Unreferenced (Reload);
begin
   null;
end Reload_Current_View;
