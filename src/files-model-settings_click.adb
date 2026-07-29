separate (Files.Model)
   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      return Guikit.Settings_Panel.Click (Model.Settings_Panel_View, X, Y);
   end Settings_Click;
