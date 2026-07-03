with Ada.Strings.Unbounded;

package body Files.Gui.Widgets is

   use Files.Gui.Draw;

   --  Saturating sum: never overflows past Natural'Last.
   function Saturating_Add (Left : Natural; Right : Natural) return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   --  Clip a run starting at Start with the given Size to Limit, mirroring the
   --  renderer: fully off-screen or empty runs clip to zero.
   function Clipped_Size
     (Start : Natural;
      Size  : Natural;
      Limit : Natural)
      return Natural is
   begin
      if Start >= Limit or else Size = 0 then
         return 0;
      else
         return Natural'Min (Size, Limit - Start);
      end if;
   end Clipped_Size;

   --  Append one rectangle, clipped to the window bounds and dropped when empty.
   procedure Add_Clipped_Rect
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color)
   is
      Draw_W : constant Natural := Clipped_Size (X, Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Y, Height, Clip_Height);
   begin
      if Draw_W > 0 and then Draw_H > 0 then
         Rectangles.Append
           (Rectangle_Command'
              (X      => X,
               Y      => Y,
               Width  => Draw_W,
               Height => Draw_H,
               Color  => Color));
      end if;
   end Add_Clipped_Rect;

   --  Append a one-pixel border (top, left, bottom, right) around a box.
   procedure Add_Border
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color) is
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, 1, Color);
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, 1, Height, Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, X, Saturating_Add (Y, Height - 1), Width, 1, Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Saturating_Add (X, Width - 1), Y, 1, Height, Color);
   end Add_Border;

   procedure Draw_Focus_Ring
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color) is
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Color);
      if X > 0 and then Y > 0 then
         Add_Border
           (Rectangles,
            Clip_Width,
            Clip_Height,
            X - 1,
            Y - 1,
            Saturating_Add (Width, 2),
            Saturating_Add (Height, 2),
            Color);
      end if;
   end Draw_Focus_Ring;

   procedure Draw_Drop_Shadow
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color)
   is
      Shadow_Offset : constant Natural := 3;
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Clipped_Rect
        (Rectangles,
         Clip_Width,
         Clip_Height,
         Saturating_Add (X, Shadow_Offset),
         Saturating_Add (Y, Height),
         Width,
         Shadow_Offset,
         Color);
      Add_Clipped_Rect
        (Rectangles,
         Clip_Width,
         Clip_Height,
         Saturating_Add (X, Width),
         Saturating_Add (Y, Shadow_Offset),
         Shadow_Offset,
         Height,
         Color);
   end Draw_Drop_Shadow;

   procedure Draw_Close_Button
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Button_X      : Natural;
      Button_Y      : Natural;
      Button_Width  : Natural;
      Button_Height : Natural;
      Fill_Color    : Render_Color;
      Border_Color  : Render_Color;
      Glyph_X       : Natural;
      Glyph_Y       : Natural;
      Glyph_Width   : Natural;
      Glyph_Height  : Natural;
      Glyph         : UString;
      Glyph_Color   : Render_Color;
      Show_Glyph    : Boolean)
   is
      Draw_W : constant Natural := Clipped_Size (Glyph_X, Glyph_Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Glyph_Y, Glyph_Height, Clip_Height);
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height,
         Button_X, Button_Y, Button_Width, Button_Height, Fill_Color);
      Add_Border
        (Rectangles, Clip_Width, Clip_Height,
         Button_X, Button_Y, Button_Width, Button_Height, Border_Color);

      if Show_Glyph
        and then Draw_W > 0
        and then Draw_H > 0
        and then Ada.Strings.Unbounded.Length (Glyph) > 0
      then
         Text.Append
           (Text_Command'
              (X            => Glyph_X,
               Y            => Glyph_Y,
               Width        => Draw_W,
               Height       => Draw_H,
               Text         => Glyph,
               Color        => Glyph_Color,
               Truncated    => False,
               Scale_To_Box => False,
               Italic       => False));
      end if;
   end Draw_Close_Button;

end Files.Gui.Widgets;
