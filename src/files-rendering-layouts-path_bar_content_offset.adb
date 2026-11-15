separate (Files.Rendering.Layouts)
   function Path_Bar_Content_Offset
     (Width       : Natural;
      Line_Height : Positive)
      return Natural
   is
      Star : constant Path_Favorite_Star_Bounds :=
        Path_Favorite_Star_Region (Width, Line_Height);
   begin
      if not Star.Visible then
         return 0;
      end if;
      --  Star cell width plus one full character cell of separation so the
      --  breadcrumbs/edit text are clearly detached from the star.
      return Guikit.Layout.Saturating_Add (Star.Width, Guikit.Layout.Caret_Advance_Width (Line_Height));
   end Path_Bar_Content_Offset;
