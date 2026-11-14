separate (Files.Rendering.Build_Frame_Commands.Add_Icon)
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
         Shown    : constant String := Guikit.Utf8.Prefix_By_Units (Ext, 3);
         Lbl      : constant Files.Extension_Labels.Label :=
           Files.Extension_Labels.Label_For (Shown, Text_H, Snapshot.Theme_Palette);
         Band_W   : constant Natural := Guikit.Layout.Saturating_Add (Lbl.Width, 2 * Pad_X);
         Band_H   : constant Natural := Guikit.Layout.Saturating_Add (Lbl.Height, 2 * Pad_Y);
         Overhang : constant Natural := Band_W / 3;
         Main_Right : constant Natural :=
           Natural'Min
             (Layout.Width, Guikit.Layout.Saturating_Add (Layout.Main_X, Layout.Main_Width));
         Main_Bottom : constant Natural :=
           Natural'Min
             (Layout.Height, Guikit.Layout.Saturating_Add (Layout.Main_Y, Layout.Main_Height));
      begin
         if Lbl.Width > 0
           and then Band_W <= Layout.Main_Width
           and then Band_H <= Layout.Main_Height
         then
            declare
               Raw_X : constant Natural :=
                 Guikit.Layout.Saturating_Add
                   (X,
                    (if Draw_Size + Overhang > Band_W
                     then Draw_Size + Overhang - Band_W
                     else 0));
               Raw_Y : constant Natural :=
                 Guikit.Layout.Saturating_Add
                   (Y, (if Draw_Size > Band_H then Draw_Size - Band_H else 0));
               Band_X : constant Natural :=
                 Natural'Max
                   (Layout.Main_X, Natural'Min (Raw_X, Main_Right - Band_W));
               Band_Y : constant Natural :=
                 Natural'Max
                   (Layout.Main_Y, Natural'Min (Raw_Y, Main_Bottom - Band_H));
               Text_X : constant Natural := Guikit.Layout.Saturating_Add (Band_X, Pad_X);
               Text_Y : constant Natural := Guikit.Layout.Saturating_Add (Band_Y, Pad_Y);
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
