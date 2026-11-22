separate (Files.Rendering.Layouts)
   function Details_Header_Height
     (Content_H   : Natural;
      Line_Height : Positive)
      return Natural is
   begin
      return
        Natural'Min
          (Guikit.Layout.Saturating_Add (Line_Height,
            Guikit.Layout.Saturating_Multiply (Details_Row_Padding (Line_Height), 2)),
           Content_H);
   end Details_Header_Height;
