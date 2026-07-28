separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Icon
     (Item : Item_Snapshot;
      X    : Natural;
      Y    : Natural;
      Size : Natural;
      Use_Thumbnail : Boolean := False)
   is
      Base_Color : constant Render_Color := Icon_Color (Item.Kind);
      Type_Name  : constant String := To_String (Item.Filetype);
      Icon_Name  : constant String := To_String (Item.Icon_Id);
      Draw_Size  : constant Natural :=
        Natural'Min
          (Size,
           Natural'Min
             (Clipped_Size (X, Size, Layout.Width),
              Clipped_Size (Y, Size, Layout.Height)));
      Accent     : constant Render_Color :=
        (if Item.Kind = Files.Types.Executable_Item or else Icon_Name = "ada"
         then Icon_Executable_Color
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
         Asset : constant Icon_Asset := Parse_Icon_Asset (Icon_Asset_Text (Name, Icon_Theme_Name));
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

      function Starts_With
        (Value  : String;
         Prefix : String)
         return Boolean
      is
      begin
         return Value'Length >= Prefix'Length
           and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Resolved_Icon_Name return String is
      begin
         if Use_Thumbnail
           and then Item.Thumbnail_Available
           and then Length (Item.Thumbnail_Path) > 0
         then
            return "thumbnail";
         elsif Is_Bundled_Icon (Icon_Name) then
            return Icon_Name;
         elsif Item.Kind = Files.Types.Directory_Item then
            return "folder";
         elsif Item.Kind = Files.Types.Executable_Item then
            return "executable";
         elsif Item.Kind = Files.Types.Symlink_Item then
            return "link";
         elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
            return "image";
         elsif Type_Name = "text/markdown" then
            return "markdown";
         elsif Type_Name = "application/octet-stream" then
            return "unknown";
         elsif Starts_With (Type_Name, "text/") then
            return "text";
         else
            return "unknown";
         end if;
      end Resolved_Icon_Name;

      Resolved_Name : constant String := Resolved_Icon_Name;
      Resolved_Asset_Path : constant UString :=
        (if Use_Thumbnail
           and then Item.Thumbnail_Available
           and then Length (Item.Thumbnail_Path) > 0
         then Item.Thumbnail_Path
         else To_Unbounded_String (Icon_Asset_Directory & "/" & Resolved_Name & ".icon"));

      --  The lowercase extension of a filename (after the last dot), or "" for
      --  no extension, a dotfile (leading dot only), or a trailing dot.
      function Extension_Of (Name : String) return String is
         Dot : Natural := 0;
      begin
         for Position in reverse Name'Range loop
            if Name (Position) = '.' then
               Dot := Position;
               exit;
            end if;
         end loop;
         --  No dot at all (README, Makefile) has nothing to show; a trailing dot
         --  likewise. A leading dot (dotfiles like .gitignore, .env) is treated as
         --  a bare extension so those still get a tab.
         if Dot = 0 or else Dot = Name'Last then
            return "";
         end if;
         return Files.Types.To_Lower (Name (Dot + 1 .. Name'Last));
      end Extension_Of;

      --  In large-icon view, draw the file extension as a small index tab in the
      --  icon's bottom-right corner (a prerendered bitmap on the overlay layer).
      --  Only in large-icon view (where Use_Thumbnail is set); skipped for folders
      --  and extensionless names.
      procedure Add_Extension_Badge is
         Ext : constant String := Extension_Of (To_String (Item.Name));
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
            Shown    : constant String :=
              (if Ext'Length > 3 then Ext (Ext'First .. Ext'First + 2) else Ext);
            Lbl      : constant Files.Extension_Labels.Label :=
              Files.Extension_Labels.Label_For (Shown, Text_H, Snapshot.Theme_Palette);
            Band_W   : constant Natural := Saturating_Add (Lbl.Width, 2 * Pad_X);
            Band_H   : constant Natural := Saturating_Add (Lbl.Height, 2 * Pad_Y);
            Overhang : constant Natural := Band_W / 3;
            Band_X   : constant Natural :=
              Saturating_Add
                (X, (if Draw_Size + Overhang > Band_W then Draw_Size + Overhang - Band_W else 0));
            Band_Y   : constant Natural :=
              Saturating_Add (Y, (if Draw_Size > Band_H then Draw_Size - Band_H else 0));
            Text_X   : constant Natural := Saturating_Add (Band_X, Pad_X);
            Text_Y   : constant Natural := Saturating_Add (Band_Y, Pad_Y);
         begin
            if Lbl.Width > 0 then
               --  A small near-white index tab at the icon's bottom-right, drawn on
               --  the overlay layer so it sits on top of the opaque icon and allowed
               --  to stick out past the icon's right edge. The extension is a bitmap
               --  prerendered at this height (crisp small text, not downscaled),
               --  drawn 1:1 as an overlay image over a Text_Color background rect.
               Result.Overlay_Rectangles.Append
                 (Rectangle_Command'
                    (X      => Band_X,
                     Y      => Band_Y,
                     Width  => Band_W,
                     Height => Band_H,
                     Color  => Text_Color));
               Result.Icons.Append
                 (Icon_Command'
                    (X                => Text_X,
                     Y                => Text_Y,
                     Size             => Lbl.Width,
                     Icon_Id          => To_Unbounded_String ("extlabel:" & Shown),
                     Theme_Name       => Snapshot.Theme_Name,
                     Asset_Path       => Null_Unbounded_String,
                     Thumbnail_Width  => Lbl.Width,
                     Thumbnail_Height => Lbl.Height,
                     Thumbnail_Pixels => Lbl.Pixels,
                     Overlay          => True,
                     Draw_Width       => Lbl.Width,
                     Draw_Height      => Lbl.Height));
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

      Result.Icons.Append
        (Icon_Command'
           (X          => X,
            Y          => Y,
            Size       => Draw_Size,
            Icon_Id    => To_Unbounded_String (Resolved_Name),
            Theme_Name => To_Unbounded_String (Icon_Theme_Name),
            Asset_Path => Resolved_Asset_Path,
            Thumbnail_Width  => (if Use_Thumbnail then Item.Thumbnail_Width else 0),
            Thumbnail_Height => (if Use_Thumbnail then Item.Thumbnail_Height else 0),
            Thumbnail_Pixels =>
              (if Use_Thumbnail then Item.Thumbnail.Pixels else Files.Types.Byte_Vectors.Empty_Vector),
            Overlay          => False,
            Draw_Width       => 0,
            Draw_Height      => 0));

      if Use_Thumbnail
        and then Item.Thumbnail_Available
        and then Length (Item.Thumbnail_Path) > 0
        and then Add_Named_Asset ("thumbnail")
      then
         return;
      elsif Add_Named_Asset (Icon_Name) then
         return;
      elsif Item.Kind = Files.Types.Directory_Item and then Add_Named_Asset ("folder") then
         return;
      elsif Item.Kind = Files.Types.Executable_Item and then Add_Named_Asset ("executable") then
         return;
      elsif Item.Kind = Files.Types.Symlink_Item and then Add_Named_Asset ("link") then
         return;
      elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
         if Add_Named_Asset ("image") then
            return;
         end if;
      elsif Type_Name = "text/markdown" then
         if Add_Named_Asset ("markdown") then
            return;
         end if;
      elsif Type_Name = "application/octet-stream" then
         if Add_Named_Asset ("unknown") then
            return;
         end if;
      elsif Starts_With (Type_Name, "text/") then
         if Add_Named_Asset ("text") then
            return;
         end if;
      end if;

      case Item.Kind is
         when Files.Types.Directory_Item =>
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

         when Files.Types.Executable_Item =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
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

         when Files.Types.Symlink_Item =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
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

         when Files.Types.Regular_File_Item | Files.Types.Other_Item =>
            Add_Rect (X, Y, Draw_Size, Draw_Size, Base_Color);
            Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
            if Draw_Size > 7 then
               if Icon_Name = "image"
                 or else Starts_With (Type_Name, "image/")
               then
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
               elsif Icon_Name = "ada" or else Type_Name = "text/x-ada" then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Executable_Color);
                  Add_Rect
                    (X_Offset (Scale (3, 5)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 5),
                     Scale (1, 2),
                     Icon_Executable_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 4)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 2),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
               elsif Icon_Name = "markdown" or else Type_Name = "text/markdown" then
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
               elsif Icon_Name = "unknown" or else Type_Name = "application/octet-stream" then
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

         when Files.Types.Unknown_Item =>
            Add_Rect (X_Offset (Scale (1, 4)), Y, Scale (1, 2), Draw_Size, Base_Color);
            Add_Rect (X, Y_Offset (Scale (1, 4)), Draw_Size, Scale (1, 2), Base_Color);
            if Draw_Size > 5 then
               Add_Rect (X_Offset (Scale (1, 2)), Y_Offset (Scale (1, 4)), 1, Scale (1, 2), Border_Color);
            end if;
      end case;
   end Add_Icon;
