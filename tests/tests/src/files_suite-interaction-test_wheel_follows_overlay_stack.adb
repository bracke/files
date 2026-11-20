with Files.Input_Actions;
with Files.Settings_Form;
with Files.Rendering.Layouts;
with Files.Model.Command_Palette;
with Files.Model.Settings_Pane;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   --  The wheel goes to the overlay on top of Files.UI_Types.Overlay_Stack, as
   --  clicks and keys do: a paste dialog over the palette swallows it, the
   --  palette over the settings pane takes it, and a targeted scroll of a
   --  region that is not the top overlay's own is contained.
   procedure Test_Wheel_Follows_Overlay_Stack (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      declare
         Base    : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Overlay : Files.Rendering.View_Snapshot := Base;
         Layout  : Files.Rendering.Layout_Metrics;
         Palette : Files.Rendering.Layouts.Command_Palette_Layout;

         function Wheel_At_Palette return Files.Input_Actions.Input_Action is
           (Files.Events.Translate_Scroll_At
              (Overlay,
               Palette.Results_X + Palette.Results_Width / 2,
               Palette.Results_Y + Palette.Results_Height / 2,
               Target_W, Target_H, Y_Offset => 1, Line_Height => Line));
      begin
         Overlay.Command_Palette_Open := True;
         Layout := Files.Rendering.Layouts.Calculate_Layout (Overlay, Target_W, Target_H, Line);
         Palette := Files.Rendering.Layouts.Calculate_Command_Palette_Layout (Layout, Line);
         Assert (Palette.Results_Width > 0 and then Palette.Results_Height > 0, "the palette lists results");
         Files_Suite.Support.Assert_Equal
           (Wheel_At_Palette.Kind, Files.Input_Actions.Scroll_Input_Action,
            "the wheel over the palette's results scrolls");

         --  The settings pane under the palette changes nothing: the palette is on top.
         Overlay.Settings_Pane_Open := True;
         Files_Suite.Support.Assert_Equal
           (Wheel_At_Palette.Kind, Files.Input_Actions.Scroll_Input_Action,
            "the palette over the pane keeps the wheel");

         --  A paste dialog stacks above the palette and takes the wheel from it.
         Overlay.Paste_Conflict_Open := True;
         Files_Suite.Support.Assert_Equal
           (Wheel_At_Palette.Kind, Files.Input_Actions.No_Input_Action,
            "a paste dialog over the palette swallows the wheel");
      end;

      --  The window layer draws only the top one of the palette and the pane.
      Files.Settings_Form.Begin_Edit (Model, Settings);
      Assert (Files.Model.Window_Overlay_Shown (Model, Files.UI_Types.Settings_Pane_Overlay),
              "the settings pane alone is drawn");
      Files.Model.Command_Palette.Open (Model);
      Assert (Files.Model.Window_Overlay_Shown (Model, Files.UI_Types.Command_Palette_Overlay)
              and then not Files.Model.Window_Overlay_Shown (Model, Files.UI_Types.Settings_Pane_Overlay),
              "the palette over the pane is drawn, the pane under it is not");

      --  A targeted scroll of a region the top overlay does not own is contained.
      declare
         Main_Before : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
         Result      : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Targeted_Scroll (Model, Files.Input_Actions.Scroll_Settings_Pane, 1);
      begin
         Files_Suite.Support.Assert_Equal
           (Result.Status, Files.Controller.Controller_Ignored, "the pane under the palette does not scroll");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model), Main_Before, "nothing behind the palette moves");
      end;
   end Test_Wheel_Follows_Overlay_Stack;
