separate (Files.Model)
   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      return Guikit.Settings_Panel.Take_Change (Model.Settings_Panel_View);
   end Settings_Take_Change;
