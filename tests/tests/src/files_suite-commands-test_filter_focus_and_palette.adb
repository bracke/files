separate (Files_Suite.Commands)
   procedure Test_Filter_Focus_And_Palette (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "filter focus executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Focus_Filter_Input_Command,
         "filter command is routed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "filter focus clears stale error state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "filter focus closes command palette");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "filter input receives focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "Control+P executes while filter input has focus");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "Control+P routes through command registry from filter input");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "Control+P opens palette from filter input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Command_Palette,
         "Control+P transfers focus from filter input to palette");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape closes palette after filter shortcut");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "palette closes before filter editing resumes");
   end Test_Filter_Focus_And_Palette;
