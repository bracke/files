separate (Files_Suite.Interaction)
   --  Open the command palette, derive its close (X) button from the real
   --  palette layout, click the button's center through the shell's
   --  Translate_Click -> Apply_Input_Action path, and assert the palette closed.
   procedure Test_Command_Palette_Close_Button_Closes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Model.Open_Command_Palette (Model);
      Assert (Files.Model.Command_Palette_Is_Open (Model), "the command palette is open before the close click");
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
         Clicked  : constant Boolean := Files.Model.Palette_Click (Model, -1, -1);
      begin
         Assert
           (not Clicked and then Files.Model.Revision (Model) = Revision,
            "a command-palette miss does not advance the model revision");
      end;
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Palette  : constant Files.Rendering.Command_Palette_Layout :=
           Files.Rendering.Calculate_Command_Palette_Layout (Layout, Line);
         Close    : constant Files.Rendering.Close_Button_Layout :=
           Files.Rendering.Panel_Close_Button
             (Palette.X, Palette.Y, Palette.Width, Palette.Height, Line);
         P_Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         P_Text  : Guikit.Draw.Text_Command_Vectors.Vector;
         P_Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
         P_Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Palette_Build_Frame
           (Model         => Model,
            Region_X      => Palette.X,
            Region_Y      => Palette.Y,
            Region_Width  => Palette.Width,
            Region_Height => Palette.Height,
            Clip_Width    => Window_W,
            Clip_Height   => Window_H,
            Line_Height   => Line,
            Focused       => True,
            Rectangles    => P_Rects,
            Text          => P_Text,
            Icons         => P_Icons,
            Accessibility => P_Nodes);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Revision,
            "building a palette frame does not manufacture a semantic model revision");
         Assert (Close.Visible, "the open command palette exposes a close (X) button");
         Click
           (Model, Settings, Close.X + Close.Width / 2, Close.Y + Close.Height / 2,
            Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (not Files.Model.Command_Palette_Is_Open (Model),
         "clicking the palette close (X) button closes the command palette");
   end Test_Command_Palette_Close_Button_Closes;
