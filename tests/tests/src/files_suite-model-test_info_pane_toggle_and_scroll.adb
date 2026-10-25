separate (Files_Suite.Model)
   procedure Test_Info_Pane_Toggle_And_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;

      --  The info pane can always be toggled, even with nothing selected.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "Control+4 routes info-pane command with no selection");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "Control+4 toggles the info pane with no selection");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane opens without a selection");
      --  Close it again, then reopen with a selection so the rest of the
      --  scenario starts from an open, selection-backed info pane.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second Control+4 closes the info pane");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "Control+4 routes info-pane command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane toggles open");
      Files_Suite.Support.Assert_Equal (Files.Model.Info_Pane_Scroll_Lines (Model), 0, "info pane opens unscrolled");

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Set_Info_Pane_Scroll_Lines (Model, 0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "holding an unmoved info-pane scrollbar does not revise the model");
      end;

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "PageUp at top of info pane is ignored");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "ignored info-pane PageUp leaves the model revision unchanged");
      end;

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, -1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "negative info scroll at top is ignored");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "PageDown pages info pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         10,
         "PageDown scrolls info pane by page");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'Last);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large info scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         Natural'Last,
         "large info scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'First);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large negative info scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "large negative info scroll clamps to top");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         10,
         "info pane scroll resumes after saturation");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "PageUp pages info pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "PageUp scrolls info pane back to top");
   end Test_Info_Pane_Toggle_And_Scroll;
