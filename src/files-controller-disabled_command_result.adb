separate (Files.Controller)
   function Disabled_Command_Result
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      function Disabled_Operation (Error_Key : String) return Files.Operations.Operation_Result is
      begin
         Files.Model.Set_Error (Model, Error_Key);
         return
           (Status    => Files.Operations.Operation_Disabled,
            Error_Key => To_Unbounded_String (Error_Key),
            Path      => Null_Unbounded_String,
            Action    => Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            others    => <>);
      end Disabled_Operation;
   begin
      case Id is
         when Files.Commands.Navigate_Back_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.history.back_unavailable"));
         when Files.Commands.Navigate_Forward_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.history.forward_unavailable"));
         when Files.Commands.Open_Selected_Items_Command
            | Files.Commands.Delete_Selected_Items_Command
            | Files.Commands.Toggle_Info_Pane_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.selection.empty"));
         when Files.Commands.Rename_Selected_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.rename.disabled"));
         when Files.Commands.Create_File_Command | Files.Commands.New_Folder_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.create.pending"));
         when Files.Commands.Clear_Filter_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.filter.empty"));
         when Files.Commands.Open_Selected_Root_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.root.selection.empty"));
         when Files.Commands.Eject_Selected_Root_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.root.eject_unavailable"));
         when Files.Commands.Save_Settings_Command | Files.Commands.Reset_Settings_Command =>
            return Settings_Closed_Result (Id, Model);
         when others =>
            return Make_Result (Controller_Ignored, Id);
      end case;
   end Disabled_Command_Result;
