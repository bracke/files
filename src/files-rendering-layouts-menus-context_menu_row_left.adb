separate (Files.Rendering.Layouts.Menus)
   function Context_Menu_Row_Left
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural is
   begin
      if Menu.Column_Count > 1 and then Row > Menu.Column_Break_Row then
         return Guikit.Layout.Saturating_Add (Menu.X, Menu.Column_Width);
      else
         return Menu.X;
      end if;
   end Context_Menu_Row_Left;
