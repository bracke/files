with Files.Model.Filtering;
with Files.Model.Selection;
with Files.Operations.Navigation;
with Files.UI_Types;
separate (Files.Job_Drivers.Operation.Advance)
--  Reload the view the operation ran in: a folder's listing in the
--  background, or, while the window shows search results, the search again
--  -- a forced background listing would put the folder in their place, as
--  Operations' Reload_Current_Directory says for an operation run here.
procedure Reload_Current_View (Select_Name : String := "") is
begin
   if Files.Model.Filtering.Search_Results_Are_Active (Model) then
      declare
         --  The operation's diagnostic, set before the reload, outlives
         --  the search's own (a background listing keeps it as well).
         Error_Key  : constant String := Files.Model.Last_Error_Key (Model);
         Error_Path : constant String := Files.Model.Last_Error_Path (Model);
         Notice     : constant String := Files.Model.Last_Error_Notice (Model);
         Searched : constant Files.Operation_Results.Operation_Result :=
           Files.Operations.Navigation.Run_Search
             (Model, Settings, Files.UI_Types.Tree_Search_Scope (Files.Model.Filtering.Search_Scope_Of (Model)));
         pragma Unreferenced (Searched);
      begin
         if Error_Key /= "" then
            Files.Model.Set_Error (Model, Error_Key, Error_Path);
            if Notice /= "" then
               Files.Model.Set_Error_Notice (Model, Notice);
            end if;
         end if;
         if Select_Name /= "" then
            declare
               Selected : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Select_Name);
               pragma Unreferenced (Selected);
            begin
               null;
            end;
         end if;
      end;
      return;
   end if;
   declare
      Reload : constant Files.Operation_Results.Operation_Result :=
        Files.Refresh.Start (Model, Settings, True, Select_Name);
      pragma Unreferenced (Reload);
   begin
      null;
   end;
end Reload_Current_View;
