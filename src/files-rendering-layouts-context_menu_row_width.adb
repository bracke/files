separate (Files.Rendering.Layouts)
   function Context_Menu_Row_Width
     (Menu : Context_Menu_Layout;
      Row  : Positive)
      return Natural is
   begin
      if Menu.Column_Count > 1 and then Row > Menu.Column_Break_Row then
         return
           (if Menu.Width > Menu.Column_Width
            then Menu.Width - Menu.Column_Width
            else 0);
      else
         return Menu.Column_Width;
      end if;
   end Context_Menu_Row_Width;
