separate (Files.Model)
function Select_By_Name
  (Model : in out Window_Model;
   Name  : String)
   return Boolean is
begin
   Touch_Selection (Model);
   Model.Selected_Item_Index := 0;
   Model.Selected_Item_Indexes.Clear;
   Model.Range_Anchor_Path := Null_Unbounded_String;
   Reset_Quick_Look (Model);
   if not Model.Items.Is_Empty then
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         --  Read in place: copying every item to compare its name cost more
         --  than the search after a reload of a large folder.
         if Model.Items (Index).Name = Name
           and then Item_Is_Visible (Model, Model.Items (Index))
         then
            Model.Selected_Item_Index := Natural (Index);
            Add_Selected_Index (Model, Model.Selected_Item_Index);
            Model.Range_Anchor_Path := Model.Items (Index).Full_Path;
            Reconcile_Rename_With_Selection (Model);
            return True;
         end if;
      end loop;
   end if;

   Reconcile_Rename_With_Selection (Model);
   return False;
end Select_By_Name;
