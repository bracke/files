separate (Files.Rendering.Build_Frame_Commands)
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
   is
      Draw_W   : constant Natural := Clipped_Size (X, Text_W, Layout.Width);
      Draw_H   : constant Natural := Clipped_Size (Y, Text_H, Layout.Height);
      Cell_W   : constant Positive := Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
      Capacity : constant Natural := Draw_W / Cell_W;
      Fitted   : constant UString := (if Fit then Fitted_Text_For (Text, Capacity) else Text);
      Was_Truncated : constant Boolean := Fit and then Fitted /= Text;
   begin
      if Hidden_By_Settings_Pane (X, Y, Draw_W, Draw_H) then
         return;
      elsif Hidden_By_Command_Palette (X, Y, Draw_W, Draw_H) then
         return;
      end if;

      if Draw_W > 0 and then Draw_H > 0 and then Length (Fitted) > 0 then
         Result.Text.Append
           (Text_Command'
              (X      => X,
               Y      => Y,
               Width  => Draw_W,
               Height => Draw_H,
               Text   => Fitted,
               Color  => Color,
               Truncated => Was_Truncated,
               Scale_To_Box => Scale_To_Box,                  Italic => Italic));
      end if;
   end Add_Text;
