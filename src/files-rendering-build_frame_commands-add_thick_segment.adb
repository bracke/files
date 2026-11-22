separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Thick_Segment
     (X1    : Float;
      Y1    : Float;
      X2    : Float;
      Y2    : Float;
      Width : Float;
      Color : Render_Color)
   is
      DX  : constant Float := X2 - X1;
      DY  : constant Float := Y2 - Y1;
      Len : constant Float := Ada.Numerics.Elementary_Functions.Sqrt (DX * DX + DY * DY);
      NX  : constant Float := (if Len > 0.0 then -DY / Len * (Width / 2.0) else 0.0);
      NY  : constant Float := (if Len > 0.0 then DX / Len * (Width / 2.0) else 0.0);
   begin
      Add_Triangle (X1 + NX, Y1 + NY, X1 - NX, Y1 - NY, X2 - NX, Y2 - NY, Color);
      Add_Triangle (X1 + NX, Y1 + NY, X2 - NX, Y2 - NY, X2 + NX, Y2 + NY, Color);
   end Add_Thick_Segment;
