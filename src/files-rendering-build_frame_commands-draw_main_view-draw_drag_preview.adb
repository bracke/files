separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  The dragged item's preview, an icon and name beside the pointer.
   procedure Draw_Drag_Preview is
   begin
      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         declare
            Item : Item_Snapshot renames Snapshot.Items (Positive (Index));
         begin
            if Item.Visible_Index = Drag_Item_Index then
               declare
                  --  The preview's chrome at the reference line height,
                  --  scaled with the text it is drawn beside.
                  Small_Pad    : constant Natural := Guikit.Layout.Scaled (8, Line_Height);
                  Large_Pad    : constant Natural := Guikit.Layout.Scaled (16, Line_Height);
                  Desired_Icon : constant Natural :=
                    Natural'Min
                      (Natural'Max (Line_Height, Guikit.Layout.Scaled (28, Line_Height)),
                       Guikit.Layout.Scaled (48, Line_Height));
                  Desired_H : constant Natural :=
                    Guikit.Layout.Saturating_Add (Desired_Icon, Large_Pad);
                  Panel_H   : constant Natural := Natural'Min (Desired_H, Height);
                  Panel_W   : constant Natural :=
                    Natural'Min
                      (Natural'Max
                         (Guikit.Layout.Saturating_Add
                            (Guikit.Layout.Saturating_Add (Desired_Icon, Small_Pad),
                             Saturating_Multiply (Line_Height, 8)),
                          Guikit.Layout.Saturating_Add (Desired_Icon, Large_Pad)),
                       Natural'Max (1, Width));
                  Offset    : constant Natural := Guikit.Layout.Scaled (14, Line_Height);
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
                  Pad       : constant Natural :=
                    Natural'Min (Small_Pad, Natural'Min (Panel_W / 4, Panel_H / 4));
                  Inner_W   : constant Natural :=
                    (if Panel_W > Saturating_Multiply (Pad, 2)
                     then Panel_W - Saturating_Multiply (Pad, 2)
                     else 0);
                  Inner_H   : constant Natural :=
                    (if Panel_H > Saturating_Multiply (Pad, 2)
                     then Panel_H - Saturating_Multiply (Pad, 2)
                     else 0);
                  Fitted_Icon : constant Natural := Natural'Min (Desired_Icon, Inner_H);
                  Icon_Size : constant Natural :=
                    (if Inner_W > Guikit.Layout.Saturating_Add (Fitted_Icon, Saturating_Multiply (Line_Height, 2))
                     then Fitted_Icon
                     else 0);
                  Gap       : constant Natural :=
                    (if Icon_Size > 0 then Natural'Min (Small_Pad, Inner_W - Icon_Size) else 0);
                  Icon_X    : constant Natural := Guikit.Layout.Saturating_Add (Panel_X, Pad);
                  Icon_Y    : constant Natural :=
                    Guikit.Layout.Saturating_Add
                      (Panel_Y,
                       Guikit.Layout.Saturating_Add
                         (Pad, Centered (Inner_H, Icon_Size)));
                  Text_X    : constant Natural :=
                    Guikit.Layout.Saturating_Add (Icon_X, Guikit.Layout.Saturating_Add (Icon_Size, Gap));
                  Text_W    : constant Natural :=
                    (if Inner_W > Guikit.Layout.Saturating_Add (Icon_Size, Gap)
                     then Inner_W - Icon_Size - Gap
                     else 0);
                  Text_H    : constant Natural := Natural'Min (Line_Height, Inner_H);
                  Text_Y    : constant Natural :=
                    Guikit.Layout.Saturating_Add
                      (Panel_Y, Guikit.Layout.Saturating_Add
                         (Pad, Centered (Inner_H, Text_H)));
               begin
                  Add_Overlay_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Hover_Color);
                  Add_Overlay_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Selection_Color);
                  Add_Icon (Item, Icon_X, Icon_Y, Icon_Size, Overlay => True);
                  Add_Overlay_Text
                    (Text_X, Text_Y, Text_W, Text_H, Item.Name, Fit => True);
               end;

               exit;
            end if;
         end;
      end loop;
   end Draw_Drag_Preview;
