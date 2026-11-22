separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Dialog_Hit
     (Kind   : Dialog_Hit_Kind;
      X      : Natural;
      Y      : Natural;
      Hit_W  : Natural;
      Hit_H  : Natural)
   is
      Draw_W : constant Natural := Clipped_Size (X, Hit_W, Layout.Width);
      Draw_H : constant Natural := Clipped_Size (Y, Hit_H, Layout.Height);
   begin
      if Draw_W > 0 and then Draw_H > 0 then
         Result.Dialog_Hits.Append
           (Dialog_Hit_Region'
              (Kind   => Kind,
               X      => X,
               Y      => Y,
               Width  => Draw_W,
               Height => Draw_H));
      end if;
   end Add_Dialog_Hit;
