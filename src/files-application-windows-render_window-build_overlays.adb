with Files.Overlays;
separate (Files.Application.Windows.Render_Window)
   procedure Build_Overlays is
      Snapshot    : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Drawn_Slot);
      Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
   begin
      if Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Command_Palette_Overlay) then
         declare
            Layout : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (Snapshot, Natural (Width), Natural (Height), Line_Height);
         begin
            Palette.Shown := True;
            Files.Overlays.Build_Palette_Frame
              (Model         => Runtime.Model,
               Region        =>
                 (X           => Layout.Command_X,
                  Y           => Layout.Command_Y,
                  Width       => Layout.Command_Width,
                  Height      => Layout.Command_Height,
                  Clip_Width  => Natural (Width),
                  Clip_Height => Natural (Height),
                  Line_Height => Line_Height),
               Focused       => Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Command_Palette,
               Rectangles    => Palette.Rectangles,
               Text          => Palette.Text,
               Icons         => Palette.Icons,
               Accessibility => Palette.Accessibility);
         end;
      end if;
      if Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Settings_Pane_Overlay) then
         declare
            Layout : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (Snapshot, Natural (Width), Natural (Height), Line_Height);
            Pane : constant Guikit.Layout.Settings_Pane_Layout :=
              Guikit.Layout.Calculate_Settings_Pane_Layout
                (Natural (Width), Natural (Height), Layout.Toolbar_Height, Line_Height);
         begin
            Settings.Shown := True;
            Files.Overlays.Build_Settings_Frame
              (Model         => Runtime.Model,
               Region        =>
                 (X           => Pane.X,
                  Y           => Pane.Y,
                  Width       => Pane.Width,
                  Height      => Pane.Height,
                  Clip_Width  => Natural (Width),
                  Clip_Height => Natural (Height),
                  Line_Height => Line_Height),
               Focused       => Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Settings_Input,
               Hover_X       =>
                 (if Runtime.Cached_Inputs.Has_Hover then Integer (Runtime.Cached_Inputs.Hover_X) else -1),
               Hover_Y       =>
                 (if Runtime.Cached_Inputs.Has_Hover then Integer (Runtime.Cached_Inputs.Hover_Y) else -1),
               Rectangles    => Settings.Rectangles,
               Text          => Settings.Text,
               Accessibility => Settings.Accessibility);
         end;
      end if;
   end Build_Overlays;
