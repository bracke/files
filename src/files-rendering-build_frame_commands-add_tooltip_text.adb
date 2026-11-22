separate (Files.Rendering.Build_Frame_Commands)
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
