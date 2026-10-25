separate (Files_Suite.Interaction)
   --  Text entry: the shell's real typed-character path is
   --  Files.Controller.Append_Focused_Text on whatever input is focused (only
   --  fetching the bytes from the OS is GLFW-bound), so it is exercised here.
   procedure Test_Text_Entry_Updates_Focused_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Roots    : Files.Types.String_Vectors.Vector;
   begin
      Files.Model.Focus_Filter_Input (Model);
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "rep");
      begin
         Files_Suite.Support.Assert_Equal
           (Outcome.Status, Files.Controller.Controller_Text_Updated,
            "typed text lands in the focused filter input (status)");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Filter_Text (Model),
         "rep",
         "typed text lands in the focused filter input");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Focus_Command_Palette_Input (Model);
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "view");
      begin
         Files_Suite.Support.Assert_Equal
           (Outcome.Status, Files.Controller.Controller_Text_Updated,
            "typed text lands in the command-palette input (status)");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Palette_Query (Model),
         "view",
         "typed text lands in the command-palette input");

      --  The root selector is allowed to remain beneath the command palette.
      --  Its modal key guard must not intercept editing keys owned by the
      --  visible palette above it.
      Files.Model.Close_Command_Palette (Model);
      Roots.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Files.Model.Current_Path (Model)));
      Files.Model.Open_Root_Selector (Model, Roots);
      Files.Model.Open_Command_Palette (Model);
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Append_Focused_Text (Model, "find");
      begin
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Text_Updated,
            "printable text edits the palette stacked above the root selector");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Palette_Query (Model),
         "find",
         "the stacked palette receives native character input");
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Backspace);
      begin
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Text_Updated,
            "Backspace edits the palette stacked above the root selector");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Palette_Query (Model),
         "fin",
         "the stacked palette query loses its final character");
      Assert
        (Files.Model.Root_Selector_Is_Open (Model)
         and then Files.Model.Command_Palette_Is_Open (Model),
         "editing the stacked palette preserves both overlay states");
   end Test_Text_Entry_Updates_Focused_Input;
