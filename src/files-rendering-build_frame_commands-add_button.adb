separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Button
     (X        : Natural;
      Button_W : Natural;
      Selected : Boolean;
      Hovered  : Boolean := False;
      Pressed  : Boolean := False)
   is
      Button_Y : constant Natural :=
        (if Layout.Bottom_Bar_Height >= 1 then Bottom_Y + 1 else Bottom_Y);
      Button_H : constant Natural :=
        (if Layout.Bottom_Bar_Height >= 1 then Layout.Bottom_Bar_Height - 1
         else Layout.Bottom_Bar_Height);
   begin
      Add_Rect
        (X,
         Button_Y,
         Button_W,
         Button_H,
         (if Selected then Selection_Color
          elsif Pressed then Pressed_Color
          elsif Hovered then Hover_Color
          else Bottom_Bar_Color));
      if Selected then
         Add_Border (X, Button_Y, Button_W, Button_H, Border_Color);
      end if;
   end Add_Button;
