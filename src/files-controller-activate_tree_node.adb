with Files.Operation_Results;
separate (Files.Controller)
   function Activate_Tree_Node
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural)
      return Controller_Result is
   begin
      if not Tree_Node_Accepts_Click (Model, Node_Index) then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Node_Path : constant String := Files.Model.Tree_Panel.Node_Path (Model, Node_Index);
      begin
         --  While a Copy to.../Move to... picker is active a label click chooses
         --  the highlighted destination instead of navigating the main view.
         if Files.Model.Tree_Panel.Pick_Is_Active (Model) then
            Files.Model.Tree_Panel.Set_Pick_Target (Model, Node_Path);
            Files.Model.Set_Error (Model, "");
            return Make_Result
              (Controller_Command_Executed, Files.Commands.No_Command, Empty_Operation);
         end if;

         if not Files.Model.Tree_Panel.Node_Is_Expanded (Model, Node_Index) then
            Files.Operations.Load_Tree_Children (Model, Settings, Node_Index);
         end if;
         Files.Model.Tree_Panel.Set_Expanded (Model, Node_Index, True);

         declare
            Operation : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Node_Path);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
         end;
      end;
   end Activate_Tree_Node;
