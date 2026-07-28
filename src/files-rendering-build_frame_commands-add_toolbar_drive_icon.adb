separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Toolbar_Drive_Icon
     (X       : Natural;
      Y       : Natural;
      Size    : Natural;
      Enabled : Boolean)
   is
      Color     : constant Render_Color := (if Enabled then Text_Color else Disabled_Text_Color);
      Bar_H     : constant Natural := Natural'Max (2, Size / 9);
      Bar_W     : constant Natural := Natural'Max (1, (Size * 2) / 3);
      Gap       : constant Natural := Natural'Max (2, Size / 7);
      Total_H   : constant Natural := Saturating_Add (Saturating_Multiply (Bar_H, 3), Saturating_Multiply (Gap, 2));
      Bar_X     : constant Natural := Saturating_Add (X, (if Size > Bar_W then (Size - Bar_W) / 2 else 0));
      First_Y   : constant Natural := Saturating_Add (Y, (if Size > Total_H then (Size - Total_H) / 2 else 0));

      procedure Add_Bar (Index : Natural) is
         Offset_Y : constant Natural := Saturating_Multiply (Index, Saturating_Add (Bar_H, Gap));
      begin
         Add_Rect (Bar_X, Saturating_Add (First_Y, Offset_Y), Bar_W, Bar_H, Color);
      end Add_Bar;
   begin
      if Size = 0 then
         return;
      end if;

      Add_Bar (0);
      Add_Bar (1);
      Add_Bar (2);
   end Add_Toolbar_Drive_Icon;
