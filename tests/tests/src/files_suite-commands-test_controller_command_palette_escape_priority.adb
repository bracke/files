separate (Files_Suite.Commands)
   procedure Test_Controller_Command_Palette_Escape_Priority (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Select_Visible (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "F2 enters rename before palette opens");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "Control+P routes from rename input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette over rename state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Command_Palette,
         "palette takes focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Palette_Updated,
         "Escape first updates palette state");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape first closes palette");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "Escape closes the open palette");
      Assert (Files.Model.Rename_Is_Active (Model), "Escape does not cancel rename while palette is open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "closed palette clears palette focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "second Escape routes context cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "second Escape cancels pending rename");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model),
         0,
         "second Escape clears stale rename cursor");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "second Escape leaves focus clear");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Rename_Input, Cursor_Position => 2);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "inactive rename text click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "inactive rename text click does not focus input");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Controller.Controller_Ignored, "idle Escape is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "idle Escape still reports context command");
   end Test_Controller_Command_Palette_Escape_Priority;
