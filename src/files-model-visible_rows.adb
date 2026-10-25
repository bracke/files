with Ada.Containers.Ordered_Sets;
separate (Files.Model)
function Visible_Rows
  (Model : Window_Model)
   return Visible_Row_Vectors.Vector
is
   package Index_Sets is new Ada.Containers.Ordered_Sets (Element_Type => Natural);

   Filter   : constant String := To_String (Model.Filter_Value);
   Selected : Index_Sets.Set;
   Rows     : Visible_Row_Vectors.Vector;
begin
   for Item_Index of Model.Selected_Item_Indexes loop
      Selected.Include (Item_Index);
   end loop;

   if not Model.Items.Is_Empty then
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         declare
            --  Reference the element in place: .Element copied the whole
            --  Directory_Item (thumbnail pixels included) once for the filter
            --  test and Append copied it again. The reference tests the filter
            --  with no copy; only the retained Rows entry copies it.
            Item : Files.File_System.Directory_Item renames Model.Items (Index);
         begin
            --  Same test as Item_Is_Visible, which every index mapping
            --  (clicks, selection, rename) uses: search results show every
            --  hit, including content matches whose name lacks the query.
            if Model.Search_Results_Active
              or else Filter = ""
              or else Files.Types.Contains_Case_Insensitive (To_String (Item.Name), Filter)
            then
               Rows.Append
                 (Visible_Row'(Item_Index => Natural (Index),
                               Item     => Item,
                               Selected => Selected.Contains (Natural (Index))));
            end if;
         end;
      end loop;
   end if;

   if Temporary_Is_Visible (Model) then
      declare
         Temp : constant Files.File_System.Directory_Item :=
           (if Model.Temporary_Is_Directory then
               Files.File_System.Make_Item
                 (Parent_Path => Current_Path (Model),
                  Name        => To_String (Model.Temporary_Name_Value),
                  Kind        => Files.Types.Directory_Item)
            else
               Files.File_System.Make_Item
                 (Parent_Path => Current_Path (Model),
                  Name        => To_String (Model.Temporary_Name_Value),
                  Kind        => Files.Types.Regular_File_Item,
                  Filetype    => "text/plain"));
      begin
         Rows.Append
           (Visible_Row'(Item_Index => 0,
                         Item     => Temp,
                         Selected => Selected.Contains (Temporary_Item_Index)));
      end;
   end if;

   return Rows;
end Visible_Rows;
