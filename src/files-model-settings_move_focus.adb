separate (Files.Model)
   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Settings_Panel.Move_Focus (Model.Settings_Panel_View, Delta_Rows);
   end Settings_Move_Focus;
