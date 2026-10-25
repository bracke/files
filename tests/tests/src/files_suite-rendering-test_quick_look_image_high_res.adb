separate (Files_Suite.Rendering)
   procedure Test_Quick_Look_Image_High_Res (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      IW     : constant Natural  := 200;
      IH     : constant Natural  := 150;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Frame  : Frame_Commands;
      Found  : Boolean := False;
   begin
      Snap.Quick_Look_Open := True;
      Snap.Quick_Look_Kind := Files.Quick_Look.Image_Content;
      Snap.Quick_Look_Name := To_Unbounded_String ("photo.png");
      Snap.Quick_Look_Icon_Id := To_Unbounded_String ("image");
      Snap.Quick_Look_Image_Width := IW;
      Snap.Quick_Look_Image_Height := IH;
      for I in 1 .. IW * IH * 4 loop
         Snap.Quick_Look_Image_Pixels.Append (0);
      end loop;

      Frame := Build_Frame_Commands (Snap, Width, Height, LH);
      for Icon of Frame.Icons loop
         if Icon.Overlay and then Icon.Thumbnail_Width = IW and then Icon.Thumbnail_Height = IH then
            Found := True;
            Assert (Icon.Draw_Width > 0 and then Icon.Draw_Height > 0,
                    "the image preview draws at an explicit size");
            Assert (Icon.Draw_Width /= Icon.Draw_Height,
                    "the image preview draws non-square, preserving the 4:3 aspect");
         end if;
      end loop;
      Assert (Found,
              "the quick look image preview uses the full-resolution image, not the 64px thumbnail");
   end Test_Quick_Look_Image_High_Res;
