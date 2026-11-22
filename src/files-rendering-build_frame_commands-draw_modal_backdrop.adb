separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Modal_Backdrop is
   begin
      Result.Accessibility.Clear;
      if Width > 0 and then Height > 0 then
         Result.Overlay_Rectangles.Append (Modal_Backdrop (Width, Height));
      end if;
   end Draw_Modal_Backdrop;
