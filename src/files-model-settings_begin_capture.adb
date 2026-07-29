separate (Files.Model)
   procedure Settings_Begin_Capture (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Settings_Panel.Begin_Capture (Model.Settings_Panel_View);
   end Settings_Begin_Capture;
