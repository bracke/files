with Interfaces.C;
with Interfaces;
with System;

package body Glfw.Windows.Icon is
   type GLFW_Image is record
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int;
      Pixels : System.Address;
   end record
   with Convention => C;

   type GLFW_Image_Array is array (Positive range <>) of GLFW_Image
   with Convention => C;

   type RGBA_Pixels is array (Positive range <>) of aliased Interfaces.Unsigned_8
   with Convention => C;

   procedure Raw_Set_Window_Icon
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Images : System.Address)
   with Import, Convention => C, External_Name => "glfwSetWindowIcon";

   procedure Put_Pixel
     (Pixels : in out RGBA_Pixels;
      X      : Natural;
      Y      : Natural;
      R      : Interfaces.Unsigned_8;
      G      : Interfaces.Unsigned_8;
      B      : Interfaces.Unsigned_8;
      A      : Interfaces.Unsigned_8 := 255)
   is
      Index : constant Positive := Positive ((Y * 32 + X) * 4 + 1);
   begin
      Pixels (Index) := R;
      Pixels (Index + 1) := G;
      Pixels (Index + 2) := B;
      Pixels (Index + 3) := A;
   end Put_Pixel;

   procedure Fill_Rect
     (Pixels : in out RGBA_Pixels;
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
            Put_Pixel (Pixels, Col, Row, R, G, B);
         end loop;
      end loop;
   end Fill_Rect;

   procedure Set_Files_Icon
     (Window : not null access Glfw.Windows.Window)
   is
      Pixels : aliased RGBA_Pixels (1 .. 32 * 32 * 4) := [others => 0];
      Images : aliased GLFW_Image_Array (1 .. 1);
   begin
      Fill_Rect (Pixels, 4, 9, 11, 5, 45, 125, 210);
      Fill_Rect (Pixels, 12, 11, 16, 4, 45, 125, 210);
      Fill_Rect (Pixels, 3, 13, 26, 16, 47, 142, 229);
      Fill_Rect (Pixels, 5, 17, 22, 10, 74, 163, 223);
      Fill_Rect (Pixels, 5, 14, 23, 3, 98, 183, 240);
      Fill_Rect (Pixels, 6, 18, 20, 2, 185, 226, 255);

      Images (1) :=
        (Width  => 32,
         Height => 32,
         Pixels => Pixels (Pixels'First)'Address);
      Raw_Set_Window_Icon (Window.Handle, 1, Images'Address);
   end Set_Files_Icon;

end Glfw.Windows.Icon;
