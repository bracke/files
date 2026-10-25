with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
separate (Files.Model)
procedure Restore_Selection
  (Model        : in out Window_Model;
   Items        : Files.File_System.Item_Vectors.Vector;
   Primary_Path : String)
is
   --  Runs on every refresh, so a large Select All must stay linear:
   --  hash the previous paths once instead of rescanning them per item.
   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   First_Selected   : Natural := 0;
   Primary_Selected : Natural := 0;
   Previous_Paths   : Path_Sets.Set;
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Selected_Item_Index := 0;
   Model.Selected_Item_Indexes.Clear;
   Reset_Quick_Look (Model);

   Previous_Paths.Reserve_Capacity (Items.Length);
   for Previous of Items loop
      Previous_Paths.Include (To_String (Previous.Full_Path));
   end loop;

   if not Model.Items.Is_Empty and then not Previous_Paths.Is_Empty then
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index))
           and then Previous_Paths.Contains (To_String (Model.Items.Element (Index).Full_Path))
         then
            --  Indexes ascend and the list was cleared above, so each is
            --  new; appending directly avoids a linear duplicate check.
            Model.Selected_Item_Indexes.Append (Natural (Index));
            if First_Selected = 0 then
               First_Selected := Natural (Index);
            end if;
            if To_String (Model.Items.Element (Index).Full_Path) = Primary_Path then
               Primary_Selected := Natural (Index);
            end if;
         end if;
      end loop;
   end if;

   Model.Selected_Item_Index :=
     (if Primary_Selected /= 0 then Primary_Selected else First_Selected);
   Model.Info_Pane_Scroll := 0;
   Reconcile_Rename_With_Selection (Model);
end Restore_Selection;
