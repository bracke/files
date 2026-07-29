separate (Files.Model)
   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Last_Error := To_Unbounded_String (Error_Key);
   end Set_Error;
