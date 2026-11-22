separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Star_Fill
     (Center_X : Float;
      Center_Y : Float;
      Radius   : Float;
      Color    : Render_Color)
   is
   begin
      for K in Star_Rim'Range loop
         declare
            A : constant Star_Rim_Offset := Star_Rim (K);
            B : constant Star_Rim_Offset := Star_Rim ((K + 1) mod 10);
         begin
            Add_Triangle
              (Center_X, Center_Y,
               Center_X + A.DX * Radius, Center_Y + A.DY * Radius,
               Center_X + B.DX * Radius, Center_Y + B.DY * Radius,
               Color);
         end;
      end loop;
   end Add_Star_Fill;
