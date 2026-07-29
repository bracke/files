separate (Files.Model)
   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Path_Input_Value := To_Unbounded_String (Text);
      Model.Path_Input_Cursor := Text'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
   end Set_Path_Input_Text;
