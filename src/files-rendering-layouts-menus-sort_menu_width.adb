separate (Files.Rendering.Layouts.Menus)
   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural
   is
      Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);

      function Label_W (Key : String) return Natural is
        (Guikit.Layout.Label_Pixel_Width
           (Files.Localization.Text (Key)
            & " "
            & Files.Localization.Text ("sort.direction.ascending"),
            Cell_W));

      Widest : Natural := 0;
   begin
      for Field in Files.Types.Sort_Field loop
         Widest := Natural'Max (Widest, Label_W (Files.Commands.Sort_Label_Key (Field)));
      end loop;
      --  Mirror the sort button's sizing (guikit Calculate_Bottom_Bar_Layout) but
      --  for the widest field, so the dropdown never clips a row.
      return
        Natural'Max
          (Guikit.Layout.Saturating_Multiply (Line_Height, 2),
           Guikit.Layout.Saturating_Add
             (Widest, Guikit.Layout.Saturating_Multiply (Field_Padding (Line_Height), 2)));
   end Sort_Menu_Width;
