separate (Files_Suite.Commands)
   procedure Test_Controller_Rename_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "F2 executes rename command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 reports rename command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Rename_Input,
         "F2 focuses rename input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         3,
         "F2 places rename cursor before the file extension");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         Files.Model.Rename_Text (Model)'Length,
         "End moves the rename cursor to the end of the name");
      Result := Files.Controller.Append_Focused_Text (Model, ".bak");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "rename append works immediately after F2");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "old.txt.bak",
         "initial rename cursor appends text at the end");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "rename Left moves cursor");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "new.ttx",
         "rename insert uses cursor position");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "rename append updates text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "new.tttx",
         "rename second insert advances cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Text_Updated,
         "rename Backspace edits text");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "new.ttx",
         "rename Backspace removes character before cursor");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "new.tt",
         "rename Delete removes character at cursor");
      Files.Controller.Replace_Focused_Text (Model, "new.tx");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         6,
         "rename replacement clamps cursor to text end");
      Result := Files.Controller.Append_Focused_Text (Model, "t");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "new.txt",
         "rename append restores commit text");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "rename Return executes rename command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "rename Return reports rename command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "Return commits rename");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "rename file exists after Return");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename Return clears rename mode");
   end Test_Controller_Rename_Return;
