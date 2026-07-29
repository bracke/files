separate (Files.Model)
   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Settings_Panel.Set_Active_Section (Model.Settings_Panel_View, Ordinal);
   end Settings_Set_Active_Section;
