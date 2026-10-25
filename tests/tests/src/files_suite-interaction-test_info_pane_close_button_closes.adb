separate (Files_Suite.Interaction)
   --  Same seam for the info pane: open it, derive its close (X) button from
   --  the real info-pane layout (kept clear of the scrollbar column), click the
   --  button's center, and assert the pane closed.
   procedure Test_Info_Pane_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Info_Pane_Is_Open (Model), "the info pane is open before the close click");
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
         Panel_W  : constant Natural :=
           (if Info.Scrollbar_Visible and then Info.Width > Info.Scrollbar_Width
            then Info.Width - Info.Scrollbar_Width
            else Info.Width);
         Close    : constant Files.Rendering.Close_Button_Layout :=
           Files.Rendering.Panel_Close_Button (Info.X, Info.Y, Panel_W, Info.Height, Line);
      begin
         Assert (Close.Visible, "the open info pane exposes a close (X) button");
         Click
           (Model, Settings, Close.X + Close.Width / 2, Close.Y + Close.Height / 2,
            Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (not Files.Model.Info_Pane_Is_Open (Model),
         "clicking the info-pane close (X) button closes the info pane");
   end Test_Info_Pane_Close_Button_Closes;
