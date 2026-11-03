separate (Files.Model)
procedure Set_View_Mode
  (Model : in out Window_Model;
   Mode  : Files.Types.View_Mode) is
begin
   Touch (Model);
   Model.View_Value := Mode;
   Model.Main_View_Scroll := 0;
end Set_View_Mode;
