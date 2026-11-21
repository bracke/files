with Files.Overlays;
with Files.Rendering.Layouts;
separate (Files.Application.Windows.Render_Window)
   procedure Build_Overlays is
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      --  The frame Refresh_Cached_Frame just built for this size and snapshot.
      Layout      : Files.Rendering.Layout_Metrics renames Runtime.Cached_Frame.Layout;
      Pointer     : Files.Rendering.Pointer_State renames Overlay_Pointer;
      Pane        : constant Guikit.Layout.Settings_Pane_Layout :=
        Files.Rendering.Layouts.Settings_Pane_Region (Layout, Line_Height);

      --  What an overlay drawn in a region, with or without the pointer's
      --  hover, is built from in this pass. The pointer counts only over the
      --  region: elsewhere it hovers nothing the overlay draws.
      function Inputs_For
        (X, Y, Region_W, Region_H : Natural;
         Focused                  : Boolean;
         Hover                    : Boolean)
         return Overlay_Inputs
      is
         Over : constant Boolean :=
           Hover and then Pointer.Has_Hover
           and then Pointer.Hover_X >= X and then Pointer.Hover_X - X < Region_W
           and then Pointer.Hover_Y >= Y and then Pointer.Hover_Y - Y < Region_H;
      begin
         return
           (Model_Revision    => Files.Model.Revision (Runtime.Model),
            Settings_Revision => Files.Model.Settings_Revision (Runtime.Model),
            Region            =>
              (X           => X,
               Y           => Y,
               Width       => Region_W,
               Height      => Region_H,
               Clip_Width  => Natural (Width),
               Clip_Height => Natural (Height),
               Line_Height => Line_Height),
            Focused           => Focused,
            Hover_X           => (if Over then Integer (Pointer.Hover_X) else -1),
            Hover_Y           => (if Over then Integer (Pointer.Hover_Y) else -1));
      end Inputs_For;

      --  Keep an overlay's commands while it is shown and what they are built
      --  from stands, build them when it moved or the overlay was hidden,
      --  and drop them when it is hidden. Building or dropping them is a
      --  change the present gate looks at (Overlay_Changed).
      procedure Refresh
        (Overlay : in out Overlay_Commands;
         Built   : in out Boolean;
         From    : in out Overlay_Inputs;
         Shown   : Boolean;
         Inputs  : Overlay_Inputs;
         Build   : not null access procedure (Inputs : Overlay_Inputs; Into : in out Overlay_Commands)) is
      begin
         Overlay.Shown := Shown;
         if Shown then
            if not Built or else Inputs /= From then
               Build (Inputs, Overlay);
               From := Inputs;
               Built := True;
               Overlay_Changed := True;
            end if;
         elsif Built then
            Overlay := (others => <>);
            Built := False;
            Overlay_Changed := True;
         end if;
      end Refresh;

      procedure Build_Palette (Inputs : Overlay_Inputs; Into : in out Overlay_Commands) is
      begin
         Files.Overlays.Build_Palette_Frame
           (Model         => Runtime.Model,
            Region        => Inputs.Region,
            Focused       => Inputs.Focused,
            Rectangles    => Into.Rectangles,
            Text          => Into.Text,
            Icons         => Into.Icons,
            Accessibility => Into.Accessibility);
      end Build_Palette;

      procedure Build_Settings (Inputs : Overlay_Inputs; Into : in out Overlay_Commands) is
      begin
         Files.Overlays.Build_Settings_Frame
           (Model         => Runtime.Model,
            Region        => Inputs.Region,
            Focused       => Inputs.Focused,
            Hover_X       => Inputs.Hover_X,
            Hover_Y       => Inputs.Hover_Y,
            Fields        => Runtime.Settings_Fields,
            Rectangles    => Into.Rectangles,
            Text          => Into.Text,
            Accessibility => Into.Accessibility);
      end Build_Settings;
   begin
      --  Each overlay's commands stand until what they are built from moves;
      --  a hidden overlay is built afresh when it shows again.
      Refresh
        (Overlay => Palette,
         Built   => Runtime.Palette_Overlay_Built,
         From    => Runtime.Palette_Overlay_From,
         Shown   => Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Command_Palette_Overlay),
         Inputs  =>
           Inputs_For
             (Layout.Command_X, Layout.Command_Y, Layout.Command_Width, Layout.Command_Height,
              Focused => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Command_Palette,
              Hover   => False),
         Build   => Build_Palette'Access);
      Refresh
        (Overlay => Settings,
         Built   => Runtime.Settings_Overlay_Built,
         From    => Runtime.Settings_Overlay_From,
         Shown   => Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Settings_Pane_Overlay),
         Inputs  =>
           Inputs_For
             (Pane.X, Pane.Y, Pane.Width, Pane.Height,
              Focused => Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Settings_Input,
              Hover   => True),
         Build   => Build_Settings'Access);
   end Build_Overlays;
