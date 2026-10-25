separate (Files_Suite.Interaction)
   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Replay_Targeted_Scroll (Model, Settings);

      --  Controller entry points must preserve the same overlay ownership rule
      --  when no pointer geometry is available (for example while minimized).
      declare
         Main_Before : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
         Info_Before : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
         Outcome     : Files.Controller.Controller_Result;
      begin
         Files.Model.Toggle_Sort_Menu (Model);
         Outcome := Files.Controller.Handle_Scroll (Model, 3);
         Files_Suite.Support.Assert_Equal
           (Outcome.Status, Files.Controller.Controller_Ignored,
            "auto scrolling is contained while a non-scrolling overlay owns input (status)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model), Main_Before,
            "auto scrolling is contained while a non-scrolling overlay owns input (main view scroll)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Info_Pane_Scroll_Lines (Model), Info_Before,
            "auto scrolling is contained while a non-scrolling overlay owns input (info pane scroll)");
         Outcome :=
           Files.Controller.Handle_Targeted_Scroll
             (Model, Files.Events.Scroll_Main_View, 3);
         Assert
           (Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Main_View_Scroll_Lines (Model) = Main_Before,
            "direct targeted scrolling cannot move content behind an overlay");
         Files.Model.Close_Sort_Menu (Model);
      end;
   end Test_Controller_Scroll_Contained_By_Overlay;
