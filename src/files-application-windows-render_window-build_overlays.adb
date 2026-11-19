with Files.Overlays;
with Files.Rendering.Layouts;
separate (Files.Application.Windows.Render_Window)
   procedure Build_Overlays is
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      --  The frame Refresh_Cached_Frame just built for this size and snapshot.
      Layout      : Files.Rendering.Layout_Metrics renames Runtime.Cached_Frame.Layout;
   begin
      if Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Command_Palette_Overlay) then
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
            Focused       => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Command_Palette,
            Rectangles    => Palette.Rectangles,
            Text          => Palette.Text,
            Icons         => Palette.Icons,
            Accessibility => Palette.Accessibility);
      end if;
      Settings.Shown := Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Settings_Pane_Overlay);
      if Settings.Shown then
         declare
            Pane : constant Guikit.Layout.Settings_Pane_Layout :=
              Files.Rendering.Layouts.Settings_Pane_Region (Layout, Line_Height);
            Pointer : Files.Rendering.Pointer_State renames Runtime.Cached_Inputs.Pointer;
            Inputs  : constant Settings_Overlay_Inputs :=
              (Model_Revision => Files.Model.Revision (Runtime.Model),
               Settings_Key   => Runtime.View.Cached_Settings_Key,
               Region         =>
                 (X           => Pane.X,
                  Y           => Pane.Y,
                  Width       => Pane.Width,
                  Height      => Pane.Height,
                  Clip_Width  => Natural (Width),
                  Clip_Height => Natural (Height),
                  Line_Height => Line_Height),
               Focused        => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Settings_Input,
               Hover_X        => (if Pointer.Has_Hover then Integer (Pointer.Hover_X) else -1),
               Hover_Y        => (if Pointer.Has_Hover then Integer (Pointer.Hover_Y) else -1));
         begin
            --  The panel's commands stand until what they are built from moves.
            if not Runtime.Settings_Overlay_Built or else Inputs /= Runtime.Settings_Overlay_From then
               Files.Overlays.Build_Settings_Frame
                 (Model         => Runtime.Model,
                  Region        => Inputs.Region,
                  Focused       => Inputs.Focused,
                  Hover_X       => Inputs.Hover_X,
                  Hover_Y       => Inputs.Hover_Y,
                  Rectangles    => Settings.Rectangles,
                  Text          => Settings.Text,
                  Accessibility => Settings.Accessibility);
               Runtime.Settings_Overlay_From := Inputs;
               Runtime.Settings_Overlay_Built := True;
            end if;
         end;
      end if;
   end Build_Overlays;
