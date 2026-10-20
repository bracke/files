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
            | Files.Commands.Toggle_Info_Pane_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.selection.empty"));
         when Files.Commands.Delete_Selected_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if Files.Model.Selected_Count (Model) = 0
                    then "error.selection.empty"
                    else "error.trash.failed"));
         when Files.Commands.Cut_Selected_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if Files.Model.Selected_Count (Model) = 0
                    then "error.selection.empty"
                    else "error.drop.invalid_source"));
         when Files.Commands.Rename_Selected_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.rename.disabled"));
         when Files.Commands.Create_File_Command | Files.Commands.New_Folder_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if Files.Model.Temporary_Item_Is_Active (Model)
                    then "error.create.pending"
                    else "error.file.parent_missing"));
         when Files.Commands.Paste_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if not Files.Model.Clipboard_Has_Items (Model)
                    then "error.drop.invalid_source"
                    elsif Files.Model.Temporary_Item_Is_Active (Model)
                    then "error.create.pending"
                    else "error.drop.invalid_destination"));
         when Files.Commands.Toggle_Favorite_Command =>
            if Files.Model.Selection_Includes_Temporary (Model) then
               return
                 Make_Result
                   (Controller_Ignored, Id,
                    Disabled_Operation ("error.create.pending"));
            else
               return Make_Result (Controller_Ignored, Id);
            end if;
         when Files.Commands.Duplicate_Selected_Command
            | Files.Commands.Compress_Zip_Command
            | Files.Commands.Compress_7z_Command
            | Files.Commands.Extract_Archive_Command
            | Files.Commands.Create_Symlink_Command
            | Files.Commands.Create_Hardlink_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if Files.Model.Selection_Includes_Temporary (Model)
                    then "error.create.pending"
                    elsif Files.Model.Selected_Count (Model) = 0
                    then "error.selection.empty"
                    else
                      (case Id is
                          when Files.Commands.Duplicate_Selected_Command =>
                            "error.duplicate.failed",
                          when Files.Commands.Compress_Zip_Command
                             | Files.Commands.Compress_7z_Command =>
                            "error.compress.failed",
                          when Files.Commands.Extract_Archive_Command =>
                            "error.extract.failed",
                          when others =>
                            "error.link.failed")));
         when Files.Commands.Clear_Filter_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.filter.empty"));
         when Files.Commands.Search_Recursive_Command | Files.Commands.Search_Contents_Command =>
            return
              Make_Result
                (Controller_Ignored, Id,
                 Disabled_Operation
                   (if Files.Model.Filter_Text (Model) = ""
                    then "error.filter.empty"
                    else "error.directory.load"));
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
