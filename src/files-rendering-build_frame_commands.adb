with Files.Extension_Labels;
with Guikit.List_Panel;

separate (Files.Rendering)
   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Build       : Natural;
      Row_Texts   : in out Row_Text_Cache;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive;
      Pointer     : Pointer_State := No_Pointer)
      return Frame_Commands
   is
      --  The draw model the frame is made of, for this body and its subunits.
      use Guikit.Draw;

      --  The pointer's parts by their own names, as the drawing reads them.
      Hover_X         : Natural renames Pointer.Hover_X;
      Hover_Y         : Natural renames Pointer.Hover_Y;
      --  Whether the pointer hovers or presses what is drawn now. An open
      --  input-owning overlay (Any_Overlay_Open) takes the pointer, so the
      --  window under it is drawn with neither (bar the button toggling the
      --  overlay on top, Toggles_Topmost_Overlay); Release_Pointer hands both to the overlay drawn above it.
      Has_Hover       : Boolean := Pointer.Has_Hover and then not Any_Overlay_Open (Snapshot);
      Has_Press       : Boolean := Pointer.Pressed and then not Any_Overlay_Open (Snapshot);
      Press_X         : Natural renames Pointer.Press_X;
      Press_Y         : Natural renames Pointer.Press_Y;
      Drag_Item_Index : Natural renames Pointer.Drag_Item_Index;
      Has_Drag        : Boolean renames Pointer.Dragging;
      Marquee_Active  : Boolean renames Pointer.Marquee_Active;
      Marquee_X       : Natural renames Pointer.Marquee_X;
      Marquee_Y       : Natural renames Pointer.Marquee_Y;
      Marquee_W       : Natural renames Pointer.Marquee_W;
      Marquee_H       : Natural renames Pointer.Marquee_H;

      Result        : Frame_Commands;
      --  The frame's regions, laid out once; each by its own name below.
      Frame         : constant Files.Rendering.Layouts.Frame_Layout :=
        Files.Rendering.Layouts.Calculate_Frame_Layout (Snapshot, Width, Height, Line_Height);
      Layout        : Layout_Metrics renames Frame.Layout;
      Main_View     : Main_View_Layout renames Frame.Main_View;
      Toolbar       : Guikit.Layout.Toolbar_Layout renames Frame.Toolbar;
      Bottom        : Guikit.Layout.Bottom_Bar_Layout renames Frame.Bottom;
      Root_Selector : Root_Selector_Layout renames Frame.Root_Selector;
      Tree_Panel    : Tree_Panel_Layout renames Frame.Tree_Panel;
      Info_Pane     : Info_Pane_Layout renames Frame.Info_Pane;
      Toolbar_Input_Y      : Natural renames Frame.Toolbar_Input_Y;
      Toolbar_Input_H      : Natural renames Frame.Toolbar_Input_H;
      Toolbar_Input_Text_Y : Natural renames Frame.Toolbar_Input_Text_Y;
      Toolbar_Input_Text_H : Natural renames Frame.Toolbar_Input_Text_H;
      Bottom_Y             : Natural renames Frame.Bottom_Y;
      Bottom_Content_Y     : Natural renames Frame.Bottom_Content_Y;
      Bottom_Content_H     : Natural renames Frame.Bottom_Content_H;

      --  The per-row layouts: items, root-selector rows, breadcrumbs and tree rows.
      --  The item cells on screen only: a frame over a large folder neither
      --  lays out nor walks the items scrolled out of view.
      Items         : constant Placed_Item_Layout :=
        Place_Item_Layout (Snapshot, Layout, Line_Height);
      Root_Rows     : constant Root_Path_Layout_Vectors.Vector :=
        Calculate_Root_Path_Layout (Snapshot, Root_Selector);
      Breadcrumb_Rows : constant Breadcrumb_Segment_Layout_Vectors.Vector :=
        Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height);
      Tree_Rows_Layout : constant Tree_Row_Layout_Vectors.Vector :=
        Calculate_Tree_Row_Layout (Snapshot, Tree_Panel, Line_Height);

      --  How much of a run starting at Start lies inside [0, Limit).
      function Clipped_Size (Start, Size, Limit : Natural) return Natural renames Guikit.Widgets.Clipped_Size;

      --  One rectangle into Target, clipped to the window; nothing when
      --  none of it is inside.
      procedure Append_Rect
        (Target : in out Rectangle_Command_Vectors.Vector;
         X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Target.Append
              (Rectangle_Command'(X => X, Y => Y, Width => Draw_W, Height => Draw_H, Color => Color));
         end if;
      end Append_Rect;

      procedure Add_Rect (X, Y, Rect_W, Rect_H : Natural; Color : Render_Color) is
      begin
         Append_Rect (Result.Rectangles, X, Y, Rect_W, Rect_H, Color);
      end Add_Rect;

      --  A filled triangle, dropped when any corner is off the frame.
      procedure Add_Triangle
        (X1    : Float;
         Y1    : Float;
         X2    : Float;
         Y2    : Float;
         X3    : Float;
         Y3    : Float;
         Color : Render_Color) is separate;

      --  Unit rim offsets of a five-pointed star, point-up, outer radius 1.0 and
      --  inner radius ~0.382 (a regular pentagram). Even indices are the outer
      --  tips, odd indices the inner notches. Screen Y grows downward, so the
      --  first point (0, -1) is the top tip.
      type Star_Rim_Offset is record
         DX : Float;
         DY : Float;
      end record;
      Star_Rim : constant array (0 .. 9) of Star_Rim_Offset :=
        [(0.0, -1.0),
         (0.2245, -0.3090),
         (0.9511, -0.3090),
         (0.3633, 0.1180),
         (0.5878, 0.8090),
         (0.0, 0.3820),
         (-0.5878, 0.8090),
         (-0.3633, 0.1180),
         (-0.9511, -0.3090),
         (-0.2245, -0.3090)];

      --  Draw a filled five-pointed star as a fan of ten triangles from the
      --  centre out to each adjacent pair of rim points.
      procedure Add_Star_Fill
        (Center_X : Float;
         Center_Y : Float;
         Radius   : Float;
         Color    : Render_Color)
      is
      begin
         for K in Star_Rim'Range loop
            declare
               A : constant Star_Rim_Offset := Star_Rim (K);
               B : constant Star_Rim_Offset := Star_Rim ((K + 1) mod 10);
            begin
               Add_Triangle
                 (Center_X, Center_Y,
                  Center_X + A.DX * Radius, Center_Y + A.DY * Radius,
                  Center_X + B.DX * Radius, Center_Y + B.DY * Radius,
                  Color);
            end;
         end loop;
      end Add_Star_Fill;

      --  Draw a straight segment of a given width as two triangles.
      procedure Add_Thick_Segment
        (X1    : Float;
         Y1    : Float;
         X2    : Float;
         Y2    : Float;
         Width : Float;
         Color : Render_Color)
      is
         DX  : constant Float := X2 - X1;
         DY  : constant Float := Y2 - Y1;
         Len : constant Float := Ada.Numerics.Elementary_Functions.Sqrt (DX * DX + DY * DY);
         NX  : constant Float := (if Len > 0.0 then -DY / Len * (Width / 2.0) else 0.0);
         NY  : constant Float := (if Len > 0.0 then DX / Len * (Width / 2.0) else 0.0);
      begin
         Add_Triangle (X1 + NX, Y1 + NY, X1 - NX, Y1 - NY, X2 - NX, Y2 - NY, Color);
         Add_Triangle (X1 + NX, Y1 + NY, X2 - NX, Y2 - NY, X2 + NX, Y2 + NY, Color);
      end Add_Thick_Segment;

      --  Draw the outline of a five-pointed star by stroking its ten edges.
      procedure Add_Star_Outline
        (Center_X : Float;
         Center_Y : Float;
         Radius   : Float;
         Width    : Float;
         Color    : Render_Color)
      is
      begin
         for K in Star_Rim'Range loop
            declare
               A : constant Star_Rim_Offset := Star_Rim (K);
               B : constant Star_Rim_Offset := Star_Rim ((K + 1) mod 10);
            begin
               Add_Thick_Segment
                 (Center_X + A.DX * Radius, Center_Y + A.DY * Radius,
                  Center_X + B.DX * Radius, Center_Y + B.DY * Radius,
                  Width, Color);
            end;
         end loop;
      end Add_Star_Outline;

      procedure Add_Overlay_Rect (X, Y, Rect_W, Rect_H : Natural; Color : Render_Color) is
      begin
         Append_Rect (Result.Overlay_Rectangles, X, Y, Rect_W, Rect_H, Color);
      end Add_Overlay_Rect;

      --  The item name as displayed in the grid. With Show_Extensions off, a
      --  file's trailing extension is dropped for display only (rename, search
      --  and accessibility keep the real name). Directories are never changed,
      --  and a name that is only a leading-dot extension -- e.g. ".bashrc" --
      --  keeps its full name, since the dot is not a separator there.
      function Displayed_Name (Item : Item_Snapshot) return UString is separate;

      --  Text cut to Capacity columns with an ellipsis: guikit's one
      --  truncation rule, which every component shares.
      function Fitted_Text_For (Text : UString; Capacity : Natural) return UString renames Guikit.Widgets.Fitted_Text;

      --  One text command into Target, its box clipped to the window and
      --  its text fitted to the box when Fit says so; Mirror_Glyph marks a
      --  one-way symbol a mirrored frame draws as its mirror image.
      procedure Append_Text
        (Target : in out Text_Command_Vectors.Vector;
         X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color;
         Fit    : Boolean;
         Scale_To_Box : Boolean;
         Italic : Boolean;
         Mirror_Glyph : Boolean := False;
         Cut_Columns  : Natural := Guikit.Draw.Auto_Cut)
 is separate;

      --  Main-layer text. Every overlay panel is drawn in the overlay layer,
      --  composited after all of the main layer, so a panel covers the text
      --  under it without the text having to be left out.
      procedure Add_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False;
         Scale_To_Box : Boolean := False;
         Italic : Boolean := False;
         Mirror_Glyph : Boolean := False;
         Cut_Columns  : Natural := Guikit.Draw.Auto_Cut) is
      begin
         Append_Text
           (Result.Text, X, Y, Text_W, Text_H, Text, Color, Fit, Scale_To_Box, Italic, Mirror_Glyph, Cut_Columns);
      end Add_Text;

      procedure Add_Overlay_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False;
         Italic : Boolean := False) is
      begin
         Append_Text (Result.Overlay_Text, X, Y, Text_W, Text_H, Text, Color, Fit, False, Italic);
      end Add_Overlay_Text;

      procedure Add_Tooltip_Text
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text     : UString);

      function Command_Tooltip_Text
        (Command : Files.Commands.Command_Id)
         return UString
 is separate;

      procedure Add_Command_Tooltip
        (X       : Natural;
         Y       : Natural;
         Tip_W   : Natural;
         Tip_H   : Natural;
         Command : Files.Commands.Command_Id) is
      begin
         Add_Tooltip_Text (X, Y, Tip_W, Tip_H, Command_Tooltip_Text (Command));
      end Add_Command_Tooltip;

      procedure Add_Tooltip_Text
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text     : UString)
      is
         Draw_W : constant Natural := Clipped_Size (X, Tip_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Tip_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Length (Text) > 0 then
            Result.Tooltips.Append
              (Tooltip_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => Text));
         end if;
      end Add_Tooltip_Text;

      procedure Add_Tooltip (X, Y, Tip_W, Tip_H : Natural; Text_Key : String) is
      begin
         Add_Tooltip_Text (X, Y, Tip_W, Tip_H, To_Unbounded_String (Files.Localization.Text (Text_Key)));
      end Add_Tooltip;

      procedure Add_Accessibility_Node
        (Role        : Accessibility_Role;
         X           : Natural;
         Y           : Natural;
         Node_W      : Natural;
         Node_H      : Natural;
         Name        : UString;
         Description : UString := Null_Unbounded_String;
         Enabled     : Boolean := True;
         Selected    : Boolean := False;
         Focused     : Boolean := False)
 is separate;

      procedure Add_Dialog_Hit
        (Kind   : Dialog_Hit_Kind;
         X      : Natural;
         Y      : Natural;
         Hit_W  : Natural;
         Hit_H  : Natural)
      is
         Draw_W : constant Natural := Clipped_Size (X, Hit_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Hit_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Dialog_Hits.Append
              (Dialog_Hit_Region'
                 (Kind   => Kind,
                  X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H));
         end if;
      end Add_Dialog_Hit;

      function Localized (Key : String) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Key));
      end Localized;

      function Path_Input_Accessible_Description return UString is
      begin
         if Snapshot.Path_Input_Valid or else Length (Snapshot.Path_Input_Error_Key) = 0 then
            return Snapshot.Path_Input_Text;
         end if;

         return
           Snapshot.Path_Input_Text
           & To_Unbounded_String (" ")
           & Localized (To_String (Snapshot.Path_Input_Error_Key));
      end Path_Input_Accessible_Description;

      function Contains_Point
        (X        : Natural;
         Y        : Natural;
         Box_W    : Natural;
         Box_H    : Natural;
         Point_X  : Natural;
         Point_Y  : Natural)
         return Boolean renames Contains_Rectangle_Point;

      --  The tooltip of the region recorded last under the point: regions are
      --  recorded in drawing order, so, like Hit.Topmost_Hit_At, the one drawn
      --  on top wins where two overlap.
      function Tooltip_At
        (Point_X : Natural;
         Point_Y : Natural)
         return UString is
      begin
         for Command of reverse Result.Tooltips loop
            if Contains_Point (Command.X, Command.Y, Command.Width, Command.Height, Point_X, Point_Y) then
               return Command.Text;
            end if;
         end loop;

         return Null_Unbounded_String;
      end Tooltip_At;

      --  Whether Command's button toggles the overlay on top: the one control
      --  under an open overlay whose click still reaches it (and closes it),
      --  so it is drawn with the pointer's hover and press (Live).
      function Toggles_Topmost_Overlay (Command : Files.Commands.Command_Id) return Boolean is separate;

      --  Whether the pointer hovers over the box at X, Y.
      function Is_Hovered (X, Y, Box_W, Box_H : Natural) return Boolean is
        (Has_Hover and then Contains_Point (X, Y, Box_W, Box_H, Hover_X, Hover_Y));
      function Is_Pressed
        (X     : Natural;
         Y     : Natural;
         Box_W : Natural;
         Box_H : Natural;
         Live  : Boolean := False)
         return Boolean is
      begin
         --  Under the pointer, and where the press began: a drag (scrollbar,
         --  column, marquee) that crosses a button does not press it.
         return (Has_Press or else (Live and then Pointer.Pressed))
           and then Contains_Point (X, Y, Box_W, Box_H, Hover_X, Hover_Y)
           and then Contains_Point (X, Y, Box_W, Box_H, Press_X, Press_Y);
      end Is_Pressed;

      procedure Add_Border
        (X        : Natural;
         Y        : Natural;
         Border_W : Natural;
         Border_H : Natural;
         Color    : Render_Color) is
      begin
         Guikit.Widgets.Draw_Border
           (Result.Rectangles, Layout.Width, Layout.Height,
            X, Y, Border_W, Border_H, Color);
      end Add_Border;

      --  Add_Border for the overlay layer: the four edge rects composite on top
      --  of an opaque overlay panel rather than under the main grid content.
      procedure Add_Overlay_Border
        (X        : Natural;
         Y        : Natural;
         Border_W : Natural;
         Border_H : Natural;
         Color    : Render_Color) is
      begin
         Guikit.Widgets.Draw_Border
           (Result.Overlay_Rectangles, Layout.Width, Layout.Height,
            X, Y, Border_W, Border_H, Color);
      end Add_Overlay_Border;

      procedure Add_Focus_Ring
        (X      : Natural;
         Y      : Natural;
         Ring_W : Natural;
         Ring_H : Natural) is
      begin
         Guikit.Widgets.Draw_Focus_Ring
           (Rectangles  => Result.Rectangles,
            Clip_Width  => Layout.Width,
            Clip_Height => Layout.Height,
            X           => X,
            Y           => Y,
            Width       => Ring_W,
            Height      => Ring_H,
            Color       => Snapshot.Theme_Focus_Ring);
      end Add_Focus_Ring;

      --  Draw an editable input field's box chrome (background fill plus a
      --  one-pixel border) into the base rectangle layer. The field text,
      --  caret, focus ring and any adornments stay with the caller.
      procedure Add_Input_Field
        (X            : Natural;
         Y            : Natural;
         Field_W      : Natural;
         Field_H      : Natural;
         Fill_Color   : Render_Color;
         Border_Color : Render_Color) is
      begin
         Guikit.Widgets.Draw_Input_Field
           (Rectangles   => Result.Rectangles,
            Clip_Width   => Layout.Width,
            Clip_Height  => Layout.Height,
            X            => X,
            Y            => Y,
            Width        => Field_W,
            Height       => Field_H,
            Fill_Color   => Fill_Color,
            Border_Color => Border_Color);
      end Add_Input_Field;

      --  A drop shadow in the overlay layer, so an overlay panel's shadow
      --  composites on top of the main grid content like the panel itself.
      procedure Add_Overlay_Drop_Shadow
        (X        : Natural;
         Y        : Natural;
         Shadow_W : Natural;
         Shadow_H : Natural) is
      begin
         Guikit.Widgets.Draw_Drop_Shadow
           (Rectangles  => Result.Overlay_Rectangles,
            Clip_Width  => Layout.Width,
            Clip_Height => Layout.Height,
            X           => X,
            Y           => Y,
            Width       => Shadow_W,
            Height      => Shadow_H,
            Color       => Shadow_Color,
            Line_Height => Line_Height);
      end Add_Overlay_Drop_Shadow;

      procedure Add_Scrollbar
        (Track_X  : Natural;
         Track_Y  : Natural;
         Track_W  : Natural;
         Track_H  : Natural;
         Thumb_Y  : Natural;
         Thumb_H  : Natural) is separate;

      --  Draw a panel's top-right close (X) button plus its Role_Button
      --  accessibility node. A panel drawn over the view (Overlay: the root
      --  selector, Quick Look, the label picker, the paste dialogs, the tree
      --  as a folder pick) draws it in the overlay layer, above its body; a
      --  docked panel in the base layer. Btn is the panel layout's own
      --  Close_Button, which the click hit-test reads too.
      procedure Draw_Close_Button
        (Btn     : Close_Button_Layout;
         Overlay : Boolean)
 is separate;

      --  The window under a modal panel, which owns input while open: the
      --  inactive view leaves the accessibility frame and the whole window
      --  is dimmed, in the overlay layer.
      procedure Draw_Modal_Backdrop is
      begin
         Result.Accessibility.Clear;
         if Width > 0 and then Height > 0 then
            Result.Overlay_Rectangles.Append (Modal_Backdrop (Width, Height));
         end if;
      end Draw_Modal_Backdrop;

      --  The chrome of a modal overlay panel, which owns input while open: the inactive view leaves the
      --  accessibility frame, a Backdrop dims the window, then its shadow, Fill, border and accessibility node.
      procedure Draw_Modal_Chrome
        (X, Y, Panel_W, Panel_H : Natural;
         Fill                   : Render_Color;
         Role                   : Accessibility_Role;
         Name                   : UString;
         Description            : UString := Null_Unbounded_String;
         Backdrop               : Boolean := False)
 is separate;

      procedure Add_Hover_Tooltip is separate;

      function Icon_Theme_Name return String is (Files.Icon_Themes.Image (Snapshot.Icon_Theme));

      procedure Add_Toolbar_Asset_Icon
        (Id      : Files.Commands.Registered_Command_Id;
         X       : Natural;
         Y       : Natural;
         Size    : Natural;
         Enabled : Boolean)
 is separate;

      procedure Add_Toolbar_Drive_Icon
        (X       : Natural;
         Y       : Natural;
         Size    : Natural;
         Enabled : Boolean)
 is separate;

      procedure Add_Caret
        (Region  : Files.Rendering.Layouts.Field_Text_Region;
         Y       : Natural;
         Field_H : Natural;
         Caret_X : Natural)
 is separate;

      function Icon_Color (Kind : Files.Types.Item_Kind) return Render_Color is separate;

      --  The colour the backend rasterizes an atlas icon's base-role shapes in:
      --  a folder in the theme's folder blue, as Icon_Color draws one without
      --  an asset, every other asset a neutral grey (the backend knows no icon
      --  names, so files says which is which). The tile is keyed by this
      --  colour, so a theme change rasterizes fresh folder tiles.
      function Atlas_Base_Color (Icon_Name : String) return Guikit.Draw.Icon_Rgb is
        (if Icon_Name = "folder" then Guikit.Draw.Icon_Rgb_For (Icon_Folder_Color, Snapshot.Theme_Palette)
         else Guikit.Draw.Default_Icon_Base_Color);

      procedure Add_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural;
         Use_Thumbnail : Boolean := False;
         Overlay       : Boolean := False)
 is separate;

      procedure Add_Button
        (X        : Natural;
         Button_W : Natural;
         Selected : Boolean;
         Hovered  : Boolean := False;
         Pressed  : Boolean := False;
         Enabled  : Boolean := True)
 is separate;

      function Sort_Field_Command
        (Field : Files.Types.Sort_Field)
         return Files.Commands.Registered_Command_Id is (Files.Commands.Sort_Command (Field));

      function Command_Color (Id : Files.Commands.Registered_Command_Id) return Render_Color is
      begin
         return (if Snapshot.Command_Enabled (Id) then Text_Color else Disabled_Text_Color);
      end Command_Color;

      --  The root selector, context menu and paste dialogs.
      procedure Draw_Overlay_Commands is separate;

      --  The folder tree beside the view; over everything while it picks a
      --  destination, which blocks the rest of the window.
      procedure Draw_Tree_Panel is separate;

      --  The details column names a row's accessibility description repeats.
      Detail_Column_Labels : constant Detail_Column_Texts := Detail_Names;
      --  The window background, its panes' fills and window-level accessibility nodes.
      procedure Draw_Window_Chrome is separate;
      --  The toolbar.
      procedure Draw_Toolbar is separate;

      --  The bottom bar.
      procedure Draw_Bottom_Bar is separate;

      --  The main view: details header, items, marquee, drag, empty state and scrollbar.
      procedure Draw_Main_View is separate;

      --  The info pane beside the main view.
      procedure Draw_Info_Pane is separate;

      --  The Quick Look panel, the label picker and the sort menu.
      procedure Draw_Popups is separate;

      --  Give the pointer's hover and press back to what is drawn next: the
      --  overlays, which own the pointer while they are open.
      procedure Release_Pointer is
      begin
         Has_Hover := Pointer.Has_Hover;
         Has_Press := Pointer.Pressed;
      end Release_Pointer;
   begin
      --  Rows formatted for another build say another minute, locale or
      --  column set.
      if Build = 0 or else Row_Texts.Build /= Build then
         Row_Texts.Rows.Clear;
         Row_Texts.Build := Build;
      end if;
      Draw_Window_Chrome;
      Draw_Toolbar;
      Draw_Bottom_Bar;

      Draw_Main_View;

      Draw_Info_Pane;

      --  Before the transient overlays, which cover it as they own input.
      if Snapshot.Tree_Panel_Open then
         --  Picking a destination, the tree is the overlay itself.
         if Overlay_Open (Snapshot, Files.UI_Types.Tree_Pick_Overlay) then
            Release_Pointer;
         end if;
         Draw_Tree_Panel;
      end if;
      Release_Pointer;

      --  Popups and modal panels own the pointer while they are open.  Drop
      --  tooltip regions registered by the inactive toolbar, grid, and status
      --  bar before drawing the active overlay; otherwise a tooltip from a
      --  covered control can be painted over the popup.  Overlay-specific
      --  tooltips (for example root rows) are registered afterwards by
      --  Draw_Overlay_Commands and remain available.
      if Any_Overlay_Open (Snapshot) then
         Result.Tooltips.Clear;
      end if;

      Draw_Popups;

      Draw_Overlay_Commands;

      Add_Hover_Tooltip;

      return Result;
   end Build_Frame_Commands;
