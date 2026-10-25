separate (Files_Suite.Model)
   procedure Test_Info_Pane_Scroll_Resets_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      --  Start from an open, selection-backed, unscrolled info pane.
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);

      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         3,
         "info pane can scroll before selection changes");
      Files.Model.Select_Visible (Model, 2);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "single selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "toggle selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "range selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Clear_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "clear selection resets info pane scroll");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over info pane");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "wheel scrolls the open settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "settings wheel scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "auto scroll reaches the settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "settings auto scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks targeted info scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "blocked targeted scroll leaves info pane still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background PageDown");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "blocked PageDown leaves info pane still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after scroll block checks");
   end Test_Info_Pane_Scroll_Resets_And_Settings_Block;
