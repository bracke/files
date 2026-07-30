separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Toolbar_Asset_Icon
     (Id      : Files.Commands.Registered_Command_Id;
      X       : Natural;
      Y       : Natural;
      Size    : Natural;
      Enabled : Boolean)
   is
      Icon_Name : constant String :=
        (case Id is
           when Files.Commands.Navigate_Home_Command => "toolbar-home",
           when Files.Commands.Navigate_Back_Command => "toolbar-back",
           when Files.Commands.Navigate_Forward_Command => "toolbar-forward",
           when Files.Commands.Navigate_Parent_Command => "toolbar-parent",
           when Files.Commands.Create_File_Command => "toolbar-create",
           when Files.Commands.Delete_Selected_Items_Command => "toolbar-delete",
           when others => "unknown");
      Asset     : constant Icon_Asset := Parse_Icon_Asset (Icon_Asset_Text (Icon_Name, Icon_Theme_Name));
      Color     : constant Render_Color := (if Enabled then Text_Color else Disabled_Text_Color);

      function SX (Numerator : Natural) return Float is
      begin
         return Float (X) + Float (Size * Numerator) / 16.0;
      end SX;

      function SY (Numerator : Natural) return Float is
      begin
         return Float (Y) + Float (Size * Numerator) / 16.0;
      end SY;

      --  Draw an icon rectangle (in 16-grid units) as a pair of triangles at
      --  sub-pixel Float coordinates, so its edges land precisely and read as
      --  smoothly as the arrowhead triangles instead of snapping to whole
      --  pixels (which made the shafts and bodies look blocky).
      procedure Add_Local_Rect
        (Local_X : Natural;
         Local_Y : Natural;
         Local_W : Natural;
         Local_H : Natural)
      is
         X1 : constant Float := SX (Local_X);
         Y1 : constant Float := SY (Local_Y);
         X2 : constant Float := SX (Local_X + Local_W);
         Y2 : constant Float := SY (Local_Y + Local_H);
      begin
         Add_Triangle (X1, Y1, X2, Y1, X2, Y2, Color);
         Add_Triangle (X1, Y1, X2, Y2, X1, Y2, Color);
      end Add_Local_Rect;

      --  Bolder shapes (larger heads, thicker shafts) so the nav icons read
      --  with the same weight as the drawn favourite star.
      procedure Draw_Home is
      begin
         Add_Triangle (SX (2), SY (8), SX (8), SY (2), SX (14), SY (8), Color);
         Add_Local_Rect (4, 8, 8, 5);
         Add_Local_Rect (7, 10, 2, 3);
      end Draw_Home;

      procedure Draw_Back is
      begin
         Add_Triangle (SX (2), SY (8), SX (9), SY (2), SX (9), SY (14), Color);
         Add_Local_Rect (8, 6, 6, 4);
      end Draw_Back;

      procedure Draw_Forward is
      begin
         Add_Triangle (SX (14), SY (8), SX (7), SY (2), SX (7), SY (14), Color);
         Add_Local_Rect (2, 6, 6, 4);
      end Draw_Forward;

      procedure Draw_Parent is
      begin
         Add_Triangle (SX (8), SY (2), SX (2), SY (9), SX (14), SY (9), Color);
         Add_Local_Rect (6, 8, 4, 6);
      end Draw_Parent;

      procedure Draw_Create is
      begin
         Add_Local_Rect (7, 3, 2, 10);
         Add_Local_Rect (3, 7, 10, 2);
      end Draw_Create;

      procedure Draw_Delete is
      begin
         Add_Local_Rect (6, 3, 4, 1);
         Add_Local_Rect (4, 5, 8, 2);
         Add_Local_Rect (5, 7, 1, 6);
         Add_Local_Rect (10, 7, 1, 6);
         Add_Local_Rect (5, 12, 6, 1);
         Add_Local_Rect (7, 8, 1, 4);
         Add_Local_Rect (9, 8, 1, 4);
      end Draw_Delete;
   begin
      if Size = 0 then
         return;
      end if;

      Result.Icons.Append
        (Icon_Command'
           (X          => X,
            Y          => Y,
            Size       => Size,
            Icon_Id    => To_Unbounded_String (Icon_Name),
            Theme_Name => To_Unbounded_String (Icon_Theme_Name),
            Asset_Path => To_Unbounded_String ("share/files/icons/" & Icon_Name & ".icon"),
            Thumbnail_Width  => 0,
            Thumbnail_Height => 0,
            Thumbnail_Pixels => Files.Types.Byte_Vectors.Empty_Vector,
            Overlay          => False,
            Draw_Width       => 0,
            Draw_Height      => 0,
            others           => <>));

      if Id = Files.Commands.Navigate_Home_Command then
         Draw_Home;
      elsif Id = Files.Commands.Navigate_Back_Command then
         Draw_Back;
      elsif Id = Files.Commands.Navigate_Forward_Command then
         Draw_Forward;
      elsif Id = Files.Commands.Navigate_Parent_Command then
         Draw_Parent;
      elsif Id = Files.Commands.Create_File_Command then
         Draw_Create;
      elsif Id = Files.Commands.Delete_Selected_Items_Command then
         Draw_Delete;
      elsif Asset.Valid then
         for Rect of Asset.Rectangles loop
            Add_Local_Rect (Rect.Grid_X, Rect.Grid_Y, Rect.Grid_W, Rect.Grid_H);
         end loop;
      end if;
   end Add_Toolbar_Asset_Icon;
