separate (Files.Model)
   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.View_Value := Mode;
      Model.Main_View_Scroll := 0;
   end Set_View_Mode;
