separate (Files.Model)
   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean is
   begin
      if not Temporary_Is_Visible (Model) then
         return False;
      elsif Model.Selected_Item_Index = Temporary_Item_Index then
         return True;
      end if;

      for Index of Model.Selected_Item_Indexes loop
         if Index = Temporary_Item_Index then
            return True;
         end if;
      end loop;

      return False;
   end Selection_Includes_Temporary;
