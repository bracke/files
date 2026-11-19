separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Triangle
     (X1    : Float;
      Y1    : Float;
      X2    : Float;
      Y2    : Float;
      X3    : Float;
      Y3    : Float;
      Color : Render_Color)
   is
   begin
      if Layout.Width = 0 or else Layout.Height = 0 then
         return;
      end if;

      --  Triangle commands have no clip rectangle in the draw protocol.
      --  Suppress a partially off-frame primitive instead of handing the
      --  backend coordinates outside its framebuffer; callers scale their
      --  geometry down first when a partial compact rendering is useful.
      if X1 < 0.0 or else X1 > Float (Layout.Width)
        or else X2 < 0.0 or else X2 > Float (Layout.Width)
        or else X3 < 0.0 or else X3 > Float (Layout.Width)
        or else Y1 < 0.0 or else Y1 > Float (Layout.Height)
        or else Y2 < 0.0 or else Y2 > Float (Layout.Height)
        or else Y3 < 0.0 or else Y3 > Float (Layout.Height)
      then
         return;
      end if;

      Result.Triangles.Append
        (Triangle_Command'
           (X1    => X1,
            Y1    => Y1,
            X2    => X2,
            Y2    => Y2,
            X3    => X3,
            Y3    => Y3,
            Color => Color));
   end Add_Triangle;
