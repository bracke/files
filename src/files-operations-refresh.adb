separate (Files.Operations)
   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      --  The virtual recent view has no backing directory to reload; rebuild its
      --  synthetic listing from the current recent paths instead.
      if Files.Model.In_Recent_View (Model) then
         return Navigate_Recent (Model, Settings);
      end if;
      --  Preserve the current selection across a manual refresh when the item
      --  still exists (Reload re-selects by name; empty name => no selection).
      return Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
   end Refresh;
