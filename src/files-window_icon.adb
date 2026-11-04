with Interfaces;
with Glfw.Windows.Icon;

package body Files.Window_Icon is

   Side : constant := 32;

   procedure Fill_Rect
     (Pixels : in out Glfw.Windows.Icon.RGBA_Pixels;
      X      : Natural;
      Y      : Natural;
      W      : Natural;
      H      : Natural;
      R      : Interfaces.Unsigned_8;
      G      : Interfaces.Unsigned_8;
      B      : Interfaces.Unsigned_8)
   is
   begin
      for Row in Y .. Y + H - 1 loop
         for Col in X .. X + W - 1 loop
            declare
               Index : constant Positive := (Row * Side + Col) * 4 + 1;
            begin
               Pixels (Index) := R;
               Pixels (Index + 1) := G;
               Pixels (Index + 2) := B;
               Pixels (Index + 3) := 255;
            end;
         end loop;
      end loop;
   end Fill_Rect;

   procedure Set (Window : not null access Glfw.Windows.Window) is
      Pixels : Glfw.Windows.Icon.RGBA_Pixels (1 .. Side * Side * 4) := [others => 0];
   begin
      Fill_Rect (Pixels, 4, 9, 11, 5, 45, 125, 210);
      Fill_Rect (Pixels, 12, 11, 16, 4, 45, 125, 210);
      Fill_Rect (Pixels, 3, 13, 26, 16, 47, 142, 229);
      Fill_Rect (Pixels, 5, 17, 22, 10, 74, 163, 223);
      Fill_Rect (Pixels, 5, 14, 23, 3, 98, 183, 240);
      Fill_Rect (Pixels, 6, 18, 20, 2, 185, 226, 255);
      Glfw.Windows.Icon.Set_Icon (Window, Pixels, Side, Side);
   end Set;

end Files.Window_Icon;
