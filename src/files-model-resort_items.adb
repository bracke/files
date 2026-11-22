with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Files.Grouping;
separate (Files.Model)
procedure Resort_Items
  (Model      : in out Window_Model;
   Field_Sort : Boolean := True;
   Recency    : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector)
is
   use type Files.Preference_Types.Group_Mode;

   --  Whether the items are already in band order.
   function Items_In_Group_Order (Model : Window_Model) return Boolean is
      Labels   : Label_Maps.Map;
      Previous : Positive := 1;
   begin
      if Model.Grouping.Mode = Files.Preference_Types.No_Grouping then
         return True;
      end if;
      Labels := Group_Labels_Map (Model);
      for Item of Model.Items loop
         declare
            Band : constant Positive := Group_Band (Model, Labels, Item);
         begin
            if Band < Previous then
               return False;
            end if;
            Previous := Band;
         end;
      end loop;
      return True;
   end Items_In_Group_Order;

   --  Stable partition of the items into their bands, keeping the sort order
   --  within each band.
   procedure Group_Items (Model : in out Window_Model) is
      Labels : Label_Maps.Map;
   begin
      if Model.Grouping.Mode = Files.Preference_Types.No_Grouping then
         return;
      end if;
      Labels := Group_Labels_Map (Model);
      declare
         Count : constant Positive := Files.Grouping.Band_Count (Model.Grouping.Mode);
         type Band_Array is array (1 .. Count) of Files.Items.Item_Vectors.Vector;
         Bands : Band_Array;
      begin
         for Item of Model.Items loop
            Bands (Group_Band (Model, Labels, Item)).Append (Item);
         end loop;
         Invalidate_Visible (Model);
         Model.Items.Clear;
         for Band of Bands loop
            Model.Items.Append (Band);
         end loop;
      end;
   end Group_Items;

   procedure Restore_Recency
     (Model   : in out Window_Model;
      Recency : Files.Types.String_Vectors.Vector)
   is
      package Position_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type        => String,
         Element_Type    => Positive,
         Hash            => Ada.Strings.Hash,
         Equivalent_Keys => "=");
      Position : Position_Maps.Map;
      Taken    : array (Model.Items.First_Index .. Model.Items.Last_Index) of Boolean := [others => False];
      Ordered  : Files.Items.Item_Vectors.Vector;
   begin
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         Position.Include (To_String (Model.Items (Index).Full_Path), Index);
      end loop;
      Ordered.Reserve_Capacity (Model.Items.Length);
      for Path of Recency loop
         declare
            Found : constant Position_Maps.Cursor := Position.Find (To_String (Path));
         begin
            if Position_Maps.Has_Element (Found) and then not Taken (Position_Maps.Element (Found)) then
               Taken (Position_Maps.Element (Found)) := True;
               Ordered.Append (Model.Items (Position_Maps.Element (Found)));
            end if;
         end;
      end loop;
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if not Taken (Index) then
            Ordered.Append (Model.Items (Index));
         end if;
      end loop;
      Invalidate_Visible (Model);
      Model.Items.Move (Ordered);
   end Restore_Recency;

   --  The selected items' paths: only the path finds an item again after
   --  the sort, so the items themselves are not copied.
   Previous_Selection : Files.Types.String_Vectors.Vector;
   Primary_Sentinel   : constant Boolean := Model.Selected_Item_Index = Temporary_Item_Index;
   Primary_Path       : Unbounded_String := Null_Unbounded_String;
   Rename_Old_Paths   : Files.Types.String_Vectors.Vector;

   function Path_At (Item_Index : Natural) return Unbounded_String is
   begin
      if Item_Index in 1 .. Natural (Model.Items.Last_Index) then
         return Model.Items.Element (Positive (Item_Index)).Full_Path;
      else
         return Null_Unbounded_String;
      end if;
   end Path_At;

   --  New index of each path after the sort, built once: a per-item scan
   --  made re-sorting a Select All quadratic.
   package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   Sorted_Index : Index_Maps.Map;

   function Index_Of (Path : Unbounded_String) return Natural is
      Found : constant Index_Maps.Cursor := Sorted_Index.Find (To_String (Path));
   begin
      if Path = Null_Unbounded_String or else not Index_Maps.Has_Element (Found) then
         return 0;
      end if;
      return Natural (Index_Maps.Element (Found));
   end Index_Of;
begin
   if not Field_Sort and then Recency.Is_Empty and then Items_In_Group_Order (Model) then
      return;
   end if;
   Touch (Model);
   for Item_Index of Model.Selected_Item_Indexes loop
      if Item_Index in 1 .. Natural (Model.Items.Last_Index) then
         Previous_Selection.Append (Model.Items (Positive (Item_Index)).Full_Path);
      end if;
   end loop;
   if not Primary_Sentinel then
      Primary_Path := Path_At (Model.Selected_Item_Index);
   end if;

   --  Capture each rename field's item identity before the reorder. The
   --  temporary field (Temporary_Item_Index) records a null path so it
   --  can be preserved rather than remapped by identity.
   for Field of Model.Rename.Fields loop
      Rename_Old_Paths.Append (Path_At (Field.Item_Index));
   end loop;

   if Field_Sort then
      Files.Item_Lists.Sort_Items
        (Model.Items,
         Model.Sort_Field_Value,
         Model.Sort_Ascending);
      Invalidate_Visible (Model);
   elsif not Recency.Is_Empty then
      Restore_Recency (Model, Recency);
   end if;
   Group_Items (Model);
   Sorted_Index.Reserve_Capacity (Model.Items.Length);
   for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
      Sorted_Index.Include (To_String (Model.Items (Index).Full_Path), Index);
   end loop;
   Model.Range_Anchor_Item := Index_Of (Model.Range_Anchor_Path);

   declare
      --  The pending create row is selected through a marker, not an item
      --  index; keep it, or the row being named loses its highlight.
      Temporary_Selected : constant Boolean :=
        Model.Selected_Item_Indexes.Contains (Temporary_Item_Index);
   begin
      Model.Selected_Item_Indexes.Clear;
      for Path of Previous_Selection loop
         declare
            New_Index : constant Natural := Index_Of (Path);
         begin
            if New_Index /= 0 then
               Model.Selected_Item_Indexes.Append (New_Index);
            end if;
         end;
      end loop;
      if Temporary_Selected then
         Model.Selected_Item_Indexes.Append (Temporary_Item_Index);
      end if;
   end;

   if not Primary_Sentinel then
      Model.Selected_Item_Index := Index_Of (Primary_Path);
   end if;

   --  Remap each rename field to its item's new index, preserving the
   --  temporary field and dropping fields whose item vanished.
   declare
      Rebuilt : Rename_Field_Vectors.Vector;
      Cursor  : Positive := Rename_Old_Paths.First_Index;
   begin
      for Field of Model.Rename.Fields loop
         declare
            Old_Path  : constant Unbounded_String := Rename_Old_Paths.Element (Cursor);
            New_Field : Rename_Field := Field;
         begin
            if Field.Item_Index = Temporary_Item_Index then
               Rebuilt.Append (Field);
            else
               declare
                  New_Index : constant Natural := Index_Of (Old_Path);
               begin
                  if New_Index /= 0 then
                     New_Field.Item_Index := New_Index;
                     Rebuilt.Append (New_Field);
                  end if;
               end;
            end if;
         end;
         Cursor := Cursor + 1;
      end loop;
      Model.Rename.Fields := Rebuilt;
   end;
end Resort_Items;
