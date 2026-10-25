separate (Files_Suite.Model)
   procedure Test_Create_File_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      --  A pending "untitled 2.txt" create in a filtered, empty listing.
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes temporary rename cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "F2 cancels pending temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 clears temporary rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "F2 clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "F2 removes temporary item from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 2.txt")), "F2 does not create a file");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Create_File_Command,
         "Control+N routes create-file command");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N adds temporary item");
      Files.Model.Cancel_Create_File (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "direct create cancel clears rename focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N can add temporary item after direct cancel");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path focus can move away from create");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Escape clears path focus during create");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item after path focus");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears create rename after path focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "path-focus Escape removes temporary item from projection");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "create Escape reports successful state-only cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears temporary rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "Escape clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "cancelled temporary item disappears from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 3.txt")), "Escape does not create a file");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "temporary-row item click reports successful context cancel");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "temporary-row item click cancels pending create");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "temporary-row item click does not leave a zero selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "temporary-row item click removes the only visible row");
   end Test_Create_File_Cancellation;
