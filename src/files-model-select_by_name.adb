separate (Files.Model)
   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Reset_Quick_Look (Model);
      if not Model.Items.Is_Empty then
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if To_String (Model.Items.Element (Index).Name) = Name
              and then Item_Is_Visible (Model, Model.Items.Element (Index))
            then
               Model.Selected_Item_Index := Natural (Index);
               Add_Selected_Index (Model, Model.Selected_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return True;
            end if;
         end loop;
      end if;

      Reconcile_Rename_With_Selection (Model);
      return False;
   end Select_By_Name;
