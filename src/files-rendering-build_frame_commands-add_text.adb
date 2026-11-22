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
      Italic : Boolean := False;
      Mirror_Glyph : Boolean := False;
      Cut_Columns  : Natural := Guikit.Draw.Auto_Cut) is
   begin
      Append_Text
        (Result.Text, X, Y, Text_W, Text_H, Text, Color, Fit, Scale_To_Box, Italic, Mirror_Glyph, Cut_Columns);
   end Add_Text;
