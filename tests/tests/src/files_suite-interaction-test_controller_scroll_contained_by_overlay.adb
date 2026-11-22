with Files.Model.Info_Pane;
with Files.Input_Actions;
with Files.Rendering.Layouts;
with Files.Model.Sort_Menu;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   procedure Test_Controller_Scroll_Contained_By_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Replay_Targeted_Scroll (Model, Settings);

      --  A non-scrolling overlay on top swallows the wheel wherever it is: the
      --  translator gives no scroll and the direct targeted entry refuses.
      declare
         Main_Before : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
         Info_Before : constant Natural := Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model);
         Outcome     : Files.Controller.Controller_Result;
      begin
         Files.Model.Sort_Menu.Toggle (Model);
         declare
            Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Layouts.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
            Info     : constant Files.Rendering.Layouts.Info_Pane_Layout :=
              Files.Rendering.Layouts.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
         begin
            Files_Suite.Support.Assert_Equal
              (Files.Events.Translate_Scroll_At
                 (Snapshot, Layout.Main_X + Layout.Main_Width / 2, Layout.Main_Y + Layout.Main_Height / 2,
                  Target_W, Target_H, Y_Offset => -1, Line_Height => Line).Kind,
               Files.Input_Actions.No_Input_Action,
               "the wheel over the main view is swallowed by the sort menu");
            Scroll_Down_At (Model, Settings, Info.X + Info.Width / 2, Info.Y + Info.Height / 2);
         end;
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model), Main_Before,
            "the wheel is contained while a non-scrolling overlay owns input (main view scroll)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), Info_Before,
            "the wheel is contained while a non-scrolling overlay owns input (info pane scroll)");
         Outcome :=
           Files.Controller.Handle_Targeted_Scroll
             (Model, Files.Input_Actions.Scroll_Main_View, 3);
         Assert
           (Outcome.Status = Files.Controller.Controller_Ignored
            and then Files.Model.Main_View_Scroll_Lines (Model) = Main_Before,
            "direct targeted scrolling cannot move content behind an overlay");
         Files.Model.Sort_Menu.Close (Model);
      end;
   end Test_Controller_Scroll_Contained_By_Overlay;
