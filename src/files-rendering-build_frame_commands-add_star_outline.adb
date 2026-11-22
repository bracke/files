separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Star_Outline
     (Center_X : Float;
      Center_Y : Float;
      Radius   : Float;
      Width    : Float;
      Color    : Render_Color)
   is
   begin
      for K in Star_Rim'Range loop
         declare
            A : constant Star_Rim_Offset := Star_Rim (K);
            B : constant Star_Rim_Offset := Star_Rim ((K + 1) mod 10);
         begin
            Add_Thick_Segment
              (Center_X + A.DX * Radius, Center_Y + A.DY * Radius,
               Center_X + B.DX * Radius, Center_Y + B.DY * Radius,
               Width, Color);
         end;
      end loop;
   end Add_Star_Outline;
