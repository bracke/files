separate (Files.Operations)
   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.open_action.unsafe_placeholder");
      return Make_Result (Operation_Failed, "error.open_action.unsafe_placeholder", Path);
   end Unsafe_Open_Action;
