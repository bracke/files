separate (Files.Controller)
   function Handle_Tree_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural;
      Toggle     : Boolean)
      return Controller_Result is
   begin
      if not Files.Model.Tree_Panel_Is_Open (Model)
        or else Node_Index = 0
        or else Node_Index > Files.Model.Tree_Node_Count (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Index     : constant Positive := Positive (Node_Index);
         Node_Path : constant String := Files.Model.Tree_Node_Path (Model, Index);
      begin
         if Toggle then
            if not Files.Model.Tree_Node_Is_Expanded (Model, Index)
              and then not Files.Model.Tree_Node_Is_Loaded (Model, Index)
            then
               Load_Tree_Children (Model, Settings, Index, Node_Path);
            end if;
            Files.Model.Tree_Toggle_Expanded (Model, Index);
            return Make_Result
              (Controller_Command_Executed,
               Files.Commands.Toggle_Folder_Tree_Command,
               Empty_Operation);
         end if;

         --  While a Copy to.../Move to... picker is active a label click chooses
         --  the highlighted destination instead of navigating the main view.
         if Files.Model.Tree_Pick_Is_Active (Model) then
            Files.Model.Set_Tree_Pick_Target (Model, Node_Path);
            Files.Model.Set_Error (Model, "");
            return Make_Result
              (Controller_Command_Executed, Files.Commands.No_Command, Empty_Operation);
         end if;

         if not Files.Model.Tree_Node_Is_Loaded (Model, Index) then
            Load_Tree_Children (Model, Settings, Index, Node_Path);
         end if;
         Files.Model.Tree_Set_Expanded (Model, Index, True);

         declare
            Operation : constant Files.Operations.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Node_Path);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
         end;
      end;
   end Handle_Tree_Click;
