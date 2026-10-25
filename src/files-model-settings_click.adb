separate (Files.Model)
function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   Clicked : constant Boolean :=
     Guikit.Settings_Panel.Click (Model.Settings_Panel_View, X, Y);
begin
   if Clicked then
      Model.Revision_Value := Model.Revision_Value + 1;
   end if;
   return Clicked;
end Settings_Click;
