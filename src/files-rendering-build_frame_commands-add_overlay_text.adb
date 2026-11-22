separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Overlay_Text
     (X      : Natural;
      Y      : Natural;
      Text_W : Natural;
      Text_H : Natural;
      Text   : UString;
      Color  : Render_Color := Text_Color;
      Fit    : Boolean := False;
      Italic : Boolean := False) is
   begin
      Append_Text (Result.Overlay_Text, X, Y, Text_W, Text_H, Text, Color, Fit, False, Italic);
   end Add_Overlay_Text;
