separate (Files.Model)
   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Ownership_Input_Value := To_Unbounded_String (Text);
      Model.Ownership_Input_Cursor := Text'Length;
   end Set_Ownership_Input_Text;
