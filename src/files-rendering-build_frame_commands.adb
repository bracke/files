with Files.Extension_Labels;
with Guikit.List_Panel;

separate (Files.Rendering)
   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20;
      Hover_X     : Natural := 0;
      Hover_Y     : Natural := 0;
      Has_Hover   : Boolean := False;
      Pressed_X   : Natural := 0;
      Pressed_Y   : Natural := 0;
      Has_Press   : Boolean := False;
      Drag_Item_Index : Natural := 0;
      Drag_X      : Natural := 0;
      Drag_Y      : Natural := 0;
      Has_Drag    : Boolean := False;
      Marquee_Active : Boolean := False;
      Marquee_X   : Natural := 0;
      Marquee_Y   : Natural := 0;
      Marquee_W   : Natural := 0;
      Marquee_H   : Natural := 0)
      return Frame_Commands
   is
      Result        : Frame_Commands;
      Layout        : constant Layout_Metrics :=
        Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Items         : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Main_View     : constant Main_View_Layout := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Toolbar       : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Bottom        : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (Width, Snapshot.Sort_Field, Line_Height);
      Palette       : constant Command_Palette_Layout := Calculate_Command_Palette_Layout (Layout, Line_Height);
      Toolbar_Input_Y : constant Natural := Guikit.Layout.Toolbar_Input_Y (Line_Height);
      Toolbar_Input_H : constant Natural := Guikit.Layout.Toolbar_Input_Height (Line_Height);
      --  Visible glyph content sits low in the Line_Height cell, so the text
      --  origin is pulled up two pixels above the geometric centre. This matches
      --  the bottom bar's optical text centring (Bottom_Content_Y) exactly -- the
      --  fields share the same height -- so the toolbar text reads centred in its
      --  field, aligning with the geometric-centred toolbar icons and favourite
      --  star rather than sitting a pixel low.
      Toolbar_Glyph_Bias : constant Natural := 2;
      Toolbar_Input_Text_Y : constant Natural :=
        (if Toolbar_Input_H > Line_Height
         then
            (declare
                Centered : constant Natural :=
                  Saturating_Add
                    (Toolbar_Input_Y, (Toolbar_Input_H - Line_Height) / 2);
             begin
                (if Centered > Toolbar_Glyph_Bias
                 then Centered - Toolbar_Glyph_Bias
                 else 0))
         else Toolbar_Input_Y);
      Toolbar_Input_Text_H : constant Natural :=
        Natural'Min (Line_Height, Toolbar_Input_H);
      Root_Selector : constant Root_Selector_Layout :=
        Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Rows     : constant Root_Path_Layout_Vectors.Vector :=
        Calculate_Root_Path_Layout (Snapshot, Root_Selector);
      Breadcrumb_Rows : constant Breadcrumb_Segment_Layout_Vectors.Vector :=
        Calculate_Breadcrumb_Layout (Snapshot, Width, Line_Height);
      Tree_Panel    : constant Tree_Panel_Layout :=
        Calculate_Tree_Panel_Layout (Snapshot, Layout, Line_Height);
      Tree_Rows_Layout : constant Tree_Row_Layout_Vectors.Vector :=
        Calculate_Tree_Row_Layout (Snapshot, Tree_Panel, Line_Height);
      Info_Pane     : constant Info_Pane_Layout := Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Settings_Pane : constant Guikit.Layout.Settings_Pane_Layout :=
        Guikit.Layout.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, Line_Height);
      Bottom_Y      : constant Natural :=
        (if Height > Layout.Bottom_Bar_Height then Height - Layout.Bottom_Bar_Height else 0);
      Bottom_Content_Y : constant Natural :=
        Saturating_Add
          (Bottom_Y,
           (if Guikit.Layout.Bottom_Bar_Padding >= 2 then Guikit.Layout.Bottom_Bar_Padding - 2 else 0));
      Bottom_Content_H : constant Natural :=
        (if Layout.Bottom_Bar_Height > Saturating_Multiply (Guikit.Layout.Bottom_Bar_Padding, 2)
         then Layout.Bottom_Bar_Height - Saturating_Multiply (Guikit.Layout.Bottom_Bar_Padding, 2)
         else Layout.Bottom_Bar_Height);

      function Intersects
        (Left_X   : Natural;
         Left_Y   : Natural;
         Left_W   : Natural;
         Left_H   : Natural;
         Right_X  : Natural;
         Right_Y  : Natural;
         Right_W  : Natural;
         Right_H  : Natural)
         return Boolean
      is
      begin
         return Left_W > 0
           and then Left_H > 0
           and then Right_W > 0
           and then Right_H > 0
           and then Left_X < Saturating_Add (Right_X, Right_W)
           and then Right_X < Saturating_Add (Left_X, Left_W)
           and then Left_Y < Saturating_Add (Right_Y, Right_H)
           and then Right_Y < Saturating_Add (Left_Y, Left_H);
      end Intersects;

      function Clipped_Size
        (Start : Natural;
         Size  : Natural;
         Limit : Natural)
         return Natural
      is
      begin
         if Start >= Limit or else Size = 0 then
            return 0;
         else
            return Natural'Min (Size, Limit - Start);
         end if;
      end Clipped_Size;

      function Hidden_By_Settings_Pane
        (X      : Natural;
         Y      : Natural;
         Item_W : Natural;
         Item_H : Natural)
         return Boolean
      is
      begin
         return Snapshot.Settings_Pane_Open
           and then Intersects
             (X,
              Y,
              Item_W,
              Item_H,
              Settings_Pane.X,
              Settings_Pane.Y,
              Settings_Pane.Width,
              Settings_Pane.Height);
      end Hidden_By_Settings_Pane;

      function Hidden_By_Command_Palette
        (X      : Natural;
         Y      : Natural;
         Item_W : Natural;
         Item_H : Natural)
         return Boolean
      is
      begin
         return Snapshot.Command_Palette_Open
           and then Intersects
             (X,
              Y,
              Item_W,
              Item_H,
              Palette.X,
              Palette.Y,
              Palette.Width,
              Palette.Height);
      end Hidden_By_Command_Palette;

      procedure Add_Rect
        (X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Rectangles.Append
              (Rectangle_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Color  => Color));
         end if;
      end Add_Rect;

      procedure Add_Triangle
        (X1    : Float;
         Y1    : Float;
         X2    : Float;
         Y2    : Float;
         X3    : Float;
         Y3    : Float;
         Color : Render_Color)
      is
      begin
         if Layout.Width = 0 or else Layout.Height = 0 then
            return;
         end if;

         --  Triangle commands have no clip rectangle in the draw protocol.
         --  Suppress a partially off-frame primitive instead of handing the
         --  backend coordinates outside its framebuffer; callers scale their
         --  geometry down first when a partial compact rendering is useful.
         if X1 < 0.0 or else X1 > Float (Layout.Width)
           or else X2 < 0.0 or else X2 > Float (Layout.Width)
           or else X3 < 0.0 or else X3 > Float (Layout.Width)
           or else Y1 < 0.0 or else Y1 > Float (Layout.Height)
           or else Y2 < 0.0 or else Y2 > Float (Layout.Height)
           or else Y3 < 0.0 or else Y3 > Float (Layout.Height)
         then
            return;
         end if;

         Result.Triangles.Append
           (Triangle_Command'
              (X1    => X1,
               Y1    => Y1,
               X2    => X2,
               Y2    => Y2,
               X3    => X3,
               Y3    => Y3,
               Color => Color));
      end Add_Triangle;

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

      procedure Add_Overlay_Rect
        (X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Overlay_Rectangles.Append
              (Rectangle_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Color  => Color));
         end if;
      end Add_Overlay_Rect;

      --  The item name as displayed in the grid. With Show_Extensions off, a
      --  file's trailing extension is dropped for display only (rename, search
      --  and accessibility keep the real name). Directories are never changed,
      --  and a name that is only a leading-dot extension -- e.g. ".bashrc" --
      --  keeps its full name, since the dot is not a separator there.
      function Displayed_Name (Item : Item_Snapshot) return UString is separate;

      function Fitted_Text_For
        (Text     : UString;
         Capacity : Natural)
         return UString
 is separate;

      procedure Add_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False;
         Scale_To_Box : Boolean := False;
         Italic : Boolean := False)
 is separate;

      procedure Add_Overlay_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False;
         Italic : Boolean := False)
 is separate;

      procedure Add_Tooltip
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text_Key : String)
      is
         Text : constant String := Files.Localization.Text (Text_Key);
         Draw_W : constant Natural := Clipped_Size (X, Tip_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Tip_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Text'Length > 0 then
            Result.Tooltips.Append
              (Tooltip_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => To_Unbounded_String (Text)));
         end if;
      end Add_Tooltip;

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

      procedure Add_Conflict_Hit
        (Kind   : Conflict_Hit_Kind;
         X      : Natural;
         Y      : Natural;
         Hit_W  : Natural;
         Hit_H  : Natural)
      is
         Draw_W : constant Natural := Clipped_Size (X, Hit_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Hit_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Conflict_Hits.Append
              (Conflict_Hit_Region'
                 (Kind   => Kind,
                  X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H));
         end if;
      end Add_Conflict_Hit;

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
         return Boolean
      is
      begin
         return Contains_Rectangle_Point (X, Y, Box_W, Box_H, Point_X, Point_Y);
      end Contains_Point;

      function Tooltip_At
        (Point_X : Natural;
         Point_Y : Natural)
         return UString
      is
      begin
         for Command of Result.Tooltips loop
            if Contains_Point (Command.X, Command.Y, Command.Width, Command.Height, Point_X, Point_Y) then
               return Command.Text;
            end if;
         end loop;

         return Null_Unbounded_String;
      end Tooltip_At;

      function Is_Pressed
        (X     : Natural;
         Y     : Natural;
         Box_W : Natural;
         Box_H : Natural)
         return Boolean is
      begin
         return Has_Press and then Contains_Point (X, Y, Box_W, Box_H, Pressed_X, Pressed_Y);
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
      --  one-pixel border) into the base rectangle layer, byte-identical to the
      --  former inline Add_Rect + Add_Border pair. The field text, caret, focus
      --  ring and any adornments stay with the caller.
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

      procedure Add_Drop_Shadow
        (X        : Natural;
         Y        : Natural;
         Shadow_W : Natural;
         Shadow_H : Natural) is
      begin
         Guikit.Widgets.Draw_Drop_Shadow
           (Rectangles  => Result.Rectangles,
            Clip_Width  => Layout.Width,
            Clip_Height => Layout.Height,
            X           => X,
            Y           => Y,
            Width       => Shadow_W,
            Height      => Shadow_H,
            Color       => Shadow_Color);
      end Add_Drop_Shadow;

      --  Add_Drop_Shadow into the overlay layer, so an overlay panel's shadow
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
            Color       => Shadow_Color);
      end Add_Overlay_Drop_Shadow;

      procedure Add_Scrollbar
        (Track_X  : Natural;
         Track_Y  : Natural;
         Track_W  : Natural;
         Track_H  : Natural;
         Thumb_Y  : Natural;
         Thumb_H  : Natural) is separate;

      --  Draw a panel's top-right close (X) button plus its Role_Button
      --  accessibility node. Overlay panels (the root selector) render into the
      --  overlay layer so the button sits above the overlay body; the other
      --  panels render into the base layer. The button geometry comes from
      --  Panel_Close_Button so it matches the click hit-test exactly.
      procedure Draw_Close_Button
        (Panel_X : Natural;
         Panel_Y : Natural;
         Panel_W : Natural;
         Panel_H : Natural;
         Overlay : Boolean)
 is separate;

      procedure Add_Hover_Tooltip is separate;

      function Icon_Theme_Name return String is
      begin
         if Length (Snapshot.Settings_Icon_Theme) > 0 then
            return To_String (Snapshot.Settings_Icon_Theme);
         else
            return "files-basic";
         end if;
      end Icon_Theme_Name;

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
        (X       : Natural;
         Y       : Natural;
         Field_W : Natural;
         Field_H : Natural;
         Text    : UString;
         Cursor  : Natural)
 is separate;

      function Icon_Color (Kind : Files.Types.Item_Kind) return Render_Color is
      begin
         case Kind is
            when Files.Types.Directory_Item =>
               return Icon_Directory_Color;
            when Files.Types.Executable_Item =>
               return Icon_Executable_Color;
            when Files.Types.Regular_File_Item | Files.Types.Symlink_Item | Files.Types.Other_Item =>
               return Icon_File_Color;
            when Files.Types.Unknown_Item =>
               return Icon_Unknown_Color;
         end case;
      end Icon_Color;

      function Icon_Asset_Directory return String is
      begin
         if To_String (Snapshot.Settings_Icon_Theme) = "files-high-contrast" then
            return "share/files/icons/high-contrast";
         else
            return "share/files/icons";
         end if;
      end Icon_Asset_Directory;

      function Is_Bundled_Icon (Name : String) return Boolean is
      begin
         return
           Name = "folder"
           or else Name = "text"
           or else Name = "image"
           or else Name = "executable"
           or else Name = "link"
           or else Name = "unknown"
           or else Name = "ada"
           or else Name = "markdown";
      end Is_Bundled_Icon;

      procedure Add_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural;
         Use_Thumbnail : Boolean := False;
         Overlay       : Boolean := False)
 is separate;

      procedure Add_Details_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural)
      is
      begin
         Add_Icon (Item, X, Y, Size);
      end Add_Details_Icon;

      procedure Add_Button
        (X        : Natural;
         Button_W : Natural;
         Selected : Boolean;
         Hovered  : Boolean := False;
         Pressed  : Boolean := False)
 is separate;

      function Command_Label (Id : Files.Commands.Command_Id) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Files.Commands.Name_Key (Id)));
      end Command_Label;

      function Bottom_Command_Label (Id : Files.Commands.Command_Id) return UString is
      begin
         case Id is
            when Files.Commands.Select_Small_Icons_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.small.short"));
            when Files.Commands.Select_Large_Icons_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.large.short"));
            when Files.Commands.Select_Details_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.view.details.short"));
            when Files.Commands.Toggle_Info_Pane_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.info.toggle.short"));
            when Files.Commands.Toggle_Sort_Menu_Command =>
               return To_Unbounded_String (Files.Localization.Text ("command.sort.name"));
            when others =>
               return Command_Label (Id);
         end case;
      end Bottom_Command_Label;

      function Sort_Field_Label
        (Field : Files.Model.Sort_Field)
         return String is
      begin
         case Field is
            when Files.Model.Sort_Name =>
               return Files.Localization.Text ("command.sort.name");
            when Files.Model.Sort_Size =>
               return Files.Localization.Text ("command.sort.size");
            when Files.Model.Sort_Type =>
               return Files.Localization.Text ("command.sort.type");
            when Files.Model.Sort_Created =>
               return Files.Localization.Text ("command.sort.created");
            when Files.Model.Sort_Changed =>
               return Files.Localization.Text ("command.sort.changed");
         end case;
      end Sort_Field_Label;

      function Sort_Field_Command
        (Field : Files.Model.Sort_Field)
         return Files.Commands.Registered_Command_Id is
      begin
         case Field is
            when Files.Model.Sort_Name =>
               return Files.Commands.Sort_By_Name_Command;
            when Files.Model.Sort_Size =>
               return Files.Commands.Sort_By_Size_Command;
            when Files.Model.Sort_Type =>
               return Files.Commands.Sort_By_Type_Command;
            when Files.Model.Sort_Created =>
               return Files.Commands.Sort_By_Created_Command;
            when Files.Model.Sort_Changed =>
               return Files.Commands.Sort_By_Changed_Command;
         end case;
      end Sort_Field_Command;

      function Direction_Text return String is
      begin
         return
           Files.Localization.Text
             ((if Snapshot.Sort_Ascending then "sort.direction.ascending" else "sort.direction.descending"));
      end Direction_Text;

      function Sort_Button_Label return UString is
      begin
         return To_Unbounded_String (Sort_Field_Label (Snapshot.Sort_Field) & " " & Direction_Text);
      end Sort_Button_Label;

      function Command_Color (Id : Files.Commands.Registered_Command_Id) return Render_Color is
      begin
         return (if Snapshot.Command_Enabled (Id) then Text_Color else Disabled_Text_Color);
      end Command_Color;

      --  Group counts with the locale's separator (12.345, not 12345), the same
      --  way sizes and paste-progress counts are shown, so no on-screen number
      --  is formatted inconsistently with the rest.
      function Natural_Text (Value : Natural) return String is
      begin
         return Grouped_Integer_Text (Long_Long_Integer (Value));
      end Natural_Text;

      function View_Mode_Label return String is
      begin
         case Snapshot.View_Mode is
            when Files.Types.Small_Icons =>
               return Files.Localization.Text ("command.view.small");
            when Files.Types.Large_Icons =>
               return Files.Localization.Text ("command.view.large");
            when Files.Types.Details =>
               return Files.Localization.Text ("command.view.details");
         end case;
      end View_Mode_Label;

      function Hidden_Status_Text return String is
      begin
         --  Built from fragments so no letters-plus-space display literal is
         --  hard-coded: "N" + " " + localized "hidden".
         return
           Natural_Text (Snapshot.Hidden_Count)
           & " "
           & Files.Localization.Text ("status.hidden");
      end Hidden_Status_Text;

      function Selected_Status_Text return String is separate;

      function Count_Status_Text return UString is
      begin
         return
           To_Unbounded_String
             (Hidden_Status_Text
              & "  "
              & Natural_Text (Snapshot.Visible_Count)
              & " "
              & Files.Localization.Text ("status.visible")
              & "  "
              & Selected_Status_Text);
      end Count_Status_Text;

      function Bottom_Info_Text return UString is
      begin
         if Length (Snapshot.Last_Error_Key) > 0 then
            return To_Unbounded_String (Files.Localization.Text (To_String (Snapshot.Last_Error_Key)));
         end if;

         return Count_Status_Text;
      end Bottom_Info_Text;

      function Main_View_Accessible_Description return UString is
      begin
         return
           To_Unbounded_String
             (Files.Localization.Text ("settings.default_view")
              & ": "
              & View_Mode_Label
              & "  ")
           & Count_Status_Text;
      end Main_View_Accessible_Description;

      function Empty_State_Key return String is
      begin
         if Snapshot.Item_Count = 0 and then Snapshot.In_Recent_View then
            return "recent.empty";
         elsif Snapshot.Item_Count = 0 then
            return "status.empty_directory";
         elsif Snapshot.Visible_Count = 0 and then Length (Snapshot.Filter_Text) > 0 then
            return "status.empty_filter";
         else
            return "";
         end if;
      end Empty_State_Key;

      function Info_Value
        (Label_Key : String;
         Value     : String)
         return UString
      is
      begin
         return To_Unbounded_String (Files.Localization.Text (Label_Key) & ": " & Value);
      end Info_Value;

      function Missing_Info (Label_Key : String) return UString is
      begin
         return Info_Value (Label_Key, Files.Localization.Text ("status.missing_metadata"));
      end Missing_Info;

      function Integer_Text (Value : Long_Long_Integer) return String is
         Image : constant String := Long_Long_Integer'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Integer_Text;

      function Time_Text
        (Available : Boolean;
         Value     : Ada.Calendar.Time;
         Label_Key : String)
         return UString
 is separate;

      function Detail_Size_Text (Item : Item_Snapshot) return UString is separate;

      function Detail_Time_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Modified_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return
           To_Unbounded_String (Humanized_Time_Text (Item.Modified_Time));
      end Detail_Time_Text;

      function Detail_Created_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Creation_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return
           To_Unbounded_String (Humanized_Time_Text (Item.Creation_Time));
      end Detail_Created_Text;

      type Overlay_Draw_Phase is
        (Persistent_Overlay_Phase, Modal_Overlay_Phase);

      procedure Draw_Overlay_Commands
        (Phase : Overlay_Draw_Phase)
      is separate;

      --  Details-view accessibility row labels are identical for every row;
      --  look them up once here rather than three times per visible row.
      Detail_Modified_Label : constant String := Files.Localization.Text ("details.modified");
      Detail_Size_Label     : constant String := Files.Localization.Text ("details.size");
      Detail_Filetype_Label : constant String := Files.Localization.Text ("details.filetype");
      --  The window background, the toolbar and the bottom bar.
      procedure Draw_Toolbar is separate;

      --  The main view: details header, items, marquee, drag, empty state and scrollbar.
      procedure Draw_Main_View is separate;

      --  The info pane beside the main view.
      procedure Draw_Info_Pane is separate;

      --  The Quick Look panel, the label picker and the sort menu.
      procedure Draw_Popups is separate;
   begin
      Draw_Toolbar;
      if Layout.Bottom_Bar_Height > 0
        and then Bottom.Sort_Button_X > 0
        and then Bottom.Sort_Button_Width > 0
      then
         Add_Rect (Bottom.Sort_Button_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_X > 0 then
         Add_Rect (Bottom.Info_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_Pane_X > 0 then
         Add_Rect (Bottom.Info_Pane_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;

      Draw_Main_View;

      Draw_Info_Pane;

      --  The ordinary folder tree is persistent rather than modal. Draw it
      --  before transient overlays so Quick Look, label/root/sort menus, and
      --  dialogs cover it in the same order in which they own input.
      Draw_Overlay_Commands (Persistent_Overlay_Phase);

      --  Popups and modal panels own the pointer while they are open.  Drop
      --  tooltip regions registered by the inactive toolbar, grid, and status
      --  bar before drawing the active overlay; otherwise a tooltip from a
      --  covered control can be painted over the popup.  Overlay-specific
      --  tooltips (for example root rows) are registered afterwards by
      --  Draw_Overlay_Commands and remain available.
      if Snapshot.Root_Selector_Open
        or else Snapshot.Context_Menu_Open
        or else Snapshot.Paste_Conflict_Open
        or else Snapshot.Paste_Progress_Open
        or else Snapshot.Quick_Look_Open
        or else Snapshot.Label_Picker_Open
        or else Snapshot.Sort_Menu_Open
        or else Snapshot.Tree_Pick_Active
        or else Snapshot.Command_Palette_Open
        or else Snapshot.Settings_Pane_Open
      then
         Result.Tooltips.Clear;
      end if;

      Draw_Popups;

      Draw_Overlay_Commands (Modal_Overlay_Phase);

      Add_Hover_Tooltip;

      return Result;
   end Build_Frame_Commands;
