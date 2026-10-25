separate (Files_Suite.Commands)
   procedure Test_Controller_Path_Input_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "path-target");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "loaded.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Error (Model, "error.path.missing");
      Ctrl (Guikit.Input.Control_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_L, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "Control+L executes focus command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Path_Input_Command,
         "Control+L focuses path input");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), "", "path focus clears stale error state");
      Files.Model.Begin_Create_File (Model, "path-pending.txt");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         0,
         "path replacement places cursor at text end");
      Result := Files.Controller.Append_Focused_Text (Model, Root);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "path input append updates text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "path input append uses focused path field");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         Root'Length,
         "path append advances cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "Control+P routes through command registry from path input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette from path input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "palette shortcut preserves edited path input text");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape closes palette after path shortcut");
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, Join (Root, "missing-path-target"));
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "invalid path input Return executes path command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Path_Input_Command,
         "invalid path input Return reports path command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "invalid path input returns failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         "",
         "missing path input has no operation path");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.path.missing",
         "invalid path input reports path diagnostic");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "invalid controller path input does not navigate");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "invalid path input keeps focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "invalid path input records error");
      Assert (not Files.Model.Path_Input_Is_Valid (Model), "invalid path input marks validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "error.path.missing",
         "invalid path input stores validation diagnostic");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid path input preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid path input preserves rename state");

      Files.Controller.Replace_Focused_Text (Model, Target);
      Assert (Files.Model.Path_Input_Is_Valid (Model), "path input edit clears stale validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "path input edit clears stale validation diagnostic");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "modified Return does not commit path input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "modified Return in path input does not navigate");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "modified Return keeps path input focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "path input Return executes path command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Path_Input_Command,
         "path input Return reports path command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "Return commits path input");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Target),
         "path input operation reports normalized target path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "path input navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "path input success clears stale error state");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "path input loads destination items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "path input commit clears focus");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "path input success clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "path input success clears rename state");

      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, Join (Target, "loaded.txt"));
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "file path input Return executes path command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "file path input navigates to parent directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Target),
         "file path input operation reports normalized parent directory");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "file path input changes model to parent directory");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "file path input loads parent directory items");
   end Test_Controller_Path_Input_Return;
