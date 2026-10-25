separate (Files_Suite.Model)
   procedure Test_Main_View_Scroll_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Model.Select_Visible (Model, 1);

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'Last);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large main scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         Natural'Last,
         "large main scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'First);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large negative main scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "large negative main scroll clamps to top");
      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Set_Main_View_Scroll_Lines (Model, 0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "holding an unmoved main scrollbar does not revise the model");
      end;
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over main view");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "wheel scrolls the open settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "settings wheel scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "auto scroll reaches the settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "settings auto scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks targeted main scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked targeted scroll leaves main view still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks main PageDown");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked PageDown leaves main view still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before command click checks");
   end Test_Main_View_Scroll_And_Settings_Block;
