separate (Files.Model)
   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Settings_Panel.Cycle_Choice (Model.Settings_Panel_View, Forward);
   end Settings_Cycle_Choice;
