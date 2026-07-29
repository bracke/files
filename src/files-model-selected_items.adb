separate (Files.Model)
   function Selected_Items
     (Model : Window_Model)
      return Files.File_System.Item_Vectors.Vector
   is
      Result : Files.File_System.Item_Vectors.Vector;
   begin
      if Selected_Count (Model) = 0 or else Model.Items.Is_Empty then
         return Result;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Selection_Contains (Model, Natural (Index)) then
            Result.Append (Model.Items.Element (Index));
         end if;
      end loop;

      return Result;
   end Selected_Items;
