separate (Files.Rendering.Build_Frame_Commands.Draw_Popups)
   --  The Quick Look panel, drawn from its own part of the snapshot.
   procedure Draw_Quick_Look (Look : Quick_Look_Snapshot) is
      QL      : constant Quick_Look_Layout := Calculate_Quick_Look_Layout (Layout, Line_Height);
      Margin  : constant Natural := Natural'Max (Command_Palette_Padding (Line_Height), Line_Height / 2);
      Title_X : constant Natural := Guikit.Layout.Saturating_Add (QL.X, Margin);
      Title_Y : constant Natural :=
        Guikit.Layout.Saturating_Add (QL.Y, Guikit.Layout.Panel_Edge_Inset (Line_Height));
      --  The accent band along the panel's top edge.
      Accent_H : constant Natural := Natural'Min (Guikit.Layout.Scaled (3, Line_Height), QL.Height);
      Title_W : constant Natural :=
        (if QL.Width > Saturating_Multiply (Margin, 2)
         then QL.Width - Saturating_Multiply (Margin, 2) else QL.Width);
   begin
      --  Quick Look owns pointer and keyboard input while open.  Keep
      --  inactive file-view controls out of the accessibility frame;
      --  the dialog description identifies the item being previewed and
      --  updates as keyboard navigation changes the selection.
      Result.Accessibility.Clear;
      Add_Overlay_Drop_Shadow (QL.X, QL.Y, QL.Width, QL.Height);
      Add_Overlay_Rect (QL.X, QL.Y, QL.Width, QL.Height, Pane_Color);
      Add_Overlay_Border (QL.X, QL.Y, QL.Width, QL.Height, Border_Color);
      Add_Overlay_Rect (QL.X, QL.Y, QL.Width, Accent_H, Selection_Color);
      Add_Accessibility_Node
        (Role_Dialog, QL.X, QL.Y, QL.Width, QL.Height,
         Localized ("accessibility.quick_look"), Look.Name);
      --  Panel title: the previewed item's name, which also serves as the
      --  content marker tests assert on for every kind.
      Add_Overlay_Text (Title_X, Title_Y, Title_W, Line_Height, Look.Name, Fit => True);

      case Look.Kind is
         when Files.Quick_Look.Image_Content =>
            if not Guikit.Shared_Bytes.Is_Empty (Look.Image_Pixels)
              and then Look.Image_Width > 0
              and then Look.Image_Height > 0
            then
               declare
                  IW : constant Natural := Look.Image_Width;
                  IH : constant Natural := Look.Image_Height;
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
                    Guikit.Layout.Saturating_Add (QL.Content_X, Centered (CW, Draw_W));
                  Img_Y  : constant Natural :=
                    Guikit.Layout.Saturating_Add (QL.Content_Y, Centered (CH, Draw_H));
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
                           Icon_Id          =>
                             To_Unbounded_String (Files.File_Types.Icon_Name (Look.Icon)),
                           Theme_Name       => To_Unbounded_String (Icon_Theme_Name),
                           Thumbnail_Width  => IW,
                           Thumbnail_Height => IH,
                           Thumbnail_Pixels => Look.Image_Pixels,
                           Overlay          => True,
                           Draw_Width       => Draw_W,
                           Draw_Height      => Draw_H,
                           Base_Color       =>
                             Atlas_Base_Color (Files.File_Types.Icon_Name (Look.Icon)),
                           others           => <>));
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
               Source_Lines : constant Natural :=
                 Natural (Look.Text_Lines.Length);
               Content_Omitted : constant Boolean :=
                 Look.Text_Truncated or else Source_Lines > Max_Lines;
               Preview_Lines : constant Natural :=
                 (if Content_Omitted and then Max_Lines > 0
                  then Max_Lines - 1
                  else Max_Lines);
               Row       : Natural := 0;
            begin
               for Line of Look.Text_Lines loop
                  exit when Row >= Preview_Lines;
                  Add_Overlay_Text
                    (QL.Content_X,
                     Guikit.Layout.Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                     QL.Content_Width, Line_Height, Line, Fit => True);
                  Row := Row + 1;
               end loop;
               if Content_Omitted and then Max_Lines > 0 then
                  Add_Overlay_Text
                    (QL.Content_X,
                     Guikit.Layout.Saturating_Add (QL.Content_Y, Saturating_Multiply (Row, Line_Height)),
                     QL.Content_Width, Line_Height,
                     Localized ("quick_look.truncated"), Muted_Text_Color, Italic => True);
               end if;
            end;
         when Files.Quick_Look.Info_Content =>
            declare
               Text_Height : constant Natural := Saturating_Multiply (Line_Height, 2);
               Reserved_H  : constant Natural :=
                 Guikit.Layout.Saturating_Add (Margin, Text_Height);
               Icon_Height_Available : constant Natural :=
                 (if QL.Content_Height > Reserved_H
                  then QL.Content_Height - Reserved_H
                  else 0);
               Icon_Size : constant Natural :=
                 Natural'Min
                   (Saturating_Multiply (Line_Height, 3),
                    Natural'Min (QL.Content_Width, Icon_Height_Available));
               Content_End_Y : constant Natural :=
                 Guikit.Layout.Saturating_Add (QL.Content_Y, QL.Content_Height);
               Row_Y     : Natural :=
                 Guikit.Layout.Saturating_Add
                   (QL.Content_Y,
                    Guikit.Layout.Saturating_Add
                      (Icon_Size, (if Icon_Size > 0 then Margin else 0)));
               Size_Value : constant UString :=
                 (if Look.Size_Available
                  then To_Unbounded_String (Size_Text (Look.Size))
                  else Localized ("status.missing_metadata"));
            begin
               if Icon_Size > 0 then
                  Result.Icons.Append
                    (Icon_Command'
                       (X                => QL.Content_X,
                        Y                => QL.Content_Y,
                        Size             => Icon_Size,
                        Icon_Id          =>
                          To_Unbounded_String (Files.File_Types.Icon_Name (Look.Icon)),
                        Theme_Name       => To_Unbounded_String (Icon_Theme_Name),
                        Thumbnail_Width  => 0,
                        Thumbnail_Height => 0,
                        Thumbnail_Pixels => Guikit.Shared_Bytes.Empty,
                        Overlay          => True,
                        Draw_Width       => 0,
                        Draw_Height      => 0,
                        Base_Color       =>
                          Atlas_Base_Color (Files.File_Types.Icon_Name (Look.Icon)),
                        others           => <>));
               end if;
               if Row_Y < Content_End_Y then
                  Add_Overlay_Text
                    (QL.Content_X, Row_Y, QL.Content_Width,
                     Natural'Min (Line_Height, Content_End_Y - Row_Y),
                     Look.Filetype, Muted_Text_Color, Fit => True);
                  Row_Y := Guikit.Layout.Saturating_Add (Row_Y, Line_Height);
               end if;
               if Row_Y < Content_End_Y then
                  Add_Overlay_Text
                    (QL.Content_X, Row_Y, QL.Content_Width,
                     Natural'Min (Line_Height, Content_End_Y - Row_Y),
                     Size_Value, Muted_Text_Color, Fit => True);
               end if;
            end;
      end case;

      Draw_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, Overlay => True);
   end Draw_Quick_Look;
