separate (Files.Rendering)
   function Context_Menu_Row_Top
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural
   is
      Top : Natural := Saturating_Add (Menu.Y, Menu.Padding);
      First_Row : constant Positive :=
        (if Menu.Column_Count > 1 and then Row > Menu.Column_Break_Row
         then Positive (Menu.Column_Break_Row + 1)
         else 1);
   begin
      for Preceding in First_Row .. Row - 1 loop
         Top :=
           Saturating_Add
             (Top,
              (if Menu.Row_Kinds (Preceding) = Separator_Row
               then Menu.Separator_Height
               else Menu.Row_Height));
      end loop;
      return Top;
   end Context_Menu_Row_Top;
