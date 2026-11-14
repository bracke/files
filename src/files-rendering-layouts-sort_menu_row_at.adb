separate (Files.Rendering.Layouts)
   function Sort_Menu_Row_At
     (Menu : Sort_Menu_Layout;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      if Menu.Width = 0 or else not Guikit.Layout.Within (X, Menu.X, Menu.Width) then
         return 0;
      end if;
      for Row in 1 .. Menu.Row_Count loop
         if Guikit.Layout.Within (Y, Sort_Menu_Row_Top (Menu, Row), Menu.Row_Height) then
            return Row;
         end if;
      end loop;
      return 0;
   end Sort_Menu_Row_At;
