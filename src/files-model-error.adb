package body Files.Model.Error is
   use Ada.Strings.Unbounded;

   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String) is
   begin
      Model.Last_Error := To_Unbounded_String (Error_Key);
   end Set_Error;

   function Last_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Last_Error);
   end Last_Error_Key;

end Files.Model.Error;
