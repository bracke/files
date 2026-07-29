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
            Color       => Pane_Color);
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
            Color       => Pane_Color);
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
         Use_Thumbnail : Boolean := False)
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

      function Permission_Text (Permissions : String) return String is separate;

      procedure Draw_Overlay_Commands is separate;

      --  Details-view accessibility row labels are identical for every row;
      --  look them up once here rather than three times per visible row.
      Detail_Modified_Label : constant String := Files.Localization.Text ("details.modified");
      Detail_Size_Label     : constant String := Files.Localization.Text ("details.size");
      Detail_Filetype_Label : constant String := Files.Localization.Text ("details.filetype");
   begin
      Result.Layout := Layout;
      Result.Theme_Palette := Snapshot.Theme_Palette;

      Add_Rect (0, 0, Width, Height, Canvas_Color);
      Add_Rect (0, 0, Width, Layout.Toolbar_Height, Toolbar_Color);
      Add_Rect (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, Main_Color);
      Add_Rect (0, Bottom_Y, Width, Layout.Bottom_Bar_Height, Bottom_Bar_Color);
      if Layout.Toolbar_Height > 0 then
         Add_Rect (0, Layout.Toolbar_Height - 1, Width, 1, Border_Color);
      end if;
      Add_Rect (0, Bottom_Y, Width, 1, Border_Color);
      Add_Accessibility_Node
        (Role_Window,
         0,
         0,
         Width,
         Height,
         Snapshot.Current_Path);
      Add_Accessibility_Node
        (Role_Toolbar,
         0,
         0,
         Width,
         Layout.Toolbar_Height,
         Localized ("accessibility.toolbar"));
      Add_Accessibility_Node
        ((if Snapshot.View_Mode = Files.Types.Details then Role_Table else Role_List),
         Layout.Main_X,
         Layout.Main_Y,
         Layout.Main_Width,
         Layout.Main_Height,
         Localized ("accessibility.main_view"),
         Main_View_Accessible_Description);

      if Layout.Info_Pane_Width > 0 then
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            1,
            Layout.Main_Height,
            Border_Color);
      end if;

      for Button_Index in 0 .. 6 loop
         declare
            Button_X : constant Natural := Guikit.Layout.Toolbar_Left_Button_X (Toolbar, Button_Index);
            Button_W : constant Natural := Guikit.Layout.Toolbar_Left_Button_Width (Toolbar, Button_Index);
            Command  : constant Files.Commands.Registered_Command_Id :=
              (case Button_Index is
                  when 0 => Files.Commands.Select_Drive_Command,
                  when 1 => Files.Commands.Navigate_Home_Command,
                  when 2 => Files.Commands.Navigate_Back_Command,
                  when 3 => Files.Commands.Navigate_Forward_Command,
                  when 4 => Files.Commands.Navigate_Parent_Command,
                  when 5 => Files.Commands.Create_File_Command,
                  when others => Files.Commands.Delete_Selected_Items_Command);
            Button_Y : constant Natural := Toolbar_Input_Y;
            Button_H : constant Natural :=
              (if Button_Y >= Layout.Toolbar_Height
               then 0
               else Natural'Min (Toolbar_Input_H, Layout.Toolbar_Height - Button_Y));
            --  Per-button visual padding so the icons get breathing room and
            --  groups read separately. Inner padding for normal spacing; the
            --  end-of-group cell on either side of the navigation/file-action
            --  boundary gets a wider pad so the gap is visible.
            --  Slim vertical inset so the icon can occupy more of the button
            --  height (a modestly larger glyph) while staying inside the rect.
            Pad_V        : constant Natural :=
              Natural'Min (2, Button_H / 8);
            Inner_Pad    : constant Natural := Natural'Min (3, Button_W / 6);
            Group_Pad    : constant Natural := Natural'Min (8, Button_W / 4);
            Button_Pad_L : constant Natural :=
              (if Button_Index = 5 then Group_Pad else Inner_Pad);
            Button_Pad_R : constant Natural :=
              (if Button_Index = 4 then Group_Pad else Inner_Pad);
            Visible_X : constant Natural := Saturating_Add (Button_X, Button_Pad_L);
            Visible_W : constant Natural :=
              (if Button_W > Saturating_Add (Button_Pad_L, Button_Pad_R)
               then Button_W - Button_Pad_L - Button_Pad_R
               else 0);
            Visible_Y : constant Natural := Saturating_Add (Button_Y, Pad_V);
            Visible_H : constant Natural :=
              (if Button_H > Saturating_Multiply (Pad_V, 2)
               then Button_H - Saturating_Multiply (Pad_V, 2)
               else 0);
            Icon_Size : constant Natural :=
              (if Visible_W >= Guikit.Layout.Toolbar_Button_Width - 4
               then Natural'Min (Visible_H, Guikit.Layout.Toolbar_Button_Width - 8)
               else Natural'Min (Visible_W, Visible_H));
            Icon_X   : constant Natural :=
              (if Visible_W > Icon_Size then Visible_X + (Visible_W - Icon_Size) / 2 else Visible_X);
            Icon_Y   : constant Natural :=
              (if Visible_H > Icon_Size then Visible_Y + (Visible_H - Icon_Size) / 2 else Visible_Y);
            Enabled  : constant Boolean := Snapshot.Command_Enabled (Command);
            Hovered  : constant Boolean :=
              Has_Hover and then Contains_Point (Button_X, Button_Y, Button_W, Button_H, Hover_X, Hover_Y);
            Pressed  : constant Boolean := Is_Pressed (Button_X, Button_Y, Button_W, Button_H);
         begin
            if Visible_W > 0 and then Visible_H > 0 then
               --  Disabled buttons render with no fill and no border, exactly
               --  like an enabled idle button; only the icon dimming differs.
               if Pressed then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Pressed_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               elsif Hovered then
                  Add_Rect (Visible_X, Visible_Y, Visible_W, Visible_H, Hover_Color);
                  Add_Border (Visible_X, Visible_Y, Visible_W, Visible_H, Border_Color);
               end if;
            end if;
            if Command = Files.Commands.Select_Drive_Command then
               Add_Toolbar_Drive_Icon (Icon_X, Icon_Y, Icon_Size, Enabled);
            else
               Add_Toolbar_Asset_Icon (Command, Icon_X, Icon_Y, Icon_Size, Enabled);
            end if;
            Add_Command_Tooltip
              (Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command);
            Add_Accessibility_Node
              (Role_Button,
               Button_X,
               Button_Y,
               Button_W,
               Button_H,
               Command_Label (Command),
               Localized (Files.Commands.Description_Key (Command)),
               Enabled => Enabled);
         end;
      end loop;

      --  Vertical divider between navigation group (drives/home/back/forward)
      --  and file-action group (create/delete) so the two groups read as
      --  distinct sets of controls.
      if Layout.Toolbar_Height > 0 then
         declare
            Group_Boundary_X : constant Natural :=
              Guikit.Layout.Toolbar_Left_Button_X (Toolbar, 5);
            Divider_H : constant Natural :=
              Natural'Max (1, Layout.Toolbar_Height / 3);
            Divider_Y : constant Natural :=
              (if Layout.Toolbar_Height > Divider_H
               then (Layout.Toolbar_Height - Divider_H) / 2
               else 0);
         begin
            if Group_Boundary_X > 0
              and then Group_Boundary_X < Toolbar.Middle_X
            then
               Add_Rect (Group_Boundary_X, Divider_Y, 1, Divider_H, Border_Color);
            end if;
         end;
      end if;

      declare
         Field_Margin : constant Natural := 6;
         Path_X : constant Natural :=
           Saturating_Add (Toolbar.Middle_X, Field_Margin);
         Path_W : constant Natural :=
           (if Toolbar.Middle_Width > Saturating_Multiply (Field_Margin, 2)
            then Toolbar.Middle_Width - Saturating_Multiply (Field_Margin, 2)
            else 0);
         Star         : constant Path_Favorite_Star_Bounds :=
           Path_Favorite_Star_Region (Width, Line_Height);
         Star_Reserve : constant Natural := Path_Bar_Content_Offset (Width, Line_Height);
         Text_Start   : constant Natural :=
           Saturating_Add (Saturating_Add (Path_X, Guikit.Layout.Input_Field_Padding), Star_Reserve);
      begin
         Add_Input_Field
           (Path_X,
            Toolbar_Input_Y,
            Path_W,
            Toolbar_Input_H,
            (if Snapshot.Path_Input_Valid then Input_Color else Input_Error_Color),
            Border_Color);
         --  Favorite toggle: a filled star when the current directory is a
         --  favorite, an empty star when not, drawn at the left of the path bar
         --  ahead of the breadcrumbs/edit field in both modes.
         if Star.Visible then
            declare
               Star_Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point (Star.X, Star.Y, Star.Width, Star.Height, Hover_X, Hover_Y);
            begin
               declare
                  Center_X : constant Float := Float (Star.X) + Float (Star.Width) / 2.0;
                  Center_Y : constant Float := Float (Star.Y) + Float (Star.Height) / 2.0;
                  --  A five-pointed star spans ~1.9 * Radius across and ~1.81 *
                  --  Radius tall; size the radius to fill the box with a margin.
                  Radius   : constant Float :=
                    0.82 * Float'Min (Float (Star.Width) / 1.9, Float (Star.Height) / 1.81);
                  Stroke   : constant Float := Float'Max (1.5, Float (Line_Height) / 10.0);
               begin
                  --  Draw the favourite indicator as a vector shape (a filled
                  --  star when favourited, an outline star when not) so it fills
                  --  its box crisply at any size, unlike the small font glyph.
                  if Snapshot.Current_Path_Is_Favorite then
                     Add_Star_Fill (Center_X, Center_Y, Radius, Favorite_Star_Color);
                  else
                     Add_Star_Outline (Center_X, Center_Y, Radius, Stroke, Muted_Text_Color);
                  end if;
               end;
               if Star_Hovered then
                  Add_Border (Star.X, Star.Y, Star.Width, Star.Height, Hover_Color);
               end if;
               Add_Accessibility_Node
                 (Role_Button,
                  Star.X,
                  Star.Y,
                  Star.Width,
                  Star.Height,
                  Localized
                    (if Snapshot.Current_Path_Is_Favorite
                     then "accessibility.favorite_toggle.on"
                     else "accessibility.favorite_toggle.off"),
                  Snapshot.Current_Path,
                  Enabled  => True,
                  Selected => Snapshot.Current_Path_Is_Favorite);
            end;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input
           or else Breadcrumb_Rows.Is_Empty
         then
            Add_Text
              (Text_Start,
               Toolbar_Input_Text_Y,
               (if Path_W > 2 * Guikit.Layout.Input_Field_Padding + Star_Reserve
                then Path_W - 2 * Guikit.Layout.Input_Field_Padding - Star_Reserve
                else 0),
               Toolbar_Input_Text_H,
               Snapshot.Path_Input_Text,
               Fit => True);
         else
            for I in 1 .. Natural (Breadcrumb_Rows.Length) loop
               declare
                  Seg     : constant Breadcrumb_Segment_Layout :=
                    Breadcrumb_Rows.Element (Positive (I));
                  Is_Last : constant Boolean := I = Natural (Breadcrumb_Rows.Length);
                  Advance : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                  Label   : constant UString :=
                    (if Seg.Clickable and then Seg.Segment_Index /= 0
                     then Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Label
                     else To_Unbounded_String (Files.Breadcrumbs.Ellipsis_Label));
                  Hovered : constant Boolean :=
                    Seg.Clickable
                    and then Has_Hover
                    and then Contains_Point (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_X, Hover_Y);
               begin
                  Add_Text
                    (Seg.X,
                     Toolbar_Input_Text_Y,
                     Seg.Width,
                     Toolbar_Input_Text_H,
                     Label,
                     Color => (if Seg.Clickable then Text_Color else Muted_Text_Color));
                  if Hovered then
                     Add_Border (Seg.X, Seg.Y, Seg.Width, Seg.Height, Hover_Color);
                  end if;
                  if Seg.Clickable and then Seg.Segment_Index /= 0 then
                     Add_Accessibility_Node
                       (Role_Button,
                        Seg.X,
                        Seg.Y,
                        Seg.Width,
                        Seg.Height,
                        Label,
                        Snapshot.Breadcrumb_Segments.Element (Positive (Seg.Segment_Index)).Ancestor_Path);
                  end if;
                  if not Is_Last then
                     --  Draw '>' in the middle of the three separator cells so
                     --  it has a full character width of space on each side.
                     Add_Text
                       (Saturating_Add (Saturating_Add (Seg.X, Seg.Width), Advance),
                        Toolbar_Input_Text_Y,
                        Advance,
                        Toolbar_Input_Text_H,
                        To_Unbounded_String (Breadcrumb_Separator_Text),
                        Color => Muted_Text_Color);
                  end if;
               end;
            end loop;
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input or else not Snapshot.Path_Input_Valid then
            Add_Border
              (Path_X,
               Toolbar_Input_Y,
               Path_W,
               Toolbar_Input_H,
               (if Snapshot.Path_Input_Valid then Border_Color else Input_Error_Color));
         elsif Has_Hover
           and then Contains_Point
             (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H) then
            Add_Border (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H, Pressed_Color);
         end if;
         if Snapshot.Focus = Files.Types.Focus_Path_Input then
            Add_Focus_Ring (Path_X, Toolbar_Input_Y, Path_W, Toolbar_Input_H);
            Add_Caret
              (Saturating_Add (Path_X, Star_Reserve),
               Toolbar_Input_Y,
               (if Path_W > Star_Reserve then Path_W - Star_Reserve else 0),
               Toolbar_Input_H,
               Snapshot.Path_Input_Text,
               Snapshot.Text_Cursor_Position);
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Path_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Middle_X,
         Toolbar_Input_Y,
         Toolbar.Middle_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Path_Input_Command)),
         Path_Input_Accessible_Description,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Path_Input);
      declare
         Field_Margin : constant Natural := 6;
         Filter_X : constant Natural :=
           Saturating_Add (Toolbar.Right_X, Field_Margin);
         --  The chip is sized to its localized label so it never abbreviates;
         --  the filter field is narrowed to end before it (when it fits).
         Scope_Chip_W : constant Natural := Files.UI.Filter_Scope_Chip_Width (Line_Height);
         Filter_W : constant Natural :=
           Guikit.Layout.Filter_Input_Field_Width (Toolbar, Scope_Chip_W, Line_Height);
         Scope_Chip : constant Guikit.Layout.Scope_Chip_Region :=
           Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Scope_Chip_W, Line_Height);
         Scope_Key : constant String :=
           (case Snapshot.Search_Scope is
              when Files.Types.Filter_Here => "search.scope.here",
              when Files.Types.Search_Names => "search.scope.names",
              when Files.Types.Search_Contents => "search.scope.contents");
      begin
         Add_Input_Field
           (Filter_X,
            Toolbar_Input_Y,
            Filter_W,
            Toolbar_Input_H,
            Input_Color,
            Border_Color);
         Add_Text
           (Saturating_Add (Filter_X, Guikit.Layout.Input_Field_Padding),
            Toolbar_Input_Text_Y,
            (if Filter_W > 2 * Guikit.Layout.Input_Field_Padding
             then Filter_W - 2 * Guikit.Layout.Input_Field_Padding
             else 0),
            Toolbar_Input_Text_H,
            (if Length (Snapshot.Filter_Text) = 0
             then To_Unbounded_String (Files.Localization.Text ("filter.placeholder"))
             else Snapshot.Filter_Text),
            (if Length (Snapshot.Filter_Text) = 0 then Muted_Text_Color else Text_Color),
            Fit => True);
         if Snapshot.Focus = Files.Types.Focus_Filter_Input then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Border_Color);
            Add_Focus_Ring (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H);
            Add_Caret
              (Filter_X,
               Toolbar_Input_Y,
               Filter_W,
               Toolbar_Input_H,
               Snapshot.Filter_Text,
               Snapshot.Text_Cursor_Position);
         elsif Has_Hover
           and then Contains_Point
             (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_X, Hover_Y)
         then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Hover_Color);
         end if;
         if Is_Pressed (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H) then
            Add_Border (Filter_X, Toolbar_Input_Y, Filter_W, Toolbar_Input_H, Pressed_Color);
         end if;

         if Scope_Chip.Visible then
            declare
               --  The scope chip is a button: clicking it cycles the search
               --  scope. Give it the raised button look used by the overlay/
               --  close buttons -- a persistent Pane_Color fill and border that
               --  lifts to Hover_Color/Pressed_Color on interaction and to
               --  Selection_Color while recursive search results are on screen --
               --  rather than the recessed Input_Color look of a text field.
               Chip_Hovered : constant Boolean :=
                 Has_Hover
                 and then Contains_Point
                   (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Hover_X, Hover_Y);
               Chip_Pressed : constant Boolean :=
                 Is_Pressed (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height);
               Chip_Active  : constant Boolean := Snapshot.Search_Results_Active;
            begin
               Add_Rect
                 (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height,
                  (if Chip_Active then Selection_Color
                   elsif Chip_Pressed then Pressed_Color
                   elsif Chip_Hovered then Hover_Color
                   else Pane_Color));
               Add_Border
                 (Scope_Chip.X, Scope_Chip.Y, Scope_Chip.Width, Scope_Chip.Height, Border_Color);
               Add_Text
                 (Saturating_Add (Scope_Chip.X, Guikit.Layout.Input_Field_Padding),
                  Toolbar_Input_Text_Y,
                  (if Scope_Chip.Width > 2 * Guikit.Layout.Input_Field_Padding
                   then Scope_Chip.Width - 2 * Guikit.Layout.Input_Field_Padding
                   else 0),
                  Toolbar_Input_Text_H,
                  Localized (Scope_Key),
                  (if Chip_Active then Text_Color else Muted_Text_Color),
                  Fit => True);
               --  The chip's own tooltip, added before the filter field's, so it
               --  wins the first-match hit-test for points over the chip and
               --  explains the scope control rather than the filter input.
               Add_Tooltip
                 (Scope_Chip.X,
                  Scope_Chip.Y,
                  Scope_Chip.Width,
                  Scope_Chip.Height,
                  "search.scope.tooltip");
               Add_Accessibility_Node
                 (Role_Button,
                  Scope_Chip.X,
                  Scope_Chip.Y,
                  Scope_Chip.Width,
                  Scope_Chip.Height,
                  Localized ("accessibility.search_scope"),
                  Localized (Scope_Key),
                  Enabled => True,
                  Focused => False);
            end;
         end if;
      end;
      Add_Command_Tooltip
        (Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Files.Commands.Focus_Filter_Input_Command);
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Right_X,
         Toolbar_Input_Y,
         Toolbar.Right_Width,
         Toolbar_Input_H,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Filter_Input_Command)),
         Snapshot.Filter_Text,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Filter_Input);

      --  The view-mode switcher is a segmented control over the view-mode region.
      declare
         --  Labels come from Files.UI.View_Mode_Segments so the widths drawn
         --  here match the widths the click hit-test measures; the renderer only
         --  adds the per-cell tooltip and enabled state.
         View_Segments : Guikit.Segmented.Segment_Vectors.Vector := Files.UI.View_Mode_Segments;
         Seg_Rects     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Seg_Text      : Guikit.Draw.Text_Command_Vectors.Vector;
         Seg_Tips      : Guikit.Draw.Tooltip_Command_Vectors.Vector;
         Seg_Nodes     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Active        : constant Natural :=
           (case Snapshot.View_Mode is
               when Files.Types.Small_Icons => 1,
               when Files.Types.Large_Icons => 2,
               when Files.Types.Details     => 3);

         procedure Enrich (Cell : Positive; Command : Files.Commands.Registered_Command_Id) is
            S : Guikit.Segmented.Segment := View_Segments.Element (Cell);
         begin
            S.Tooltip := Command_Label (Command);
            S.Enabled := Snapshot.Command_Enabled (Command);
            View_Segments.Replace_Element (Cell, S);
         end Enrich;
      begin
         Enrich (1, Files.Commands.Select_Small_Icons_Command);
         Enrich (2, Files.Commands.Select_Large_Icons_Command);
         Enrich (3, Files.Commands.Select_Details_Command);
         Guikit.Segmented.Build_Frame
           (Segments      => View_Segments,
            Active        => Active,
            Region_X      => Bottom.View_Mode_X,
            Region_Y      => Bottom_Y,
            Region_Width  => Bottom.View_Mode_Width,
            Region_Height => Layout.Bottom_Bar_Height,
            Clip_Width    => Width,
            Clip_Height   => Height,
            Line_Height   => Line_Height,
            Hover_X       => (if Has_Hover then Hover_X else -1),
            Hover_Y       => (if Has_Hover then Hover_Y else -1),
            --  Cells fill the full bar, but sit the labels on the shared bottom-bar
            --  text baseline instead of centring them in the taller cell.
            Label_Inset   => Bottom_Content_Y - Bottom_Y,
            Rectangles    => Seg_Rects,
            Text          => Seg_Text,
            Tooltips      => Seg_Tips,
            Accessibility => Seg_Nodes);
         for C of Seg_Rects loop
            Result.Rectangles.Append (C);
         end loop;
         for C of Seg_Text loop
            Result.Text.Append (C);
         end loop;
         for C of Seg_Tips loop
            Result.Tooltips.Append (C);
         end loop;
         for N of Seg_Nodes loop
            Result.Accessibility.Append (N);
         end loop;
      end;
      declare
         Hovered : constant Boolean :=
           Has_Hover
           and then Contains_Point
             (Bottom.Sort_Button_X,
              Bottom_Y,
              Bottom.Sort_Button_Width,
              Layout.Bottom_Bar_Height,
              Hover_X,
              Hover_Y);
         Pressed : constant Boolean :=
           Is_Pressed (Bottom.Sort_Button_X, Bottom_Y, Bottom.Sort_Button_Width, Layout.Bottom_Bar_Height);
      begin
         Add_Button (Bottom.Sort_Button_X, Bottom.Sort_Button_Width, Snapshot.Sort_Menu_Open, Hovered, Pressed);
         declare
            Field_Label : constant String := Sort_Field_Label (Snapshot.Sort_Field);
            Arrow_Text  : constant String := Direction_Text;
            Cell_W      : constant Positive :=
              Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
            Label_W     : constant Natural :=
              Saturating_Multiply (Files.UTF8.Display_Units (Field_Label), Cell_W);
            --  Tighter than a full monospace space so the direction arrow sits
            --  close to the sort field it belongs to.
            Arrow_Gap   : constant Natural := Cell_W / 2;
            Arrow_W     : constant Natural :=
              Saturating_Multiply (Files.UTF8.Display_Units (Arrow_Text), Cell_W);
            --  Actual field + gap + arrow width drawn. The button is sized assuming
            --  a full space before the arrow, so it is a touch wider; centre the
            --  drawn content within the button rather than left-aligning it.
            Rendered_W  : constant Natural :=
              Saturating_Add (Label_W, Saturating_Add (Arrow_Gap, Arrow_W));
            Text_X0     : constant Natural :=
              Saturating_Add
                (Bottom.Sort_Button_X,
                 (if Bottom.Sort_Button_Width > Rendered_W
                  then (Bottom.Sort_Button_Width - Rendered_W) / 2
                  else Guikit.Layout.Input_Field_Padding));
            Content_W   : constant Natural :=
              (if Bottom.Sort_Button_Width > Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)
               then Bottom.Sort_Button_Width - Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2)
               else 0);
            Arrow_X     : constant Natural :=
              Saturating_Add (Text_X0, Saturating_Add (Label_W, Arrow_Gap));
            Sort_Color  : constant Render_Color :=
              Command_Color (Files.Commands.Toggle_Sort_Menu_Command);
         begin
            Add_Text
              (Text_X0,
               Bottom_Content_Y,
               Content_W,
               Bottom_Content_H,
               To_Unbounded_String (Field_Label),
               Sort_Color,
               Fit => False);
            if Content_W > Saturating_Add (Label_W, Arrow_Gap) then
               Add_Text
                 (Arrow_X,
                  Bottom_Content_Y,
                  Content_W - Label_W - Arrow_Gap,
                  Bottom_Content_H,
                  To_Unbounded_String (Arrow_Text),
                  Sort_Color,
                  Fit => False);
            end if;
         end;
         Add_Command_Tooltip
           (Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Files.Commands.Toggle_Sort_Menu_Command);
         Add_Accessibility_Node
           (Role_Button,
            Bottom.Sort_Button_X,
            Bottom_Content_Y,
            Bottom.Sort_Button_Width,
            Bottom_Content_H,
            Sort_Button_Label,
            Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Sort_Menu_Command)),
            Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Sort_Menu_Command),
            Selected => Snapshot.Sort_Menu_Open);
      end;
      --  The counts area doubles as the hidden-count control: clicking it
      --  toggles Show_Hidden_Files. The free-space field to its right is a
      --  separate, non-interactive field, so the toggle's hover/press/tooltip
      --  affordances stop at the divider rather than spanning the whole region.
      declare
         Pad       : constant Natural := 4;
         Cell_W    : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Free_Text : constant String := Free_Space_Label (Snapshot);
         Free_W    : constant Natural := Free_Space_Label_Width (Snapshot, Line_Height);
         --  The counts/free split, shared with the click hit-test so the toggle's
         --  hover/press/tooltip area and the separate free-space field agree.
         Toggle_W, Divider_X, Free_X, Free_Field_W : Natural;
         --  Fill the whole button height (matching the neighbouring bottom-bar
         --  controls and this control's own full-height hit region), not just
         --  the padding-inset content box, so hover/press has no uncovered
         --  stripe at the bottom.
         Info_Btn_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Info_Btn_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Files.UI.Split_Status_Region
           (Bottom.Info_X, Bottom.Info_Width, Free_W, Toggle_W, Divider_X, Free_X, Free_Field_W);
         declare
            Show_Free : constant Boolean := Free_Field_W > 0;
            Counts_W  : constant Natural := (if Toggle_W > 2 * Pad then Toggle_W - 2 * Pad else 0);
            Info_Text : constant UString := Bottom_Info_Text;
            --  When the labelled counts do not fit the available width, collapse
            --  to just the three numbers (hidden / visible / selected),
            --  slash-separated and label-less. The error line is never collapsed.
            Compact   : constant String :=
              Natural_Text (Snapshot.Hidden_Count) & "/"
              & Natural_Text (Snapshot.Visible_Count) & "/"
              & Natural_Text (Snapshot.Selected_Count);
            Use_Compact : constant Boolean :=
              Length (Snapshot.Last_Error_Key) = 0
              and then Saturating_Multiply (Files.UTF8.Display_Units (To_String (Info_Text)), Cell_W) > Counts_W;
            Status_Text : constant UString :=
              (if Use_Compact then To_Unbounded_String (Compact) else Info_Text);
            --  The counts area is the clickable hidden-files toggle, so its text
            --  is drawn in the active control colour (white when enabled), like
            --  the neighbouring toggle buttons, rather than the muted info colour
            --  used for the non-clickable free-space field. The error line keeps
            --  the error colour.
            Counts_Color : constant Render_Color :=
              (if Length (Snapshot.Last_Error_Key) > 0 then Error_Text_Color
               else Command_Color (Files.Commands.Toggle_Hidden_Files_Command));
            --  The counts tooltip carries the toggle action plus a legend of the
            --  three numbers (hidden / visible / selected, in display order), so
            --  their meaning is clear even when the small-window form drops the
            --  labels down to "N/N/N". The legend reuses the status labels, so it
            --  is localized and matches the compact separator.
            Counts_Tip : constant UString :=
              Command_Tooltip_Text (Files.Commands.Toggle_Hidden_Files_Command)
              & To_Unbounded_String
                  (" ("
                   & Files.Localization.Text ("status.hidden") & " / "
                   & Files.Localization.Text ("status.visible") & " / "
                   & Files.Localization.Text ("status.selected")
                   & ")");
         begin
            Add_Rect
              (Bottom.Info_X,
               Info_Btn_Y,
               Toggle_W,
               Info_Btn_H,
               (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command)
                then Bottom_Bar_Color
                elsif Is_Pressed (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height)
                then Pressed_Color
                elsif Has_Hover
                  and then Contains_Point
                    (Bottom.Info_X, Bottom_Y, Toggle_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y)
                then Hover_Color
                else Bottom_Bar_Color));
            Add_Text
              (Saturating_Add (Bottom.Info_X, Pad),
               Bottom_Content_Y,
               Counts_W,
               Bottom_Content_H,
               Status_Text,
               Counts_Color,
               Fit => True);
            if Show_Free then
               declare
                  --  The free field's interactive region: from the divider to the
                  --  right edge of the info area, mirroring the click hit-test.
                  Free_Region_X : constant Natural := Divider_X;
                  Free_Region_W : constant Natural :=
                    (if Saturating_Add (Bottom.Info_X, Bottom.Info_Width) > Divider_X
                     then Saturating_Add (Bottom.Info_X, Bottom.Info_Width) - Divider_X
                     else Free_Field_W);
               begin
                  --  Clicking the field toggles free/used space, so it gets the
                  --  same hover/press affordance as the neighbouring toggles.
                  Add_Rect
                    (Free_Region_X,
                     Info_Btn_Y,
                     Free_Region_W,
                     Info_Btn_H,
                     (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command)
                      then Bottom_Bar_Color
                      elsif Is_Pressed (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height)
                      then Pressed_Color
                      elsif Has_Hover
                        and then Contains_Point
                          (Free_Region_X, Bottom_Y, Free_Region_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y)
                      then Hover_Color
                      else Bottom_Bar_Color));
                  --  Span the full bar height (matching the button fills), not
                  --  just the inset content band, so the divider reaches top to
                  --  bottom.
                  Add_Rect
                    (Divider_X,
                     Saturating_Add (Bottom_Y, 1),
                     1,
                     (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
                      else Layout.Bottom_Bar_Height),
                     Border_Color);
                  if Free_Space_Bar_Active (Snapshot) then
                     --  Bar mode: a scrollbar-like track whose blue core width is
                     --  the fraction of disk space used.
                     declare
                        Bar_H  : constant Natural := Natural'Max (8, Saturating_Multiply (Line_Height, 2) / 3);
                        --  Centre the bar in the field's full height (the hover
                        --  rect band), not the smaller inset content band.
                        Bar_Y  : constant Natural :=
                          (if Info_Btn_H > Bar_H
                           then Saturating_Add (Info_Btn_Y, (Info_Btn_H - Bar_H) / 2)
                           else Info_Btn_Y);
                        Bar_W  : constant Natural :=
                          (if Free_Field_W > Pad then Free_Field_W - Pad else 0);
                        --  Centre the bar in the field's interactive region so the
                        --  margins before and after it are equal.
                        Bar_X  : constant Natural :=
                          (if Free_Region_W > Bar_W
                           then Saturating_Add (Free_Region_X, (Free_Region_W - Bar_W) / 2)
                           else Free_Region_X);
                        Used   : constant Long_Long_Integer :=
                          Snapshot.Total_Space_Bytes - Snapshot.Free_Space_Bytes;
                        --  Warn in red when 10% or less of the disk is free.
                        Fill_Color : constant Render_Color :=
                          (if Snapshot.Free_Space_Bytes * 10 <= Snapshot.Total_Space_Bytes
                           then Error_Text_Color
                           else Selection_Color);
                     begin
                        if Bar_W > 0 then
                           Guikit.Widgets.Draw_Meter
                             (Result.Rectangles, Layout.Width, Layout.Height,
                              Bar_X, Bar_Y, Bar_W, Bar_H,
                              Used, Snapshot.Total_Space_Bytes,
                              Input_Color, Fill_Color);
                           Add_Border (Bar_X, Bar_Y, Bar_W, Bar_H, Border_Color);
                        end if;
                     end;
                  else
                     Add_Text
                       (Free_X,
                        Bottom_Content_Y,
                        Free_Field_W,
                        Bottom_Content_H,
                        To_Unbounded_String (Free_Text),
                        Command_Color (Files.Commands.Toggle_Free_Space_Display_Command),
                        Fit => True);
                  end if;
                  --  Tooltip describes the current mode and flips after a toggle.
                  Add_Tooltip
                    (Free_Region_X,
                     Bottom_Content_Y,
                     Free_Region_W,
                     Bottom_Content_H,
                     (if Free_Space_Bar_Active (Snapshot) then "status.space_bar.tooltip"
                      elsif Snapshot.Show_Used_Space then "status.used_space.tooltip"
                      else "status.free_space.tooltip"));
                  Add_Accessibility_Node
                    (Role_Button,
                     Free_Region_X,
                     Bottom_Content_Y,
                     Free_Region_W,
                     Bottom_Content_H,
                     Command_Label (Files.Commands.Toggle_Free_Space_Display_Command),
                     Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Free_Space_Display_Command)),
                     Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command));
               end;
            end if;
            Add_Tooltip_Text
              (Bottom.Info_X,
               Bottom_Content_Y,
               Toggle_W,
               Bottom_Content_H,
               Counts_Tip);
            Add_Accessibility_Node
              (Role_Button,
               Bottom.Info_X,
               Bottom_Content_Y,
               Toggle_W,
               Bottom_Content_H,
               Command_Label (Files.Commands.Toggle_Hidden_Files_Command),
               Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Hidden_Files_Command)),
               Enabled => Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command));
         end;
      end;
      declare
         Info_Btn_Y : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
         Info_Btn_H : constant Natural :=
           (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
            else Layout.Bottom_Bar_Height);
      begin
         Add_Rect
           (Bottom.Info_Pane_X,
            Info_Btn_Y,
            Bottom.Info_Pane_Width,
            Info_Btn_H,
            (if not Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) then Pane_Color
             elsif Snapshot.Info_Pane_Open
             then Selection_Color
             elsif Is_Pressed
               (Bottom.Info_Pane_X,
                Bottom_Y,
                Bottom.Info_Pane_Width,
                Layout.Bottom_Bar_Height)
             then Pressed_Color
             elsif Has_Hover
               and then Contains_Point
                 (Bottom.Info_Pane_X,
                  Bottom_Y,
                  Bottom.Info_Pane_Width,
                  Layout.Bottom_Bar_Height,
                  Hover_X,
                  Hover_Y)
             then Hover_Color
             else Bottom_Bar_Color));
      end;
      Add_Text
        (Saturating_Add (Bottom.Info_Pane_X, 4),
         Bottom_Content_Y,
         (if Bottom.Info_Pane_Width > 8 then Bottom.Info_Pane_Width - 8 else 0),
         Bottom_Content_H,
         Bottom_Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Command_Color (Files.Commands.Toggle_Info_Pane_Command),
         Fit => True);
      Add_Command_Tooltip
        (Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Files.Commands.Toggle_Info_Pane_Command);
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_Pane_X,
         Bottom_Content_Y,
         Bottom.Info_Pane_Width,
         Bottom_Content_H,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command),
         Selected => Snapshot.Info_Pane_Open);
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

      if Snapshot.View_Mode = Files.Types.Details then
         declare
            Content : constant Content_Rectangle := Main_Content_Rect (Layout);
            Content_X : constant Natural := Content.X;
            Content_Y : constant Natural := Content.Y;
            Content_W : constant Natural := Content.Width;
            Content_H : constant Natural := Content.Height;
            Header_H  : constant Natural :=
              Natural'Min
                (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
            Header_Y  : constant Natural := Content_Y;
            Header_W  : constant Natural := Content_W;
            Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
            --  Optically centre the label in the header field: sit it two pixels
            --  above the geometric inset, matching the bottom bar's text baseline
            --  (Bottom_Content_Y), so the glyphs read as centred rather than low.
            Text_Y    : constant Natural :=
              Saturating_Add (Header_Y, (if Header_Pad >= 2 then Header_Pad - 2 else 0));
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Header_Pad);

            function Cell_X (Column_X : Natural) return Natural is
            begin
               return Saturating_Add (Column_X, Details_Column_Padding);
            end Cell_X;

            function Cell_W (Column_W : Natural) return Natural is
            begin
               return (if Column_W > Details_Column_Padding then Column_W - Details_Column_Padding else 0);
            end Cell_W;

            function Header_Label (Column : Files.Types.Detail_Column) return String is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     return "details.name";
                  when Files.Types.Modified_Column =>
                     return "details.modified";
                  when Files.Types.Size_Column =>
                     return "details.size";
                  when Files.Types.Filetype_Column =>
                     return "details.filetype";
                  when Files.Types.Created_Column =>
                     return "details.created";
                  when Files.Types.Permissions_Column =>
                     return "details.permissions";
               end case;
            end Header_Label;

            function Column_Sort_Field
              (Column : Files.Types.Detail_Column;
               Field  : out Files.Model.Sort_Field)
               return Boolean is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     Field := Files.Model.Sort_Name;
                     return True;
                  when Files.Types.Modified_Column =>
                     Field := Files.Model.Sort_Changed;
                     return True;
                  when Files.Types.Size_Column =>
                     Field := Files.Model.Sort_Size;
                     return True;
                  when Files.Types.Filetype_Column =>
                     Field := Files.Model.Sort_Type;
                     return True;
                  when Files.Types.Created_Column =>
                     Field := Files.Model.Sort_Created;
                     return True;
                  when Files.Types.Permissions_Column =>
                     Field := Files.Model.Sort_Name;
                     return False;
               end case;
            end Column_Sort_Field;

            function Header_Text (Column : Files.Types.Detail_Column) return UString is
               Label : constant String := Files.Localization.Text (Header_Label (Column));
               Field : Files.Model.Sort_Field;
            begin
               if Column_Sort_Field (Column, Field) and then Snapshot.Sort_Field = Field then
                  return To_Unbounded_String (Label & " " & Direction_Text);
               else
                  return To_Unbounded_String (Label);
               end if;
            end Header_Text;

            function Header_Description return UString is
               Result : Unbounded_String := Null_Unbounded_String;
            begin
               for Column in Files.Types.Detail_Column loop
                  if Columns (Column).Visible then
                     if Length (Result) > 0 then
                        Append (Result, ", ");
                     end if;
                     Append (Result, Files.Localization.Text (Header_Label (Column)));
                  end if;
               end loop;
               return Result;
            end Header_Description;
         begin
            Add_Rect (Content_X, Header_Y, Header_W, Header_H, Pane_Color);
            Add_Border (Content_X, Header_Y, Header_W, Header_H, Border_Color);
            for Column in Files.Types.Detail_Column loop
               if Columns (Column).Visible then
                  Add_Text
                    (Cell_X (Columns (Column).X),
                     Text_Y,
                     Cell_W (Columns (Column).Width),
                     Line_Height,
                     Header_Text (Column),
                     Muted_Text_Color,
                     Fit => True);
               end if;
            end loop;
            Add_Accessibility_Node
              (Role_Table_Row,
               Content_X,
               Header_Y,
               Header_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.header")),
               Header_Description);

            if Header_H > 0 then
               for Column in Files.Types.Optional_Detail_Column loop
                  if Columns (Column).Visible then
                     Add_Rect
                       ((if Columns (Column).X > 2 then Columns (Column).X - 2 else 0),
                        Header_Y, 1, Header_H, Border_Color);
                  end if;
               end loop;
               Add_Rect
                 (Content_X,
                  Saturating_Add (Header_Y, Header_H - Natural'Min (2, Header_H)),
                  Header_W,
                  Natural'Min (2, Header_H),
                  Selection_Color);
            end if;
         end;
      end if;

      for Index in 1 .. Natural (Items.Length) loop
         declare
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
         begin
            --  Layout marks off-screen items with Height = 0 (Details rows that
            --  fall outside the scrolled viewport and icon cells past the
            --  bottom). Skip them so we don't pay per-item draw/accessibility
            --  cost for hundreds of invisible rows.
            if Item_Rect.Height = 0 or else Item_Rect.Width = 0 then
               goto Continue_Item_Loop;
            end if;
         end;

         declare
            Item      : Item_Snapshot renames Snapshot.Items (Positive (Index));
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
            --  Suppress the main-grid item hover highlight while the context
            --  menu is open: the pointer is interacting with the menu, so the
            --  cell under the cursor must not also light up. The menu's own row
            --  hover (drawn separately) is unaffected.
            Hovered   : constant Boolean :=
              Has_Hover
              and then not Snapshot.Context_Menu_Open
              and then Contains_Point
                (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_X, Hover_Y);
            Drop_Target : constant Boolean :=
              Has_Drag
              and then Drag_Item_Index /= 0
              and then Item.Visible_Index /= Drag_Item_Index
              and then Item.Kind = Files.Types.Directory_Item
              and then Hovered;
            --  Details mode needs the formatted modified/size text twice -- once
            --  to draw the row, once for the accessibility description. Format
            --  each once here; other view modes never touch them.
            Detail_Modified : constant UString :=
              (if Snapshot.View_Mode = Files.Types.Details
               then Detail_Time_Text (Item) else Null_Unbounded_String);
            Detail_Size : constant UString :=
              (if Snapshot.View_Mode = Files.Types.Details
               then Detail_Size_Text (Item) else Null_Unbounded_String);

         begin
            --  Grouping band header: a non-selectable caption row. It draws its
            --  own subdued background and label and then skips all per-item
            --  drawing (icon, columns, selection, hover).
            if Item.Is_Group_Header then
               Guikit.Item_Grid.Draw_Group_Header
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Accessibility    => Result.Accessibility,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  Label            => Item.Group_Label,
                  Line_Height      => Line_Height,
                  Background_Color => Pane_Color,
                  Label_Color      => Muted_Text_Color,
                  Border_Color     => Border_Color);
               goto Continue_Item_Loop;
            end if;

            declare
               Kind : constant Guikit.Item_Grid.Background_Kind :=
                 (if Drop_Target then Guikit.Item_Grid.Drop_Target
                  elsif Item.Selected then Guikit.Item_Grid.Selected
                  elsif Hovered then Guikit.Item_Grid.Hovered
                  elsif Snapshot.View_Mode = Files.Types.Details and then Index mod 2 = 0
                  then Guikit.Item_Grid.Alternate
                  else Guikit.Item_Grid.No_Background);
            begin
               Guikit.Item_Grid.Draw_Item_Background
                 (Rectangles      => Result.Rectangles,
                  Clip_Width      => Layout.Width,
                  Clip_Height     => Layout.Height,
                  Cell            => Item_Rect,
                  Kind            => Kind,
                  Selection_Color => Selection_Color,
                  Hover_Color     => Hover_Color,
                  Border_Color    => Border_Color,
                  Alternate_Color => Detail_Alternate_Color);
            end;

            if Snapshot.View_Mode = Files.Types.Details then
               Add_Details_Icon (Item, Item_Rect.Icon_X, Item_Rect.Icon_Y, Item_Rect.Icon_Size);
            else
               Add_Icon
                 (Item,
                  Item_Rect.Icon_X,
                  Item_Rect.Icon_Y,
                  Item_Rect.Icon_Size,
                  Use_Thumbnail => Snapshot.View_Mode = Files.Types.Large_Icons);
            end if;

            --  Favorite indicator: a small filled star tucked into the
            --  top-left corner of the item's icon in every view mode. Drawn
            --  only for favorited items, so a bare icon means "not favorited".
            --  Favorite star (top-left) and color-label dot (bottom-right) over
            --  the icon; each draws only when set.
            Guikit.Item_Grid.Draw_Item_Indicators
              (Rectangles    => Result.Rectangles,
               Text_Commands => Result.Text,
               Clip_Width    => Layout.Width,
               Clip_Height   => Layout.Height,
               Cell          => Item_Rect,
               Line_Height   => Line_Height,
               Favorite      => Item.Is_Favorite,
               Star_Glyph    => To_Unbounded_String (Favorite_Star_Filled_Text),
               Star_Color    => Favorite_Star_Color,
               Has_Label     => Item.Label /= Files.Types.No_Label,
               Label_Color   => Label_Render_Color (Item.Label));
            declare
               Renaming : constant Boolean := Item.Renaming;
            begin
               Guikit.Item_Grid.Draw_Name_Field
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  View             => Grid_View (Snapshot.View_Mode),
                  Renaming         => Renaming,
                  Focused          => Snapshot.Focus = Files.Types.Focus_Rename_Input,
                  Dim              => Item.Cut_Pending,
                  Text             => (if Renaming then Item.Rename_Value else Displayed_Name (Item)),
                  Cursor           => Item.Rename_Cursor,
                  Line_Height      => Line_Height,
                  Text_Color       => Text_Color,
                  Dim_Color        => Disabled_Text_Color,
                  Border_Color     => Border_Color,
                  Focus_Ring_Color => Snapshot.Theme_Focus_Ring,
                  Caret_Color      => Text_Color);
            end;

            if Snapshot.View_Mode = Files.Types.Details and then Item_Rect.Height > 0 then
               Guikit.Item_Grid.Draw_Details_Row
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Tooltips         => Result.Tooltips,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  Line_Height      => Line_Height,
                  Modified         => Detail_Modified,
                  Size             => Detail_Size,
                  Filetype         => Item.Filetype_Detail,
                  Created          => Detail_Created_Text (Item),
                  Permissions      => Item.Permissions,
                  Modified_Tooltip =>
                    (if Item.Modified_Available
                     then To_Unbounded_String (Full_Time_Text (Item.Modified_Time))
                     else Null_Unbounded_String),
                  Created_Tooltip  =>
                    (if Item.Creation_Available
                     then To_Unbounded_String (Full_Time_Text (Item.Creation_Time))
                     else Null_Unbounded_String),
                  Dim              => Item.Cut_Pending,
                  Value_Color      => Muted_Text_Color,
                  Dim_Color        => Disabled_Text_Color,
                  Border_Color     => Border_Color);
            end if;

            declare
               Row_Description : constant UString :=
                 (if Snapshot.View_Mode = Files.Types.Details
                  then To_Unbounded_String
                    (Detail_Modified_Label & ": " &
                     To_String (Detail_Modified) & ", " &
                     Detail_Size_Label & ": " &
                     To_String (Detail_Size) & ", " &
                     Detail_Filetype_Label & ": " &
                     To_String (Item.Filetype_Detail))
                  else Item.Filetype_Detail);
            begin
               Add_Accessibility_Node
                 ((if Snapshot.View_Mode = Files.Types.Details then Role_Table_Row else Role_List_Item),
                  Item_Rect.X,
                  Item_Rect.Y,
                  Item_Rect.Width,
                  Item_Rect.Height,
                  Item.Name,
                  Row_Description,
                  Enabled  => True,
                  Selected => Item.Selected,
                  Focused  => Item.Selected);
            end;
         end;

         <<Continue_Item_Loop>>
         null;
      end loop;

      if Snapshot.View_Mode = Files.Types.Details and then not Items.Is_Empty then
         declare
            Content   : constant Content_Rectangle := Main_Content_Rect (Layout);
            Content_X : constant Natural := Content.X;
            Content_W : constant Natural := Content.Width;
            Content_Y : constant Natural := Content.Y;
            Separator_Y : constant Natural := Content_Y;
            --  Bottom edge of the content viewport (excludes the bottom bar).
            Content_Bottom : constant Natural := Saturating_Add (Content_Y, Content.Height);

            --  The dividers span the visible rows only: down to the bottom edge of
            --  the last row that is actually on screen, clamped to the viewport.
            --  They must not descend past the last visible line into empty space
            --  below the list (nor through the bottom bar).
            function Last_Visible_Bottom return Natural is
               Result : Natural := Content_Y;
            begin
               for Row of Items loop
                  declare
                     Row_Bottom : constant Natural := Saturating_Add (Row.Y, Row.Height);
                  begin
                     if Row.Y < Content_Bottom and then Row_Bottom > Content_Y then
                        Result := Natural'Max (Result, Natural'Min (Row_Bottom, Content_Bottom));
                     end if;
                  end;
               end loop;
               return Result;
            end Last_Visible_Bottom;

            Separator_H : constant Natural := Last_Visible_Bottom - Separator_Y;
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Natural'Min (Details_Row_Padding, Line_Height));

            procedure Add_Column_Separator (Column_X : Natural) is
            begin
               Add_Rect ((if Column_X > 2 then Column_X - 2 else 0), Separator_Y, 1, Separator_H, Border_Color);
            end Add_Column_Separator;
         begin
            for Column in Files.Types.Optional_Detail_Column loop
               if Columns (Column).Visible then
                  Add_Column_Separator (Columns (Column).X);
               end if;
            end loop;
         end;
      end if;

      --  Rubber-band (marquee) selection rectangle: a translucent fill plus a
      --  solid selection-colored border over the grid while an empty-space drag
      --  is in progress. The items it touches are already drawn selected via the
      --  selection set, so this only shows the drag region itself.
      if Marquee_Active
        and then Marquee_W > 0
        and then Marquee_H > 0
        and then Width > 0
        and then Height > 0
      then
         Guikit.Widgets.Draw_Marquee
           (Rectangles   => Result.Rectangles,
            Clip_Width   => Layout.Width,
            Clip_Height  => Layout.Height,
            X            => Marquee_X,
            Y            => Marquee_Y,
            Width        => Marquee_W,
            Height       => Marquee_H,
            Fill_Color   => Marquee_Color,
            Border_Color => Selection_Color);
      end if;

      if Has_Drag
        and then Drag_Item_Index /= 0
        and then not Snapshot.Items.Is_Empty
        and then Width > 0
        and then Height > 0
      then
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            declare
               Item : Item_Snapshot renames Snapshot.Items (Positive (Index));
            begin
               if Item.Visible_Index = Drag_Item_Index then
                  declare
                     Icon_Size : constant Natural := Natural'Min (Natural'Max (Line_Height, 28), 48);
                     Pad       : constant Natural := 8;
                     Gap       : constant Natural := 8;
                     Panel_H   : constant Natural :=
                       Saturating_Add (Icon_Size, Saturating_Multiply (Pad, 2));
                     Panel_W   : constant Natural :=
                       Natural'Min
                         (Natural'Max
                            (Saturating_Add
                               (Saturating_Add (Icon_Size, Gap),
                                Saturating_Multiply (Line_Height, 8)),
                             Saturating_Add (Icon_Size, Saturating_Multiply (Pad, 2))),
                          Natural'Max (1, Width));
                     Offset    : constant Natural := 14;
                     Panel_X   : constant Natural :=
                       (if Drag_X <= Natural'Last - Offset
                          and then Drag_X + Offset <= Width
                          and then Width > Panel_W
                        then Natural'Min (Drag_X + Offset, Width - Panel_W)
                        elsif Width > Panel_W
                        then Width - Panel_W
                        else 0);
                     Panel_Y   : constant Natural :=
                       (if Drag_Y <= Natural'Last - Offset
                          and then Drag_Y + Offset <= Height
                          and then Height > Panel_H
                        then Natural'Min (Drag_Y + Offset, Height - Panel_H)
                        elsif Height > Panel_H
                        then Height - Panel_H
                        else 0);
                     Icon_X    : constant Natural := Saturating_Add (Panel_X, Pad);
                     Icon_Y    : constant Natural := Saturating_Add (Panel_Y, Pad);
                     Text_X    : constant Natural := Saturating_Add (Icon_X, Saturating_Add (Icon_Size, Gap));
                     Text_W    : constant Natural :=
                       (if Panel_W > Saturating_Add (Icon_Size, Saturating_Add (Gap, Saturating_Multiply (Pad, 2)))
                        then Panel_W - Icon_Size - Gap - Saturating_Multiply (Pad, 2)
                        else 0);
                     Text_Y    : constant Natural :=
                       Saturating_Add
                         (Panel_Y,
                          (if Panel_H > Line_Height then (Panel_H - Line_Height) / 2 else 0));
                  begin
                     Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Hover_Color);
                     Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Selection_Color);
                     Add_Icon (Item, Icon_X, Icon_Y, Icon_Size);
                     Add_Text (Text_X, Text_Y, Text_W, Line_Height, Item.Name, Fit => True);
                  end;

                  exit;
               end if;
            end;
         end loop;
      end if;

      if Empty_State_Key /= "" and then Layout.Main_Width > 0 and then Layout.Main_Height > 0 then
         declare
            Text_H : constant Natural := Line_Height;
            Panel_W : constant Natural :=
              Natural'Min (Natural'Max (240, Layout.Main_Width / 2), Layout.Main_Width);
            Panel_H : constant Natural := Natural'Min (Saturating_Multiply (Line_Height, 3), Layout.Main_Height);
            Panel_X : constant Natural :=
              Saturating_Add
                (Layout.Main_X,
                 (if Layout.Main_Width > Panel_W then (Layout.Main_Width - Panel_W) / 2 else 0));
            Panel_Y : constant Natural :=
              Saturating_Add
                (Layout.Main_Y,
                 (if Layout.Main_Height > Panel_H then (Layout.Main_Height - Panel_H) / 2 else 0));
            Text_Y : constant Natural :=
              Saturating_Add (Panel_Y, (if Panel_H > Text_H then (Panel_H - Text_H) / 2 else 0));
            Icon_Size : constant Natural := Natural'Min (Line_Height, Panel_H);
            Icon_X : constant Natural := Saturating_Add (Panel_X, 8);
            Text_X : constant Natural := Saturating_Add (Panel_X, Saturating_Add (Icon_Size, 16));
            Text_W : constant Natural :=
              (if Panel_W > Saturating_Add (Icon_Size, 24)
               then Panel_W - Saturating_Add (Icon_Size, 24)
               else Panel_W);
         begin
            Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Pane_Color);
            Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Border_Color);
            Add_Rect
              (Icon_X,
               Text_Y,
               Icon_Size,
               Natural'Min (Icon_Size, Text_H),
               Muted_Text_Color);
            if Icon_Size > 6 then
               Add_Rect
                 (Saturating_Add (Icon_X, Icon_Size / 4),
                  Saturating_Add (Text_Y, Icon_Size / 2),
                  Icon_Size / 2,
                  1,
                  Pane_Color);
            end if;
            Add_Text
              (Text_X,
               Text_Y,
               Text_W,
               Text_H,
               To_Unbounded_String (Files.Localization.Text (Empty_State_Key)),
               Muted_Text_Color,
               Fit => True);
         end;
      end if;

      if Main_View.Scrollbar_Visible then
         Add_Scrollbar
           (Main_View.Scrollbar_X,
            Main_View.Scrollbar_Y,
            Main_View.Scrollbar_Width,
            Main_View.Scrollbar_Track_Height,
            Main_View.Scrollbar_Thumb_Y,
            Main_View.Scrollbar_Height);
      end if;

      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (2, Info_Pane.Height),
            Border_Color);
         Add_Accessibility_Node
           (Role_Pane,
            Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Info_Pane.Height,
            Localized ("accessibility.info_pane"));
         declare
            --  The combined selection total is rendered as the last line of the
            --  Contents section (see Coalesced_Info_Sections), so no header rows
            --  are reserved above the list.
            Section_Offset_Rows : Natural := 0;
         begin

            if Natural (Snapshot.Selected_Info.Length) >= 2 then
               declare
                  --  Sections start at the top of the pane: the combined total is
                  --  now the Contents section's last line, not a reserved header.
                  Base_Y : constant Integer :=
                    Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding));
                  Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
                  Text_X : constant Natural := Saturating_Add (Layout.Main_Width, Info_Pane_Padding);
                  Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
                  Reserved_W : constant Natural :=
                    Saturating_Add
                      ((if Info_Pane.Scrollbar_Visible then Info_Pane.Scrollbar_Width else 0),
                       Saturating_Multiply (Info_Pane_Padding, 2));
                  Text_W : constant Natural :=
                    (if Layout.Info_Pane_Width > Reserved_W
                     then Layout.Info_Pane_Width - Reserved_W
                     else 0);
                  Sections : constant Coalesced_Section_Vectors.Vector :=
                    Coalesced_Info_Sections (Snapshot);
                  Current_Row : Natural := 0;

                  procedure Add_Info_Text
                    (Offset : Natural;
                     Text   : UString;
                     Color  : Render_Color := Text_Color;
                     Fit    : Boolean := True)
                  is
                     Y : constant Integer :=
                       Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
                  begin
                     if Y >= Integer (Info_Pane.Y)
                       and then Y < Integer (Info_Bottom)
                     then
                        Add_Text (Text_X, Natural (Y), Text_W, Line_Height, Text, Color, Fit => Fit);
                     end if;
                  end Add_Info_Text;

                  procedure Add_Info_Label
                    (Row : Natural;
                     Key : String)
                  is
                     Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
                  begin
                     Add_Info_Text (Row, Text, Text_Color);
                     if Text_W > 1 then
                        declare
                           Y : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                        begin
                           if Y >= Integer (Info_Pane.Y)
                             and then Y < Integer (Info_Bottom)
                           then
                              Add_Text
                                (Saturating_Add (Text_X, 1),
                                 Natural (Y),
                                 Text_W - 1,
                                 Line_Height,
                                 Text,
                                 Text_Color,
                                 Fit => True);
                           end if;
                        end;
                     end if;

                     --  A "<key>.tooltip" catalog entry, when present, describes
                     --  the section on hover.
                     declare
                        Tip_Key : constant String := Key & ".tooltip";
                        Tip_Y   : constant Integer :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                     begin
                        if Text_W > 0
                          and then Tip_Y >= Integer (Info_Pane.Y)
                          and then Tip_Y < Integer (Info_Bottom)
                          and then Files.Localization.Text (Tip_Key) /= Tip_Key
                        then
                           Add_Tooltip (Text_X, Natural (Tip_Y), Text_W, Line_Height, Tip_Key);
                        end if;
                     end;
                  end Add_Info_Label;

                  procedure Add_Info_Wrapped_Value
                    (Row   : Natural;
                     Text  : UString;
                     Color : Render_Color := Muted_Text_Color)
                  is
                     Raw        : constant String := To_String (Text);
                     Cell_W     : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
                     Capacity   : constant Natural := Text_W / Cell_W;
                     Line_Index : Natural := 0;

                     procedure Add_Wrapped_Segment
                       (Segment_First : Integer;
                        Segment_Last  : Integer)
                     is
                        Start : Integer := Segment_First;
                     begin
                        if Segment_Last < Segment_First then
                           Line_Index := Saturating_Add (Line_Index, 1);
                           return;
                        end if;

                        while Start <= Segment_Last loop
                           declare
                              Prefix : constant String :=
                                Files.UTF8.Prefix_By_Units (Raw (Start .. Segment_Last), Capacity);
                              Last   : constant Integer :=
                                (if Prefix'Length = 0 then Start else Start + Prefix'Length - 1);
                           begin
                              Add_Info_Text
                                (Saturating_Add (Row, Line_Index),
                                 To_Unbounded_String (Raw (Start .. Last)),
                                 Color,
                                 Fit => False);
                              exit when Last >= Segment_Last;
                              Start := Last + 1;
                              Line_Index := Saturating_Add (Line_Index, 1);
                           end;
                        end loop;

                        Line_Index := Saturating_Add (Line_Index, 1);
                     end Add_Wrapped_Segment;

                     Line_First : Integer := Raw'First;
                  begin
                     if Raw'Length = 0 or else Capacity = 0 then
                        Add_Info_Text (Row, Text, Color, Fit => False);
                        return;
                     end if;

                     for Position in Raw'Range loop
                        if Raw (Position) = ASCII.LF then
                           Add_Wrapped_Segment (Line_First, Position - 1);
                           Line_First := Position + 1;
                        end if;
                     end loop;

                     if Line_First <= Raw'Last then
                        Add_Wrapped_Segment (Line_First, Raw'Last);
                     elsif Raw (Raw'Last) = ASCII.LF then
                        Add_Info_Text (Saturating_Add (Row, Line_Index), Null_Unbounded_String, Color, Fit => False);
                     end if;
                  end Add_Info_Wrapped_Value;
               begin
                  --  Field-major coalesced layout: each section's label once,
                  --  then one value row per selected item (see Coalesced_Info_Rows
                  --  for the matching row accounting).
                  for Section of Sections loop
                     Add_Info_Label (Current_Row, To_String (Section.Key));
                     Current_Row := Saturating_Add (Current_Row, 1);
                     for Value of Section.Values loop
                        Add_Info_Wrapped_Value (Current_Row, Value);
                        Current_Row :=
                          Saturating_Add (Current_Row, Wrapped_Line_Count (Value, Text_W, Line_Height));
                     end loop;
                     Current_Row := Saturating_Add (Current_Row, 1);
                  end loop;

                  --  One accessibility node per item, anchored at its value row in
                  --  the first rendered section (values start one row below its
                  --  label). Advance by that section's per-item wrapped height.
                  if not Sections.Is_Empty then
                     declare
                        First : constant Coalesced_Section := Sections.First_Element;
                        Item_Row : Natural := 1;
                        Item_Index : Positive := 1;
                     begin
                        for Info of Snapshot.Selected_Info loop
                           declare
                              Y : constant Integer :=
                                Saturating_Integer_Add (Row_Y, Saturating_Multiply (Item_Row, Line_Height));
                              Visible_Y : constant Integer := Integer'Max (Y, Integer (Info_Pane.Y));
                              Description : constant Unbounded_String :=
                                To_Unbounded_String
                                  (Files.Localization.Text ("info.filetype") & ": " &
                                   To_String (Info_Field_Value (Info, 1)) & ", " &
                                   Files.Localization.Text ("info.size") & ": " &
                                   To_String (Info_Field_Value (Info, 2)));
                           begin
                              if Y >= Integer (Info_Pane.Y)
                                and then Y < Integer (Info_Bottom)
                                and then Text_W > 0
                              then
                                 Add_Accessibility_Node
                                   (Role_List_Item,
                                    Info_Pane.X,
                                    Natural (Visible_Y),
                                    Text_W,
                                    Line_Height,
                                    Info.Name,
                                    Description);
                              end if;
                              Item_Row :=
                                Saturating_Add
                                  (Item_Row,
                                   Wrapped_Line_Count (First.Values.Element (Item_Index), Text_W, Line_Height));
                              Item_Index := Item_Index + 1;
                           end;
                        end loop;
                     end;
                  end if;
               end;
            else
               for Index in 1 .. Natural (Snapshot.Selected_Info.Length) loop
                  declare
                     Info   : constant Info_Snapshot := Snapshot.Selected_Info.Element (Positive (Index));
                     Section_Offset : constant Natural := Saturating_Multiply (Section_Offset_Rows, Line_Height);
                     Base_Y : constant Integer :=
                       Saturating_Integer_Add
                         (Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding)), Section_Offset);
                     Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
                     Text_X : constant Natural := Saturating_Add (Layout.Main_Width, Info_Pane_Padding);
                     Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
                     Reserved_W : constant Natural :=
                       Saturating_Add
                         ((if Info_Pane.Scrollbar_Visible then Info_Pane.Scrollbar_Width else 0),
                          Saturating_Multiply (Info_Pane_Padding, 2));
                     Text_W : constant Natural :=
                       (if Layout.Info_Pane_Width > Reserved_W
                        then Layout.Info_Pane_Width - Reserved_W
                        else 0);

                     procedure Add_Info_Text
                       (Offset : Natural;
                        Text   : UString;
                        Color  : Render_Color := Text_Color;
                        Fit    : Boolean := True)
                     is
                        Y : constant Integer :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
                     begin
                        if Y >= Integer (Info_Pane.Y)
                          and then Y < Integer (Info_Bottom)
                        then
                           Add_Text (Text_X, Natural (Y), Text_W, Line_Height, Text, Color, Fit => Fit);
                        end if;
                     end Add_Info_Text;

                     procedure Add_Info_Label
                       (Row : Natural;
                        Key : String)
                     is
                        Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
                     begin
                        Add_Info_Text (Row, Text, Text_Color);
                        if Text_W > 1 then
                           declare
                              Y : constant Integer :=
                                Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                           begin
                              if Y >= Integer (Info_Pane.Y)
                                and then Y < Integer (Info_Bottom)
                              then
                                 Add_Text
                                   (Saturating_Add (Text_X, 1),
                                    Natural (Y),
                                    Text_W - 1,
                                    Line_Height,
                                    Text,
                                    Text_Color,
                                    Fit => True);
                              end if;
                           end;
                        end if;

                        --  A "<key>.tooltip" catalog entry, when present, describes
                        --  the section on hover.
                        declare
                           Tip_Key : constant String := Key & ".tooltip";
                           Tip_Y   : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                        begin
                           if Text_W > 0
                             and then Tip_Y >= Integer (Info_Pane.Y)
                             and then Tip_Y < Integer (Info_Bottom)
                             and then Files.Localization.Text (Tip_Key) /= Tip_Key
                           then
                              Add_Tooltip (Text_X, Natural (Tip_Y), Text_W, Line_Height, Tip_Key);
                           end if;
                        end;
                     end Add_Info_Label;

                     procedure Add_Info_Wrapped_Value
                       (Row   : Natural;
                        Text  : UString;
                        Color : Render_Color := Muted_Text_Color)
                     is
                        Raw        : constant String := To_String (Text);
                        Cell_W     : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
                        Capacity   : constant Natural := Text_W / Cell_W;
                        Line_Index : Natural := 0;

                        procedure Add_Wrapped_Segment
                          (Segment_First : Integer;
                           Segment_Last  : Integer)
                        is
                           Start : Integer := Segment_First;
                        begin
                           if Segment_Last < Segment_First then
                              Line_Index := Saturating_Add (Line_Index, 1);
                              return;
                           end if;

                           while Start <= Segment_Last loop
                              declare
                                 Prefix : constant String :=
                                   Files.UTF8.Prefix_By_Units (Raw (Start .. Segment_Last), Capacity);
                                 Last   : constant Integer :=
                                   (if Prefix'Length = 0 then Start else Start + Prefix'Length - 1);
                              begin
                                 Add_Info_Text
                                   (Saturating_Add (Row, Line_Index),
                                    To_Unbounded_String (Raw (Start .. Last)),
                                    Color,
                                    Fit => False);
                                 exit when Last >= Segment_Last;
                                 Start := Last + 1;
                                 Line_Index := Saturating_Add (Line_Index, 1);
                              end;
                           end loop;

                           Line_Index := Saturating_Add (Line_Index, 1);
                        end Add_Wrapped_Segment;

                        Line_First : Integer := Raw'First;
                     begin
                        if Raw'Length = 0 or else Capacity = 0 then
                           Add_Info_Text (Row, Text, Color, Fit => False);
                           return;
                        end if;

                        for Position in Raw'Range loop
                           if Raw (Position) = ASCII.LF then
                              Add_Wrapped_Segment (Line_First, Position - 1);
                              Line_First := Position + 1;
                           end if;
                        end loop;

                        if Line_First <= Raw'Last then
                           Add_Wrapped_Segment (Line_First, Raw'Last);
                        elsif Raw (Raw'Last) = ASCII.LF then
                           Add_Info_Text (Saturating_Add (Row, Line_Index), Null_Unbounded_String, Color, Fit => False);
                        end if;
                     end Add_Info_Wrapped_Value;

                     Current_Row : Natural := 0;

                     procedure Add_Info_Field
                       (Key   : String;
                        Value : UString;
                        Field : Natural;
                        Color : Render_Color := Muted_Text_Color)
                     is
                        --  Postfix the value with the item name (dropping the Name
                        --  field), matching Info_Section_Row_Count's row accounting.
                        Display_Value : constant UString :=
                          (if Field = 8 then Info_Field_Display_Value (Info, Field) else Value)
                          & Info_Postfix (Info);
                        Value_Rows : constant Natural := Wrapped_Line_Count (Display_Value, Text_W, Line_Height);
                     begin
                        Add_Info_Label (Current_Row, Key);
                        Current_Row := Saturating_Add (Current_Row, 1);
                        Add_Info_Wrapped_Value (Current_Row, Display_Value, Color);
                        Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                     end Add_Info_Field;

                     --  Draw the permissions matrix: a "Permissions" label, an
                     --  R/W/E column header, a 3x3 rwx grid (rows user/group/other,
                     --  columns read/write/execute) with a per-row label, and -- when
                     --  editable -- one click hit region per cell. Cell index Bit
                     --  maps to POSIX mode bit 2 ** (8 - Bit); a filled cell is set.
                     procedure Add_Permission_Grid is
                        Cell : constant Natural := Natural'Max (6, Line_Height - 6);
                        Gap  : constant Natural := Natural'Max (2, Line_Height / 6);
                        --  Approximate glyph advance, used to horizontally centre a
                        --  header letter over its column.
                        Char_W : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
                        --  The glyph box is ~4/5 of the line height and sits at the
                        --  bottom of the row (the leading is above it), so centre the
                        --  cell square within that font box -- not the whole line --
                        --  to line it up with the row label text.
                        Font_H : constant Natural := Saturating_Multiply (Line_Height, 4) / 5;
                        Cell_Top : constant Natural :=
                          (if 2 * Line_Height > Font_H + Cell then Line_Height - (Font_H + Cell) / 2 + 1 else 0);
                        --  Horizontal inset that centres a header letter over a cell.
                        Header_Pad : constant Natural := (if Cell > Char_W then (Cell - Char_W) / 2 else 0);
                        --  The row labels sit just past the three columns.
                        Labels_X : constant Natural :=
                          Saturating_Add
                            (Text_X, Saturating_Add (Saturating_Multiply (3, Cell + Gap), Gap));
                        Labels_W : constant Natural :=
                          (if Text_W > Labels_X - Text_X then Text_W - (Labels_X - Text_X) else 0);

                        --  Draw a clipped label/glyph at a section-row offset.
                        procedure Add_At (X : Natural; Section_Row : Natural; Width : Natural; Text : String) is
                           Y : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Section_Row, Line_Height));
                        begin
                           if Width > 0
                             and then Y >= Integer (Info_Pane.Y)
                             and then Y < Integer (Info_Bottom)
                           then
                              Add_Text
                                (X, Natural (Y), Width, Line_Height,
                                 To_Unbounded_String (Text), Muted_Text_Color, Fit => True);
                           end if;
                        end Add_At;

                        Column_Header : constant array (0 .. 2) of Character := ('R', 'W', 'E');

                        function Row_Label_Key (Row : Natural) return String is
                          (case Row is
                              when 0      => "info.permissions.user",
                              when 1      => "info.permissions.group",
                              when others => "info.permissions.other");
                     begin
                        Add_Info_Label (Current_Row, "info.permissions");

                        --  R/W/E header, one letter centred over each column.
                        for Col in 0 .. 2 loop
                           Add_At
                             (Saturating_Add
                                (Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap)), Header_Pad),
                              Current_Row + 1, Char_W, [1 => Column_Header (Col)]);
                        end loop;

                        for Bit in 0 .. 8 loop
                           declare
                              Col   : constant Natural := Bit mod 3;
                              Row   : constant Natural := Bit / 3;
                              Cell_X : constant Natural :=
                                Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap));
                              Cell_Y : constant Integer :=
                                Saturating_Integer_Add
                                  (Saturating_Integer_Add
                                     (Row_Y,
                                      Saturating_Multiply (Saturating_Add (Current_Row + 2, Row), Line_Height)),
                                   Cell_Top);
                              Is_Set : constant Boolean :=
                                (Info.Mode_Bits / (2 ** (8 - Bit))) mod 2 = 1;
                           begin
                              if Cell_Y >= Integer (Info_Pane.Y)
                                and then Cell_Y + Integer (Cell) <= Integer (Info_Bottom)
                              then
                                 Add_Rect (Cell_X, Natural (Cell_Y), Cell, Cell, Border_Color);
                                 if Cell > 2 then
                                    Add_Rect
                                      (Saturating_Add (Cell_X, 1),
                                       Natural (Cell_Y) + 1,
                                       Cell - 2,
                                       Cell - 2,
                                       (if Is_Set then Selection_Color else Input_Color));
                                 end if;
                                 if Snapshot.Permissions_Editable then
                                    Result.Permission_Hits.Append
                                      (Permission_Hit_Region'
                                         (Present => True,
                                          Bit     => Bit,
                                          X       => Cell_X,
                                          Y       => Natural (Cell_Y),
                                          Width   => Cell,
                                          Height  => Cell));
                                 end if;
                              end if;
                           end;
                        end loop;

                        --  Per-row labels: user / group / other.
                        for Row in 0 .. 2 loop
                           Add_At
                             (Labels_X, Current_Row + 2 + Row, Labels_W,
                              Files.Localization.Text (Row_Label_Key (Row)));
                        end loop;

                        Current_Row := Saturating_Add (Current_Row, Permission_Grid_Rows);
                     end Add_Permission_Grid;

                     --  Draw an editable owner or group value and register one
                     --  click hit region over it. While editing, the value shows
                     --  the editor buffer with an underline and a text caret.
                     procedure Add_Ownership_Field
                       (Key     : String;
                        Field   : Natural;
                        Editing : Boolean)
                     is
                        Value      : constant UString := Info_Field_Value (Info, Field);
                        Value_Rows : constant Natural := Wrapped_Line_Count (Value, Text_W, Line_Height);
                        Value_Row  : Natural;
                        Cell_Y     : Integer;
                     begin
                        Add_Info_Label (Current_Row, Key);
                        Current_Row := Saturating_Add (Current_Row, 1);
                        Value_Row := Current_Row;
                        Add_Info_Wrapped_Value
                          (Value_Row, Value, (if Editing then Text_Color else Muted_Text_Color));
                        Cell_Y :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Value_Row, Line_Height));
                        if Cell_Y >= Integer (Info_Pane.Y)
                          and then Cell_Y < Integer (Info_Bottom)
                          and then Text_W > 0
                        then
                           Result.Ownership_Hits.Append
                             (Ownership_Hit_Region'
                                (Present  => True,
                                 Is_Group => Field = 10,
                                 X        => Text_X,
                                 Y        => Natural (Cell_Y),
                                 Width    => Text_W,
                                 Height   => Line_Height));
                           if Editing then
                              Add_Rect
                                (Text_X,
                                 Saturating_Add (Natural (Cell_Y), Line_Height - 1),
                                 Text_W,
                                 1,
                                 Selection_Color);
                              declare
                                 Char_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                                 Raw     : constant String := To_String (Value);
                                 Caret_X : constant Natural :=
                                   Saturating_Add
                                     (Text_X,
                                      Saturating_Multiply
                                        (Files.UTF8.Display_Units_Before
                                           (Raw, Snapshot.Text_Cursor_Position),
                                         Char_W));
                              begin
                                 Add_Rect
                                   (Caret_X,
                                    Saturating_Add (Natural (Cell_Y), 2),
                                    2,
                                    (if Line_Height > 4 then Line_Height - 4 else Line_Height),
                                    Text_Color);
                              end;
                           end if;
                        end if;
                        Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                     end Add_Ownership_Field;
                  begin
                     --  No Name field: the item name is postfixed onto every value.
                     Add_Info_Field ("info.filetype", Info_Field_Value (Info, 1), 1);
                     --  Filesize is a file-only field; a folder shows Contents.
                     if not Info.Is_Directory then
                        Add_Info_Field ("info.size", Info_Field_Value (Info, 2), 2);
                     end if;
                     if Info.Is_Directory and then Info.Folder_Size_Available then
                        Add_Info_Field ("info.folder_size", Folder_Contents_Text (Info), 2);
                     end if;
                     Add_Info_Field ("info.created", Info_Field_Value (Info, 3), 3);
                     Add_Info_Field ("info.modified", Info_Field_Value (Info, 4), 4);
                     --  Permissions render as a labelled matrix (no text summary),
                     --  clickable only when editable (gated inside Add_Permission_Grid).
                     if Info.Mode_Available then
                        Add_Permission_Grid;
                     end if;
                     if Info.Ownership_Available then
                        Add_Ownership_Field ("info.owner", 9, Info.Owner_Editing);
                        Add_Ownership_Field ("info.group", 10, Info.Group_Editing);
                     end if;
                     --  Metadata Error only appears when the item's metadata could
                     --  not be read; healthy items show no such row.
                     if Info.Metadata_Error then
                        Add_Info_Field ("info.metadata_error", Info_Field_Value (Info, 6), 6);
                     end if;
                     --  Kind (field 7) is omitted: it duplicates the Filetype field.
                     Add_Info_Field ("info.extra", Info_Field_Value (Info, 8), 8);
                     declare
                        Section_H : constant Natural :=
                          Natural'Min
                            (Saturating_Multiply
                               (Line_Height,
                                Info_Section_Row_Count (Info, Text_W, Line_Height)),
                             Info_Pane.Height);
                        Visible_Y : constant Integer := Integer'Max (Row_Y, Integer (Info_Pane.Y));
                        Raw_Bottom : constant Integer :=
                          Integer'Min
                            (Saturating_Integer_Add (Row_Y, Section_H),
                             Integer (Info_Bottom));
                        Visible_H : constant Natural :=
                          (if Raw_Bottom > Visible_Y then Natural (Raw_Bottom - Visible_Y) else 0);
                        Size_Text : constant String := To_String (Info_Field_Value (Info, 2));
                        Modified_Text : constant String :=
                          To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified"));
                        Description : Unbounded_String :=
                          To_Unbounded_String
                            (Files.Localization.Text ("info.filetype") & ": " &
                             To_String (Info_Field_Value (Info, 1)) & ", " &
                             Files.Localization.Text ("info.size") & ": " &
                             Size_Text & ", " &
                             Modified_Text);
                     begin
                        if Info.Metadata_Error then
                           Append
                             (Description,
                              ", " &
                              Files.Localization.Text ("info.metadata_error") & ": " &
                              Files.Localization.Text (To_String (Info.Error_Key)));
                        end if;

                        Add_Accessibility_Node
                          (Role_List_Item,
                           Info_Pane.X,
                           Natural (Visible_Y),
                           Text_W,
                           Visible_H,
                           Info.Name,
                           Description);
                     end;
                     Section_Offset_Rows :=
                       Saturating_Add
                         (Section_Offset_Rows,
                          Info_Section_Row_Count (Info, Text_W, Line_Height));
                  end;
               end loop;
            end if;
         end;

         if Info_Pane.Scrollbar_Visible then
            Add_Scrollbar
              (Info_Pane.Scrollbar_X,
               Info_Pane.Scrollbar_Y,
               Info_Pane.Scrollbar_Width,
               Info_Pane.Scrollbar_Track_Height,
               Info_Pane.Scrollbar_Thumb_Y,
               Info_Pane.Scrollbar_Height);
         end if;
         --  Keep the close button clear of the scrollbar column on the right.
         Draw_Close_Button
           (Info_Pane.X,
            Info_Pane.Y,
            (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
             then Info_Pane.Width - Info_Pane.Scrollbar_Width
             else Info_Pane.Width),
            Info_Pane.Height,
            Overlay => False);
      end if;

      if Snapshot.Quick_Look_Open then
         declare
            QL      : constant Quick_Look_Layout := Calculate_Quick_Look_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (QL.X, Margin);
            Title_Y : constant Natural := Saturating_Add (QL.Y, Natural'Max (4, Line_Height / 4));
            Title_W : constant Natural :=
              (if QL.Width > Saturating_Multiply (Margin, 2)
               then QL.Width - Saturating_Multiply (Margin, 2) else QL.Width);
         begin
            Add_Overlay_Drop_Shadow (QL.X, QL.Y, QL.Width, QL.Height);
            Add_Overlay_Rect (QL.X, QL.Y, QL.Width, QL.Height, Pane_Color);
            Add_Overlay_Border (QL.X, QL.Y, QL.Width, QL.Height, Border_Color);
            Add_Overlay_Rect (QL.X, QL.Y, QL.Width, Natural'Min (3, QL.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, QL.X, QL.Y, QL.Width, QL.Height, Localized ("accessibility.quick_look"));
            --  Panel title: the previewed item's name, which also serves as the
            --  content marker tests assert on for every kind.
            Add_Overlay_Text (Title_X, Title_Y, Title_W, Line_Height, Snapshot.Quick_Look_Name, Fit => True);

            case Snapshot.Quick_Look_Kind is
               when Files.Quick_Look.Image_Content =>
                  if Natural (Snapshot.Quick_Look_Image_Pixels.Length) > 0
                    and then Snapshot.Quick_Look_Image_Width > 0
                    and then Snapshot.Quick_Look_Image_Height > 0
                  then
                     declare
                        IW : constant Natural := Snapshot.Quick_Look_Image_Width;
                        IH : constant Natural := Snapshot.Quick_Look_Image_Height;
                        CW : constant Natural := QL.Content_Width;
                        CH : constant Natural := QL.Content_Height;
                        --  Fit the image inside the content box preserving aspect.
                        Height_Bound : constant Boolean :=
                          Saturating_Multiply (IW, CH) <= Saturating_Multiply (IH, CW);
                        Draw_W : constant Natural :=
                          (if Height_Bound then Saturating_Multiply (IW, CH) / IH else CW);
                        Draw_H : constant Natural :=
                          (if Height_Bound then CH else Saturating_Multiply (IH, CW) / IW);
                        Img_X  : constant Natural :=
                          Saturating_Add (QL.Content_X, (if CW > Draw_W then (CW - Draw_W) / 2 else 0));
                        Img_Y  : constant Natural :=
                          Saturating_Add (QL.Content_Y, (if CH > Draw_H then (CH - Draw_H) / 2 else 0));
                     begin
                        if Draw_W > 0 and then Draw_H > 0 then
                           --  One icon command carrying the decoded pixels; the
                           --  atlas gives it a high-resolution tile and it draws
                           --  at its aspect-correct size.
                           Result.Icons.Append
                             (Icon_Command'
                                (X                => Img_X,
                                 Y                => Img_Y,
                                 Size             => Draw_W,
                                 Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                                 Theme_Name       => Snapshot.Theme_Name,
                                 Asset_Path       => Null_Unbounded_String,
                                 Thumbnail_Width  => IW,
                                 Thumbnail_Height => IH,
                                 Thumbnail_Pixels => Snapshot.Quick_Look_Image_Pixels,
                                 Overlay          => True,
                                 Draw_Width       => Draw_W,
                                 Draw_Height      => Draw_H));
                        end if;
                     end;
                  else
                     Add_Overlay_Text
                       (QL.Content_X, QL.Content_Y, QL.Content_Width, Line_Height,
                        Localized ("quick_look.empty"), Muted_Text_Color);
                  end if;
               when Files.Quick_Look.Text_Content =>
                  declare
                     Max_Lines : constant Natural :=
                       (if QL.Content_Height >= Line_Height then QL.Content_Height / Line_Height else 0);
                     Row       : Natural := 0;
                  begin
                     for Line of Snapshot.Quick_Look_Text_Lines loop
                        exit when Row >= Max_Lines;
                        Add_Overlay_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height, Line, Fit => True);
                        Row := Row + 1;
                     end loop;
                     if Snapshot.Quick_Look_Text_Truncated and then Row < Max_Lines then
                        Add_Overlay_Text
                          (QL.Content_X,
                           Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                           QL.Content_Width, Line_Height,
                           Localized ("quick_look.truncated"), Muted_Text_Color, Italic => True);
                     end if;
                  end;
               when Files.Quick_Look.Info_Content =>
                  declare
                     Icon_Size : constant Natural :=
                       Natural'Min (Saturating_Multiply (Line_Height, 3), QL.Content_Width);
                     Row_Y     : Natural :=
                       Saturating_Add (QL.Content_Y, Saturating_Add (Icon_Size, Margin));
                     Size_Value : constant UString :=
                       (if Snapshot.Quick_Look_Size_Available
                        then To_Unbounded_String (Size_Text (Snapshot.Quick_Look_Size))
                        else Localized ("status.missing_metadata"));
                  begin
                     if Icon_Size > 0 then
                        Result.Icons.Append
                          (Icon_Command'
                             (X                => QL.Content_X,
                              Y                => QL.Content_Y,
                              Size             => Icon_Size,
                              Icon_Id          => Snapshot.Quick_Look_Icon_Id,
                              Theme_Name       => Snapshot.Theme_Name,
                              Asset_Path       => Null_Unbounded_String,
                              Thumbnail_Width  => 0,
                              Thumbnail_Height => 0,
                              Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector,
                              Overlay          => True,
                              Draw_Width       => 0,
                              Draw_Height      => 0));
                     end if;
                     Add_Overlay_Text
                       (QL.Content_X, Row_Y, QL.Content_Width, Line_Height,
                        Snapshot.Quick_Look_Type, Muted_Text_Color, Fit => True);
                     Row_Y := Saturating_Add (Row_Y, Line_Height);
                     Add_Overlay_Text
                       (QL.Content_X, Row_Y, QL.Content_Width, Line_Height,
                        Size_Value, Muted_Text_Color, Fit => True);
                  end;
            end case;

            Draw_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, Overlay => True);
         end;
      end if;

      if Snapshot.Label_Picker_Open then
         declare
            Picker  : constant Label_Picker_Layout :=
              Calculate_Label_Picker_Layout (Layout, Line_Height);
            Margin  : constant Natural := Natural'Max (Command_Palette_Padding, Line_Height / 2);
            Title_X : constant Natural := Saturating_Add (Picker.X, Margin);
            Title_Y : constant Natural := Saturating_Add (Picker.Y, Natural'Max (4, Line_Height / 4));
            Title_W : constant Natural :=
              (if Picker.Width > Saturating_Multiply (Margin, 2)
               then Picker.Width - Saturating_Multiply (Margin, 2) else Picker.Width);
         begin
            Add_Drop_Shadow (Picker.X, Picker.Y, Picker.Width, Picker.Height);
            Add_Rect (Picker.X, Picker.Y, Picker.Width, Picker.Height, Pane_Color);
            Add_Border (Picker.X, Picker.Y, Picker.Width, Picker.Height, Border_Color);
            Add_Rect (Picker.X, Picker.Y, Picker.Width, Natural'Min (3, Picker.Height), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog, Picker.X, Picker.Y, Picker.Width, Picker.Height,
               Localized ("accessibility.label_picker"));
            Add_Text (Title_X, Title_Y, Title_W, Line_Height, Localized ("label_picker.title"), Fit => True);

            for Index in Picker.Swatches'Range loop
               declare
                  Swatch  : constant Label_Swatch_Bounds := Picker.Swatches (Index);
                  Label   : constant Files.Types.Color_Label := Label_For_Swatch (Index);
                  Hovered : constant Boolean :=
                    Has_Hover
                    and then Contains_Point (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Hover_X, Hover_Y);
                  Highlighted : constant Boolean := Index = Snapshot.Label_Picker_Highlight;
                  Name    : constant UString :=
                    Localized
                      ((case Label is
                          when Files.Types.No_Label => "label.color.none",
                          when Files.Types.Red      => "label.color.red",
                          when Files.Types.Orange   => "label.color.orange",
                          when Files.Types.Yellow   => "label.color.yellow",
                          when Files.Types.Green    => "label.color.green",
                          when Files.Types.Blue     => "label.color.blue",
                          when Files.Types.Purple   => "label.color.purple",
                          when Files.Types.Gray     => "label.color.gray"));
               begin
                  if Label = Files.Types.No_Label then
                     --  The clear swatch is an empty bordered box rather than a
                     --  filled color, so it reads as "remove any label".
                     Add_Rect (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Pane_Color);
                  else
                     Add_Rect (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Label_Render_Color (Label));
                  end if;
                  Add_Border
                    (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height,
                     (if Hovered or else Highlighted then Selection_Color else Border_Color));
                  if Highlighted and then Swatch.Width > 4 and then Swatch.Height > 4 then
                     --  A second inset ring so the keyboard highlight reads
                     --  distinctly from a plain mouse hover.
                     Add_Border
                       (Swatch.X + 2, Swatch.Y + 2, Swatch.Width - 4, Swatch.Height - 4,
                        Selection_Color);
                  end if;
                  Add_Accessibility_Node
                    (Role_Button, Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height, Name);
               end;
            end loop;

            Draw_Close_Button (Picker.X, Picker.Y, Picker.Width, Picker.Height, Overlay => False);
         end;
      end if;

      if Snapshot.Sort_Menu_Open and then Bottom.Sort_Button_Width > 0 then
         declare
            Row_Count : constant Natural := 5;
            Row_H     : constant Natural :=
              Saturating_Add (Line_Height, Saturating_Multiply (Guikit.Layout.Bottom_Bar_Padding, 2));
            Rows_H    : constant Natural := Saturating_Multiply (Row_H, Row_Count);
            Menu_H    : constant Natural :=
              Saturating_Add (Rows_H, Saturating_Multiply (Guikit.Layout.Sort_Menu_Padding, 2));
            Menu_X    : constant Natural := Bottom.Sort_Button_X;
            Menu_Y    : constant Natural := (if Bottom_Y > Menu_H then Bottom_Y - Menu_H else 0);
            --  The dropdown fits the widest field, not the (snug) sort button.
            Menu_W    : constant Natural := Files.UI.Sort_Menu_Width (Line_Height);
            Rows_Y    : constant Natural := Saturating_Add (Menu_Y, Guikit.Layout.Sort_Menu_Padding);
            Row_X     : constant Natural := Saturating_Add (Menu_X, 1);
            Row_W     : constant Natural := (if Menu_W > 2 then Menu_W - 2 else 0);

            type Sort_Field_Array is array (Positive range <>) of Files.Model.Sort_Field;
            Fields : constant Sort_Field_Array :=
              [Files.Model.Sort_Name,
               Files.Model.Sort_Size,
               Files.Model.Sort_Type,
               Files.Model.Sort_Created,
               Files.Model.Sort_Changed];
         begin
            Add_Overlay_Rect (Menu_X, Menu_Y, Menu_W, Menu_H, Overlay_Color);
            Add_Overlay_Border (Menu_X, Menu_Y, Menu_W, Menu_H, Border_Color);
            Add_Accessibility_Node
              (Role_List,
               Menu_X,
               Menu_Y,
               Menu_W,
               Menu_H,
               Localized ("command.sort.menu"));

            declare
               --  Row backgrounds and label text are the shared list geometry --
               --  delegate them to Guikit.List_Panel. The chrome, 1px inter-row
               --  separators and the richer accessibility stay here. The sort menu
               --  has no selected accent bar, so each row's accent is set to the
               --  selection colour, which renders Draw_Palette_Row's accent
               --  invisible against a selected row's background.
               List_Rows    : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
               Discard_A11y : Guikit.Draw.Accessibility_Node_Vectors.Vector;
               Config : constant Guikit.List_Panel.List_Panel_Configuration :=
                 (Line_Height         => Line_Height,
                  Text_Padding        => Guikit.Layout.Input_Field_Padding,
                  Show_Alternate_Rows => False,
                  others              => <>);
            begin
               for Row in Fields'Range loop
                  declare
                     Field    : constant Files.Model.Sort_Field := Fields (Row);
                     Row_Y    : constant Natural :=
                       Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                     Hovered  : constant Boolean :=
                       Has_Hover and then Contains_Point (Menu_X, Row_Y, Menu_W, Row_H, Hover_X, Hover_Y);
                     Pressed  : constant Boolean := Is_Pressed (Menu_X, Row_Y, Menu_W, Row_H);
                     Enabled  : constant Boolean := Snapshot.Command_Enabled (Sort_Field_Command (Field));
                     Label    : constant UString :=
                       To_Unbounded_String
                         (Sort_Field_Label (Field)
                          & (if Selected then " " & Direction_Text else ""));
                  begin
                     List_Rows.Append
                       (Guikit.List_Panel.List_Panel_Row'
                          (Label            => Label,
                           Selected         => Selected,
                           Enabled          => Enabled,
                           Label_Color      => (if Enabled then Text_Color else Disabled_Text_Color),
                           Accent_Color     => Selection_Color,
                           Has_Background   => not Selected,
                           Background_Color =>
                             (if Pressed then Pressed_Color
                              elsif Hovered then Hover_Color
                              else Overlay_Color),
                           others           => <>));
                  end;
               end loop;

               Guikit.List_Panel.Draw_Frame
                 (Rectangles    => Result.Overlay_Rectangles,
                  Text          => Result.Overlay_Text,
                  Accessibility => Discard_A11y,
                  Clip_Width    => Layout.Width,
                  Clip_Height   => Layout.Height,
                  Region_X      => Row_X,
                  Region_Y      => Rows_Y,
                  Region_Width  => Row_W,
                  Region_Height => Rows_H,
                  Config        => Config,
                  Rows          => List_Rows,
                  Draw_Chrome   => False,
                  Row_Height    => Row_H);

               for Row in Fields'Range loop
                  declare
                     Field : constant Files.Model.Sort_Field := Fields (Row);
                     Row_Y : constant Natural :=
                       Saturating_Add (Rows_Y, Saturating_Multiply (Natural (Row - 1), Row_H));
                     Selected : constant Boolean := Field = Snapshot.Sort_Field;
                     Label : constant UString :=
                       To_Unbounded_String
                         (Sort_Field_Label (Field)
                          & (if Selected then " " & Direction_Text else ""));
                  begin
                     if Row > Fields'First then
                        Add_Overlay_Rect (Row_X, Row_Y, Row_W, 1, Border_Color);
                     end if;
                     Add_Accessibility_Node
                       (Role_List_Item,
                        Menu_X,
                        Row_Y,
                        Menu_W,
                        Row_H,
                        Label,
                        Localized (Files.Commands.Description_Key (Sort_Field_Command (Field))),
                        Enabled  => Snapshot.Command_Enabled (Sort_Field_Command (Field)),
                        Selected => Selected);
                  end;
               end loop;
            end;
         end;
      end if;

      Draw_Overlay_Commands;

      Add_Hover_Tooltip;

      return Result;
   end Build_Frame_Commands;
