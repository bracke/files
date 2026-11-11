separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Icon
     (Item : Item_Snapshot;
      X    : Natural;
      Y    : Natural;
      Size : Natural;
      Use_Thumbnail : Boolean := False;
      Overlay       : Boolean := False)
   is
      use type Files.File_Types.Icon_Kind;

      Base_Color : constant Render_Color := Icon_Color (Item.Kind);
      --  The icon was resolved when the snapshot was built: this draws it.
      Icon       : constant Files.File_Types.Icon_Kind := Item.Icon;
      Icon_Name  : constant String := Files.File_Types.Icon_Name (Icon);
      Thumbnail  : constant Boolean :=
        Use_Thumbnail and then Item.Thumbnail_Available and then Length (Item.Thumbnail_Path) > 0;
      Draw_Size  : constant Natural :=
        Natural'Min
          (Size,
           Natural'Min
             (Clipped_Size (X, Size, Layout.Width),
              Clipped_Size (Y, Size, Layout.Height)));
      Accent     : constant Render_Color :=
        (if Item.Kind = Files.Types.Executable_Item or else Icon = Files.File_Types.Ada_Icon
         then Icon_Program_Color
         else Selection_Color);
      Fold       : constant Natural := Natural'Max (1, Draw_Size / 4);
      Stripe_W   : constant Natural := Natural'Max (1, Draw_Size / 5);
      Body_Y     : constant Natural := Saturating_Add (Y, Natural'Max (1, Draw_Size / 4));
      Body_H     : constant Natural :=
        (if Draw_Size > Body_Y - Y then Draw_Size - (Body_Y - Y) else Draw_Size);

      function Scale (Numerator : Natural; Denominator : Positive) return Natural is
      begin
         return Bounded_Product_Divide (Draw_Size, Numerator, Denominator);
      end Scale;

      function X_Offset (Offset : Natural) return Natural is
      begin
         return Saturating_Add (X, Offset);
      end X_Offset;

      function Y_Offset (Offset : Natural) return Natural is
      begin
         return Saturating_Add (Y, Offset);
      end Y_Offset;

      function Asset_Color (Role : Icon_Asset_Color_Role) return Render_Color is
      begin
         case Role is
            when Icon_Asset_Base =>
               return Base_Color;
            when Icon_Asset_Accent =>
               return Accent;
            when Icon_Asset_Border =>
               return Border_Color;
            when Icon_Asset_Muted =>
               return Muted_Text_Color;
         end case;
      end Asset_Color;

      procedure Add_Asset_Rect
      (Asset : Icon_Asset;
       Rect  : Icon_Asset_Rect)
      is
         Rect_X : constant Natural :=
           Saturating_Add
             (X, Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_Y : constant Natural :=
           Saturating_Add
             (Y, Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_W : constant Natural :=
           Natural'Max
             (1, Bounded_Product_Divide (Value => Rect.Grid_W, Factor => Draw_Size, Denominator => Asset.Grid));
         Rect_H : constant Natural :=
           Natural'Max
             (1, Bounded_Product_Divide (Value => Rect.Grid_H, Factor => Draw_Size, Denominator => Asset.Grid));
      begin
         Add_Rect (Rect_X, Rect_Y, Rect_W, Rect_H, Asset_Color (Rect.Role));
      end Add_Asset_Rect;

      procedure Add_Asset_Tri
        (Asset : Icon_Asset;
         Tri   : Icon_Asset_Tri)
      is
         function PX (G : Natural) return Float is
           (Float (Saturating_Add
              (X, Bounded_Product_Divide (Value => G, Factor => Draw_Size, Denominator => Asset.Grid))));
         function PY (G : Natural) return Float is
           (Float (Saturating_Add
              (Y, Bounded_Product_Divide (Value => G, Factor => Draw_Size, Denominator => Asset.Grid))));
      begin
         Add_Triangle
           (PX (Tri.X1), PY (Tri.Y1), PX (Tri.X2), PY (Tri.Y2), PX (Tri.X3), PY (Tri.Y3),
            Asset_Color (Tri.Role));
      end Add_Asset_Tri;

      function Add_Named_Asset (Name : String) return Boolean is
         Asset : constant Icon_Asset := Parsed_Icon_Asset (Name, Icon_Theme_Name);
      begin
         if not Asset.Valid then
            return False;
         end if;

         for Rect of Asset.Rectangles loop
            Add_Asset_Rect (Asset, Rect);
         end loop;
         for Tri of Asset.Triangles loop
            Add_Asset_Tri (Asset, Tri);
         end loop;
         return True;
      end Add_Named_Asset;

      --  In large-icon view, draw the file extension as a small index tab in the
      --  icon's bottom-right corner (a prerendered bitmap on the overlay layer).
      --  Only in large-icon view (where Use_Thumbnail is set); skipped for folders
      --  and extensionless names.
      procedure Add_Extension_Badge is
         Ext : constant String := Files.File_Types.Extension_Of (To_String (Item.Name), Dotfiles => True);
      begin
         if Ext = ""
           or else not Use_Thumbnail
           or else Item.Kind = Files.Types.Directory_Item
         then
            return;
         end if;
         declare
            Text_H   : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 3) / 4);
            Pad_Y    : constant Natural := Natural'Max (1, Line_Height / 8);
            Pad_X    : constant Natural := Pad_Y + 1;
            --  Three display cells, cut at a character boundary: a byte
            --  slice split a multibyte extension (.док) into invalid UTF-8.
            Shown    : constant String := Files.UTF8.Prefix_By_Units (Ext, 3);
            Lbl      : constant Files.Extension_Labels.Label :=
              Files.Extension_Labels.Label_For (Shown, Text_H, Snapshot.Theme_Palette);
            Band_W   : constant Natural := Saturating_Add (Lbl.Width, 2 * Pad_X);
            Band_H   : constant Natural := Saturating_Add (Lbl.Height, 2 * Pad_Y);
            Overhang : constant Natural := Band_W / 3;
            Main_Right : constant Natural :=
              Natural'Min
                (Layout.Width, Saturating_Add (Layout.Main_X, Layout.Main_Width));
            Main_Bottom : constant Natural :=
              Natural'Min
                (Layout.Height, Saturating_Add (Layout.Main_Y, Layout.Main_Height));
         begin
            if Lbl.Width > 0
              and then Band_W <= Layout.Main_Width
              and then Band_H <= Layout.Main_Height
            then
               declare
                  Raw_X : constant Natural :=
                    Saturating_Add
                      (X,
                       (if Draw_Size + Overhang > Band_W
                        then Draw_Size + Overhang - Band_W
                        else 0));
                  Raw_Y : constant Natural :=
                    Saturating_Add
                      (Y, (if Draw_Size > Band_H then Draw_Size - Band_H else 0));
                  Band_X : constant Natural :=
                    Natural'Max
                      (Layout.Main_X, Natural'Min (Raw_X, Main_Right - Band_W));
                  Band_Y : constant Natural :=
                    Natural'Max
                      (Layout.Main_Y, Natural'Min (Raw_Y, Main_Bottom - Band_H));
                  Text_X : constant Natural := Saturating_Add (Band_X, Pad_X);
                  Text_Y : constant Natural := Saturating_Add (Band_Y, Pad_Y);
               begin
               --  A small near-white index tab at the icon's bottom-right, drawn on
               --  the overlay layer so it sits on top of the opaque icon. It may
               --  overhang the icon, but is clamped to the main viewport so a
               --  compact last column cannot leak into the info or bottom pane.
                  Add_Overlay_Rect
                    (Band_X, Band_Y, Band_W, Band_H, Text_Color);
                  Result.Icons.Append
                    (Icon_Command'
                       (X                => Text_X,
                        Y                => Text_Y,
                        Size             => Lbl.Width,
                        Icon_Id          => To_Unbounded_String ("extlabel:" & Shown),
                        Theme_Name       => To_Unbounded_String (Icon_Theme_Name),
                        Thumbnail_Width  => Lbl.Width,
                        Thumbnail_Height => Lbl.Height,
                        Thumbnail_Pixels => Lbl.Pixels,
                        Overlay          => True,
                        Draw_Width       => Lbl.Width,
                        Draw_Height      => Lbl.Height,
                        others           => <>));
               end;
            end if;
         end;
      end Add_Extension_Badge;
   begin
      if Draw_Size = 0 then
         return;
      elsif Hidden_By_Settings_Pane (X, Y, Draw_Size, Draw_Size) then
         return;
      elsif Hidden_By_Command_Palette (X, Y, Draw_Size, Draw_Size) then
         return;
      end if;

      Add_Extension_Badge;

      --  An icon the vector layer can draw is drawn there, in the theme's
      --  colours (below). An atlas tile is for what it cannot: a thumbnail's
      --  pixels, and an overlay icon (a drag preview), which must sit above
      --  the base layer. Both at once painted every icon twice, the atlas's
      --  fixed colours over the theme's.
      if Overlay or else Thumbnail then
         declare
            --  A thumbnail keeps its proportions: fitted into the icon's
            --  square and centred in it, rather than stretched to fill it.
            Thumb_W : constant Natural := (if Use_Thumbnail then Item.Thumbnail_Width else 0);
            Thumb_H : constant Natural := (if Use_Thumbnail then Item.Thumbnail_Height else 0);
            Longest : constant Natural := Natural'Max (Thumb_W, Thumb_H);
            Fit_W   : constant Natural :=
              (if Longest = 0 or else Thumb_W = Thumb_H then 0
               else Positive'Max (1, Thumb_W * Draw_Size / Longest));
            Fit_H   : constant Natural :=
              (if Longest = 0 or else Thumb_W = Thumb_H then 0
               else Positive'Max (1, Thumb_H * Draw_Size / Longest));
         begin
            Result.Icons.Append
              (Icon_Command'
                 (X          => (if Fit_W > 0 then X + (Draw_Size - Fit_W) / 2 else X),
                  Y          => (if Fit_H > 0 then Y + (Draw_Size - Fit_H) / 2 else Y),
                  Size       => Draw_Size,
                  Icon_Id    =>
                    To_Unbounded_String (if Thumbnail then Files.File_Types.Thumbnail_Icon_Name else Icon_Name),
                  Theme_Name => To_Unbounded_String (Icon_Theme_Name),
                  Thumbnail_Width  => (if Use_Thumbnail then Item.Thumbnail_Width else 0),
                  Thumbnail_Height => (if Use_Thumbnail then Item.Thumbnail_Height else 0),
                  Thumbnail_Pixels =>
                    (if Use_Thumbnail then Item.Thumbnail.Pixels else Files.Shared_Bytes.Empty),
                  Overlay          => Overlay,
                  Draw_Width       => Fit_W,
                  Draw_Height      => Fit_H,
                  Base_Color       =>
                    Atlas_Base_Color (if Thumbnail then Files.File_Types.Thumbnail_Icon_Name else Icon_Name),
                  others           => <>));
         end;
      end if;

      --  Overlay icons are rasterized from the same asset, but must not
      --  also emit their vectors into the base rectangle/triangle layer or
      --  background content would paint over the drag preview.
      if Overlay then
         return;
      end if;

      if Thumbnail and then Add_Named_Asset (Files.File_Types.Thumbnail_Icon_Name) then
         return;
      elsif Add_Named_Asset (Icon_Name) then
         return;
      end if;

      --  No definition could be drawn (a broken .icon file): a plain shape
      --  for the same icon, so the item is never left without one.
      case Icon is
         when Files.File_Types.Folder_Icon =>
            Add_Rect
              (X,
               Y_Offset (Scale (1, 6)),
               Natural'Max (1, Scale (1, 2)),
               Natural'Max (1, Scale (1, 5)),
               Base_Color);
            Add_Rect (X, Body_Y, Draw_Size, Body_H, Base_Color);
            if Draw_Size > 4 then
               Add_Rect (X_Offset (1), Saturating_Add (Body_Y, 1), Draw_Size - 2, 1, Border_Color);
            end if;

         when Files.File_Types.Executable_Icon =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_Document_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            Add_Rect (X, Y, Stripe_W, Draw_Size, Accent);
            if Draw_Size > 6 then
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (1, 3)),
                  Stripe_W,
                  Scale (1, 3),
                  Accent);
               Add_Rect
                 (X_Offset (Saturating_Add (Scale (1, 2), Stripe_W)),
                  Y_Offset (Scale (1, 2)),
                  Stripe_W,
                  Stripe_W,
                  Accent);
            end if;

         when Files.File_Types.Link_Icon =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_Document_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            if Draw_Size > 5 then
               Add_Rect
                 (X_Offset (Scale (1, 5)),
                  Y_Offset (Scale (1, 2)),
                  Scale (1, 2),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (1, 3)),
                  Scale (1, 4),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
               Add_Rect
                 (X_Offset (Scale (1, 2)),
                  Y_Offset (Scale (2, 3)),
                  Scale (1, 4),
                  Natural'Max (1, Scale (1, 6)),
                  Selection_Color);
            end if;

         when Files.File_Types.Text_Icon | Files.File_Types.Markdown_Icon | Files.File_Types.Ada_Icon
            | Files.File_Types.Image_Icon | Files.File_Types.Unknown_Icon
         =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Base_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            if Draw_Size > 7 then
               if Icon = Files.File_Types.Image_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (3, 5),
                     Scale (1, 3),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 4)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 5),
                     Scale (1, 6),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 4),
                     Scale (1, 6),
                     Border_Color);
               elsif Icon = Files.File_Types.Ada_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Program_Color);
                  Add_Rect
                    (X_Offset (Scale (3, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Program_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 4)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 2),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
               elsif Icon = Files.File_Types.Markdown_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (2, 5)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 5),
                     Scale (1, 3),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (3, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Border_Color);
               elsif Icon = Files.File_Types.Unknown_Icon then
                  Add_Rect
                    (X_Offset (Scale (1, 3)),
                     Y_Offset (Scale (1, 4)),
                     Scale (1, 3),
                     Natural'Max (1, Scale (1, 6)),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Natural'Max (1, Scale (1, 6)),
                     Scale (1, 3),
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (3, 4)),
                     Natural'Max (1, Scale (1, 6)),
                     1,
                     Border_Color);
               else
                  Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 2)), Scale (3, 5), 1, Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Saturating_Add (Scale (1, 2), Scale (1, 5))),
                     Scale (1, 2),
                     1,
                     Border_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 2) - Scale (1, 5)),
                     Scale (1, 2),
                     1,
                     Border_Color);
               end if;
            end if;

      end case;
   end Add_Icon;
