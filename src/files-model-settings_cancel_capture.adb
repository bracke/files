separate (Files.Model)
   procedure Settings_Cancel_Capture (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
   end Settings_Cancel_Capture;
