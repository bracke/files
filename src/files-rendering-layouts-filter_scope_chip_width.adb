separate (Files.Rendering.Layouts)
   function Filter_Scope_Chip_Width
     (Line_Height : Positive)
      return Natural
   is
      Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);

      function Label_W (Key : String) return Natural is
      begin
         return Guikit.Layout.Label_Pixel_Width (Files.Localization.Text (Key), Cell_W);
      end Label_W;

      Widest : constant Natural :=
        Natural'Max
          (Label_W ("search.scope.here"),
           Natural'Max
             (Label_W ("search.scope.names"),
              Label_W ("search.scope.contents")));
   begin
      return Guikit.Layout.Saturating_Add (Widest, Guikit.Layout.Saturating_Multiply (Field_Padding (Line_Height), 2));
   end Filter_Scope_Chip_Width;
