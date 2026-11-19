separate (Files.Rendering.Build_Frame_Commands.Draw_Bottom_Bar)
   --  The sort button: the sort field and its direction arrow.
   procedure Draw_Sort_Button is
      --  The open sort menu leaves its button the pointer (a click closes it).
      Live    : constant Boolean := Toggles_Topmost_Overlay (Files.Commands.Toggle_Sort_Menu_Command);
      Hovered : constant Boolean :=
        (Has_Hover or else (Live and then Pointer.Has_Hover))
        and then Contains_Point
          (Bottom.Sort_Button_X,
           Bottom_Y,
           Bottom.Sort_Button_Width,
           Layout.Bottom_Bar_Height,
           Hover_X,
           Hover_Y);
      Pressed : constant Boolean :=
        Is_Pressed (Bottom.Sort_Button_X, Bottom_Y, Bottom.Sort_Button_Width, Layout.Bottom_Bar_Height, Live);
   begin
      --  Open, it is drawn selected, but pressed while a click on it is held.
      Add_Button
        (Bottom.Sort_Button_X,
         Bottom.Sort_Button_Width,
         Snapshot.Sort_Menu_Open and then not Pressed,
         Hovered,
         Pressed);
      declare
         Field_Label : constant String := Sort_Field_Label (Snapshot.Sort_Field);
         Arrow_Text  : constant String := Direction_Text (Snapshot.Sort_Ascending);
         Cell_W      : constant Positive :=
           Guikit.Layout.Caret_Advance_Width (Line_Height);
         Label_W     : constant Natural :=
           Saturating_Multiply (Guikit.Utf8.Display_Units (Field_Label), Cell_W);
         --  Tighter than a full monospace space so the direction arrow sits
         --  close to the sort field it belongs to.
         Arrow_Gap   : constant Natural := Cell_W / 2;
         Arrow_W     : constant Natural :=
           Saturating_Multiply (Guikit.Utf8.Display_Units (Arrow_Text), Cell_W);
         --  Actual field + gap + arrow width drawn. The button is sized assuming
         --  a full space before the arrow, so it is a touch wider; centre the
         --  drawn content within the button rather than left-aligning it.
         Rendered_W  : constant Natural :=
           Guikit.Layout.Saturating_Add (Label_W, Guikit.Layout.Saturating_Add (Arrow_Gap, Arrow_W));
         Text_X0     : constant Natural :=
           Guikit.Layout.Saturating_Add
             (Bottom.Sort_Button_X,
              (if Bottom.Sort_Button_Width > Rendered_W
               then (Bottom.Sort_Button_Width - Rendered_W) / 2
               else Files.Rendering.Layouts.Field_Padding (Line_Height)));
         Content_W   : constant Natural :=
           (if Bottom.Sort_Button_Width > Saturating_Multiply (Files.Rendering.Layouts.Field_Padding (Line_Height), 2)
            then Bottom.Sort_Button_Width - Saturating_Multiply (Files.Rendering.Layouts.Field_Padding (Line_Height), 2)
            else 0);
         Arrow_X     : constant Natural :=
           Guikit.Layout.Saturating_Add (Text_X0, Guikit.Layout.Saturating_Add (Label_W, Arrow_Gap));
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
         if Content_W > Guikit.Layout.Saturating_Add (Label_W, Arrow_Gap) then
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
         Sort_Button_Label (Snapshot.Sort_Field, Snapshot.Sort_Ascending),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Sort_Menu_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Sort_Menu_Command),
         Selected => Snapshot.Sort_Menu_Open);
   end Draw_Sort_Button;
