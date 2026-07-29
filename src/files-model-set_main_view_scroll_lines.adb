separate (Files.Model)
   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Main_View_Scroll := Lines;
   end Set_Main_View_Scroll_Lines;
