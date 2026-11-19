with Files.Overlays;
with Files.Rendering.Layouts;
separate (Files.Application.Windows.Render_Window)
   procedure Build_Overlays is
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      --  The frame Refresh_Cached_Frame just built for this size and snapshot.
      Layout      : Files.Rendering.Layout_Metrics renames Runtime.Cached_Frame.Layout;
      Pointer     : Files.Rendering.Pointer_State renames Runtime.Cached_Inputs.Pointer;

      --  What an overlay drawn in a region, with or without the pointer's
      --  hover, is built from in this pass.
      function Inputs_For
        (X, Y, Region_W, Region_H : Natural;
         Focused                  : Boolean;
         Hover                    : Boolean)
         return Overlay_Inputs is
        (Model_Revision => Files.Model.Revision (Runtime.Model),
         Settings_Key   => Runtime.View.Cached_Settings_Key,
         Region         =>
           (X           => X,
            Y           => Y,
            Width       => Region_W,
            Height      => Region_H,
            Clip_Width  => Natural (Width),
            Clip_Height => Natural (Height),
            Line_Height => Line_Height),
         Focused        => Focused,
         Hover_X        => (if Hover and then Pointer.Has_Hover then Integer (Pointer.Hover_X) else -1),
         Hover_Y        => (if Hover and then Pointer.Has_Hover then Integer (Pointer.Hover_Y) else -1));
   begin
      --  Each overlay's commands stand until what they are built from moves;
      --  a hidden overlay is built afresh when it shows again.
      Palette.Shown := Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Command_Palette_Overlay);
      if Palette.Shown then
         declare
            Inputs : constant Overlay_Inputs :=
              Inputs_For
                (Layout.Command_X, Layout.Command_Y, Layout.Command_Width, Layout.Command_Height,
                 Focused => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Command_Palette,
                 Hover   => False);
         begin
            if not Runtime.Palette_Overlay_Built or else Inputs /= Runtime.Palette_Overlay_From then
               Files.Overlays.Build_Palette_Frame
                 (Model         => Runtime.Model,
                  Region        => Inputs.Region,
                  Focused       => Inputs.Focused,
                  Rectangles    => Palette.Rectangles,
                  Text          => Palette.Text,
                  Icons         => Palette.Icons,
                  Accessibility => Palette.Accessibility);
               Runtime.Palette_Overlay_From := Inputs;
               Runtime.Palette_Overlay_Built := True;
            end if;
         end;
      elsif Runtime.Palette_Overlay_Built then
         Palette := (others => <>);
         Runtime.Palette_Overlay_Built := False;
      end if;

      Settings.Shown := Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Settings_Pane_Overlay);
      if Settings.Shown then
         declare
            Pane   : constant Guikit.Layout.Settings_Pane_Layout :=
              Files.Rendering.Layouts.Settings_Pane_Region (Layout, Line_Height);
            Inputs : constant Overlay_Inputs :=
              Inputs_For
                (Pane.X, Pane.Y, Pane.Width, Pane.Height,
                 Focused => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Settings_Input,
                 Hover   => True);
         begin
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
      elsif Runtime.Settings_Overlay_Built then
         Settings := (others => <>);
         Runtime.Settings_Overlay_Built := False;
      end if;
   end Build_Overlays;
