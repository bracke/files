with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

with Files.Grouping;
with Files.Settings_Form;

package body Files.Model.Support is

   use Ada.Strings.Unbounded;
   use type Files.Types.Focus_Target;
   use type Files.Types.Group_Mode;

   procedure Invalidate_Visible (Model : in out Window_Model) is
   begin
      Model.Visible_Cache_Valid := False;
   end Invalidate_Visible;

   --  The visible-row map, built when it was invalidated. The model is read
   --  as a constant by the lookups; the map is a cache of what it holds, so
   --  it is filled in through an unrestricted view (GNAT), as no reader can
   --  tell.
   procedure Ensure_Visible_Map (Model : Window_Model) is
      type Model_Access is access all Window_Model;
      Cache : constant Model_Access := Model'Unrestricted_Access;
      Seen  : Natural := 0;
   begin
      if Model.Visible_Cache_Valid then
         return;
      end if;
      Cache.Visible_Items.Clear;
      Cache.Item_Visible_Rows.Clear;
      Cache.Item_Visible_Rows.Reserve_Capacity (Model.Items.Length);
      Cache.Hidden_Items := 0;
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         declare
            Item : Files.Items.Directory_Item renames Model.Items (Index);
         begin
            if Item.Hidden or else (Length (Item.Name) > 0 and then Element (Item.Name, 1) = '.') then
               Cache.Hidden_Items := Cache.Hidden_Items + 1;
            end if;
         end;
         if Item_Is_Visible (Model, Model.Items (Index)) then
            Seen := Seen + 1;
            Cache.Visible_Items.Append (Index);
            Cache.Item_Visible_Rows.Append (Seen);
         else
            Cache.Item_Visible_Rows.Append (0);
         end if;
      end loop;
      Cache.Visible_Cache_Valid := True;
   end Ensure_Visible_Map;

   procedure Touch (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Rows_Revision_Value := Model.Rows_Revision_Value + 1;
   end Touch;

   procedure Touch_Selection (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Selection_Revision_Value := Model.Selection_Revision_Value + 1;
   end Touch_Selection;

   procedure Touch_Header (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
   end Touch_Header;

   procedure Reset_Quick_Look
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      Model.Quick_Look := (others => <>);
   end Reset_Quick_Look;

   function Scroll_Step (Lines : Integer) return Natural is
   begin
      if Lines = Integer'First then
         return Natural'Last;
      elsif Lines < 0 then
         return Natural (-Lines);
      else
         return Natural (Lines);
      end if;
   end Scroll_Step;

   procedure Reset_Rename_State
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Rename.Active := False;
      Model.Rename.Fields.Clear;
   end Reset_Rename_State;

   function Is_Temporary_Rename
     (Model : Window_Model)
      return Boolean is
   begin
      if not Model.Temporary.Active then
         return False;
      end if;

      for Field of Model.Rename.Fields loop
         if Field.Item_Index = 0 then
            return True;
         end if;
      end loop;

      return False;
   end Is_Temporary_Rename;

   procedure Clear_Root_Selector_State
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Root_Selector := (others => <>);
   end Clear_Root_Selector_State;

   function Item_Is_Visible
     (Model : Window_Model;
      Item  : Files.Items.Directory_Item)
      return Boolean
   is
   begin
      --  No filter (the common case): no copy of it, nor of the name.
      return Model.Search_Results_Active or else Length (Model.Filter.Text) = 0
        or else Files.Types.Contains_Case_Insensitive (To_String (Item.Name), To_String (Model.Filter.Text));
   end Item_Is_Visible;

   function Temporary_Is_Visible (Model : Window_Model) return Boolean is
   begin
      return Model.Temporary.Active;
   end Temporary_Is_Visible;

   function Temporary_Item (Model : Window_Model) return Files.Items.Directory_Item is
     (if Model.Temporary.Is_Directory
      then Files.File_System.Make_Item
        (Parent_Path => Current_Path (Model),
         Name        => To_String (Model.Temporary.Name),
         Kind        => Files.Types.Directory_Item)
      else Files.File_System.Make_Item
        (Parent_Path => Current_Path (Model),
         Name        => To_String (Model.Temporary.Name),
         Kind        => Files.Types.Regular_File_Item,
         Filetype    => "text/plain"));

   function Visible_To_Item_Index
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural is
   begin
      Ensure_Visible_Map (Model);
      return (if Visible_Index <= Natural (Model.Visible_Items.Length)
              then Model.Visible_Items (Visible_Index) else 0);
   end Visible_To_Item_Index;

   function Item_To_Visible_Index
     (Model      : Window_Model;
      Item_Index : Positive)
      return Natural is
   begin
      Ensure_Visible_Map (Model);
      return (if Item_Index <= Natural (Model.Item_Visible_Rows.Length)
              then Model.Item_Visible_Rows (Item_Index) else 0);
   end Item_To_Visible_Index;

   function Visible_Item_Count (Model : Window_Model) return Natural is
   begin
      Ensure_Visible_Map (Model);
      return Natural (Model.Visible_Items.Length);
   end Visible_Item_Count;

   function Selection_Contains
     (Model      : Window_Model;
      Item_Index : Natural)
      return Boolean
   is
   begin
      for Selected of Model.Selected_Item_Indexes loop
         if Selected = Item_Index then
            return True;
         end if;
      end loop;

      return False;
   end Selection_Contains;

   function Selected_Flags
     (Model : Window_Model)
      return Selection_Flags
   is
      Last  : constant Natural := Natural (Model.Items.Length);
      Flags : Selection_Flags (1 .. Last) := [others => False];
   begin
      for Selected of Model.Selected_Item_Indexes loop
         if Selected in 1 .. Last then
            Flags (Selected) := True;
         end if;
      end loop;
      return Flags;
   end Selected_Flags;

   procedure Add_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural)
   is
   begin
      Touch_Selection (Model);
      if Item_Index /= 0 and then not Selection_Contains (Model, Item_Index) then
         Model.Selected_Item_Indexes.Append (Item_Index);
      end if;
   end Add_Selected_Index;

   procedure Remove_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural)
   is
   begin
      Touch_Selection (Model);
      if not Model.Selected_Item_Indexes.Is_Empty then
         for Index in reverse Model.Selected_Item_Indexes.First_Index .. Model.Selected_Item_Indexes.Last_Index loop
            if Model.Selected_Item_Indexes.Element (Index) = Item_Index then
               Model.Selected_Item_Indexes.Delete (Index);
            end if;
         end loop;
      end if;
   end Remove_Selected_Index;

   function Effective_Selected_Item_Index (Model : Window_Model) return Natural is
   begin
      if Model.Selected_Item_Index /= 0 then
         return Model.Selected_Item_Index;
      elsif not Model.Selected_Item_Indexes.Is_Empty then
         return Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index);
      else
         return 0;
      end if;
   end Effective_Selected_Item_Index;

   procedure Reconcile_Rename_With_Selection (Model : in out Window_Model) is
   begin
      Touch_Selection (Model);
      if not Model.Rename.Active then
         return;
      end if;

      --  The temporary create item keeps its rename field until it is
      --  explicitly committed or cancelled, so leave it untouched here.
      if Model.Temporary.Active then
         return;
      end if;

      --  Drop the inline field for any item that is no longer selected. This
      --  keeps a synchronized multi-rename in step with the live selection.
      --  The selection as flags, read once: a scan of it per field made a
      --  click during rename-all of a large folder take most of a second.
      declare
         Selected : constant Selection_Flags := Selected_Flags (Model);
      begin
         for Index in reverse Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
            declare
               Item : constant Natural := Model.Rename.Fields.Element (Index).Item_Index;
            begin
               if Item not in Selected'Range or else not Selected (Item) then
                  --  A row's rename field goes: the rows change.
                  Touch (Model);
                  Model.Rename.Fields.Delete (Index);
               end if;
            end;
         end loop;
      end;

      if Model.Rename.Fields.Is_Empty then
         Model.Rename.Active := False;
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      end if;
   end Reconcile_Rename_With_Selection;

   procedure Reconcile_Selection (Model : in out Window_Model) is
   begin
      Touch_Selection (Model);
      if not Model.Selected_Item_Indexes.Is_Empty then
         for Index in reverse Model.Selected_Item_Indexes.First_Index .. Model.Selected_Item_Indexes.Last_Index loop
            declare
               Item_Index : constant Natural := Model.Selected_Item_Indexes.Element (Index);
            begin
               if Item_Index = Temporary_Item_Index then
                  if not Temporary_Is_Visible (Model) then
                     Model.Selected_Item_Indexes.Delete (Index);
                  end if;
               elsif Model.Items.Is_Empty
                 or else Item_Index > Natural (Model.Items.Last_Index)
                 or else not Item_Is_Visible (Model, Model.Items.Element (Positive (Item_Index)))
               then
                  Model.Selected_Item_Indexes.Delete (Index);
               end if;
            end;
         end loop;
      end if;

      if Model.Selected_Item_Index = Temporary_Item_Index then
         if Temporary_Is_Visible (Model) then
            Add_Selected_Index (Model, Temporary_Item_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;
      end if;

      if Model.Selected_Item_Index /= 0 then
         if not Model.Items.Is_Empty
           and then Model.Selected_Item_Index <= Natural (Model.Items.Last_Index)
           and then Item_Is_Visible (Model, Model.Items.Element (Positive (Model.Selected_Item_Index)))
         then
            Add_Selected_Index (Model, Model.Selected_Item_Index);
            Reconcile_Rename_With_Selection (Model);
            return;
         end if;
      end if;

      Model.Selected_Item_Index := 0;
      if not Model.Selected_Item_Indexes.Is_Empty then
         Model.Selected_Item_Index := Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index);
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      if not Model.Items.Is_Empty then
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Item_Is_Visible (Model, Model.Items (Index)) then
               Model.Selected_Item_Index := Natural (Index);
               Add_Selected_Index (Model, Model.Selected_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return;
            end if;
         end loop;
      end if;
      Reconcile_Rename_With_Selection (Model);
   end Reconcile_Selection;

   package Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Files.Types.Color_Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Files.Types."=");

   function Group_Labels_Map (Model : Window_Model) return Label_Maps.Map is
      Result : Label_Maps.Map;
   begin
      if Model.Grouping.Mode = Files.Types.Group_By_Label then
         for Entry_Value of Model.Grouping.Labels loop
            Result.Include (To_String (Entry_Value.Path), Entry_Value.Label);
         end loop;
      end if;
      return Result;
   end Group_Labels_Map;

   function Group_Band
     (Model  : Window_Model;
      Labels : Label_Maps.Map;
      Item   : Files.Items.Directory_Item)
      return Positive
   is
      Found : constant Label_Maps.Cursor := Labels.Find (To_String (Item.Full_Path));
   begin
      return Files.Grouping.Band_Of
        (Model.Grouping.Mode, Item.Kind, To_String (Item.Filetype),
         Item.Modified_Available, Item.Modified_Time, Item.Size_Available, Item.Size,
         (if Label_Maps.Has_Element (Found) then Label_Maps.Element (Found) else Files.Types.No_Label),
         Model.Grouping.Day);
   end Group_Band;

   function Items_In_Group_Order (Model : Window_Model) return Boolean is
      Labels   : Label_Maps.Map;
      Previous : Positive := 1;
   begin
      if Model.Grouping.Mode = Files.Types.No_Grouping then
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
      if Model.Grouping.Mode = Files.Types.No_Grouping then
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

   procedure Resort_Items (Model : in out Window_Model; Field_Sort : Boolean := True) is
      Previous_Selection : Files.Items.Item_Vectors.Vector;
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
      Touch (Model);
      for Item_Index of Model.Selected_Item_Indexes loop
         if Item_Index in 1 .. Natural (Model.Items.Last_Index) then
            Previous_Selection.Append (Model.Items.Element (Positive (Item_Index)));
         end if;
      end loop;
      if not Primary_Sentinel then
         Primary_Path := Path_At (Model.Selected_Item_Index);
      end if;

      --  Capture each rename field's item identity before the reorder. The
      --  temporary field (Item_Index = 0) records a null path sentinel so it
      --  can be preserved rather than remapped by identity.
      for Field of Model.Rename.Fields loop
         Rename_Old_Paths.Append (Path_At (Field.Item_Index));
      end loop;

      if Field_Sort then
         Files.File_System.Sort_Items
           (Model.Items,
            Model.Sort_Field_Value,
            Model.Sort_Ascending);
         Invalidate_Visible (Model);
      end if;
      Group_Items (Model);
      Sorted_Index.Reserve_Capacity (Model.Items.Length);
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         Sorted_Index.Include (To_String (Model.Items (Index).Full_Path), Index);
      end loop;

      declare
         --  The pending create row is selected through a marker, not an item
         --  index; keep it, or the row being named loses its highlight.
         Temporary_Selected : constant Boolean :=
           Model.Selected_Item_Indexes.Contains (Temporary_Item_Index);
      begin
         Model.Selected_Item_Indexes.Clear;
         for Item of Previous_Selection loop
            declare
               New_Index : constant Natural := Index_Of (Item.Full_Path);
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
               if Field.Item_Index = 0 then
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

   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
   end Clear_Overlay_State_For_Edit;

   function Focused_Field
     (Model : Window_Model)
      return Text_Field_State
   is
      --  A field edited as a whole value: the caret sits at its end.
      function At_End (Text : String) return Text_Field_State is
        ((Text => To_Unbounded_String (Text), Cursor => Text'Length));
   begin
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            return Model.Path_Input.Edit;
         when Files.Types.Focus_Filter_Input =>
            return Model.Filter;
         when Files.Types.Focus_Rename_Input =>
            return (if Model.Rename.Fields.Is_Empty then (others => <>) else Model.Rename.Fields.First_Element.Edit);
         when Files.Types.Focus_Command_Palette =>
            --  The palette query has no separate caret.
            return At_End (Guikit.Command_Palette.Query (Model.Command_Palette.View));
         when Files.Types.Focus_Settings_Input =>
            --  The panel edits whole values.
            return At_End (Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View));
         when Files.Types.Focus_Ownership_Input =>
            return Model.Ownership_Input.Edit;
         when Files.Types.Focus_None =>
            return (others => <>);
      end case;
   end Focused_Field;

   function Focused_Text_Value
     (Model : Window_Model)
      return String is
     (To_String (Focused_Field (Model).Text));

   procedure Reset_Settings_Panel (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Reset (Model.Settings_Panel_View);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Files.Settings_Form.Fields (Model));
   end Reset_Settings_Panel;

   function Find_Rename_Field
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural
   is
      Loaded : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
      Target : Natural;
   begin
      if Loaded = 0 then
         if Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model) then
            Target := 0;
         else
            return 0;
         end if;
      else
         Target := Loaded;
      end if;

      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         if Model.Rename.Fields.Element (Index).Item_Index = Target then
            return Index;
         end if;
      end loop;

      return 0;
   end Find_Rename_Field;

   procedure Begin_Create_Temporary
      (Model        : in out Window_Model;
       Name         : String;
       Is_Directory : Boolean) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Clear_Overlay_State_For_Edit (Model);
      Model.Temporary := (Active => True, Is_Directory => Is_Directory, Name => To_Unbounded_String (Name));
      Model.Rename.Fields.Clear;
      Model.Rename.Fields.Append
        (Rename_Field'
           (Item_Index => 0,
            Edit       => (Text => To_Unbounded_String (Name), Cursor => Name'Length)));
      Model.Rename.Active := True;
      Model.Main_View_Scroll := 0;
      Model.Selected_Item_Index := Temporary_Item_Index;
      Model.Selected_Item_Indexes.Clear;
      Add_Selected_Index (Model, Temporary_Item_Index);
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Begin_Create_Temporary;

   procedure Claim_Overlay_Input
     (Model : in out Window_Model) is
   begin
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Claim_Overlay_Input;

   procedure Close_Command_Palette
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Command_Palette.Open := False;
      Model.Command_Palette.Mode := Palette_Commands;
      Model.Command_Palette.Open_With_Targets.Clear;
      Model.Command_Palette.Open_With_Applications.Clear;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         --  Settings intentionally remains open beneath the palette.  Return
         --  keyboard focus to that revealed input surface when the palette
         --  closes instead of leaving the hidden file grid active.
         Model.Focus_Value :=
           (if Model.Settings_Pane_Open
            then Files.Types.Focus_Settings_Input
            else Files.Types.Focus_None);
      end if;
   end Close_Command_Palette;

   procedure Close_Root_Selector
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Clear_Root_Selector_State (Model);
   end Close_Root_Selector;

   procedure Close_Label_Picker
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Label_Picker := (others => <>);
   end Close_Label_Picker;

   procedure Close_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Sort_Menu := (others => <>);
   end Close_Sort_Menu;

   procedure Close_Context_Menu
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Context_Menu := (others => <>);
   end Close_Context_Menu;

   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Settings_Pane_Open := not Model.Settings_Pane_Open;
      if Model.Settings_Pane_Open then
         Claim_Overlay_Input (Model);
         Clear_Edit_State (Model);
         Clear_Root_Selector_State (Model);
         Model.Command_Palette.Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette.View);
         Reset_Settings_Panel (Model);
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      elsif Model.Focus_Value = Files.Types.Focus_Settings_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Toggle_Settings_Pane;

   function Released_Process return Files.Process_Jobs.Session is
      Idle : Files.Process_Jobs.Session;
   begin
      return Idle;
   end Released_Process;

   --  An idle folder-size session, to release a held one by assignment
   --  (the transfer and process ones are Support's).
   function Released_Scan return Files.Folder_Size.Session is
      Idle : Files.Folder_Size.Session;
   begin
      return Idle;
   end Released_Scan;

   procedure Reset_Type_Ahead
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Reset_Type_Ahead;

   function Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      if Model.Selected_Item_Index = Temporary_Item_Index then
         if Temporary_Is_Visible (Model) then
            return Visible_Count (Model);
         end if;

         return 0;
      end if;

      if Model.Selected_Item_Index = 0 then
         return 0;
      end if;

      return Item_To_Visible_Index (Model, Positive (Model.Selected_Item_Index));
   end Selected_Index;

   function Selected_Count
     (Model : Window_Model)
      return Natural is
   begin
      if not Model.Selected_Item_Indexes.Is_Empty then
         return Natural (Model.Selected_Item_Indexes.Length);
      elsif Selected_Index (Model) /= 0 then
         return 1;
      else
         return 0;
      end if;
   end Selected_Count;

   function Selected_Item
     (Model : Window_Model)
      return Files.Items.Directory_Item
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      elsif Item_Index = Temporary_Item_Index then
         return Temporary_Item (Model);
      end if;

      return Model.Items.Element (Positive (Item_Index));
   end Selected_Item;

   function Selected_Items
     (Model : Window_Model;
      Limit : Natural := Natural'Last)
      return Files.Items.Item_Vectors.Vector
   is
      Result : Files.Items.Item_Vectors.Vector;
   begin
      if Selected_Count (Model) = 0 or else Model.Items.Is_Empty then
         return Result;
      end if;

      declare
         Selected : constant Selection_Flags := Selected_Flags (Model);
      begin
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            exit when Natural (Result.Length) >= Limit;
            if Selected (Index) then
               Result.Append (Model.Items (Index));
            end if;
         end loop;
      end;

      return Result;
   end Selected_Items;

   procedure Restore_Selection
     (Model        : in out Window_Model;
      Items        : Files.Items.Item_Vectors.Vector;
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
      Touch_Selection (Model);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Reset_Quick_Look (Model);

      Previous_Paths.Reserve_Capacity (Items.Length);
      for Previous of Items loop
         Previous_Paths.Include (To_String (Previous.Full_Path));
      end loop;

      if not Model.Items.Is_Empty and then not Previous_Paths.Is_Empty then
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            declare
               --  Read in place: Element copied the whole item, three times.
               Item : Files.Items.Directory_Item renames Model.Items (Index);
               Path : constant String := To_String (Item.Full_Path);
            begin
               if Item_Is_Visible (Model, Item)
                 and then Previous_Paths.Contains (Path)
               then
                  --  Indexes ascend and the list was cleared above, so each is
                  --  new; appending directly avoids a linear duplicate check.
                  Model.Selected_Item_Indexes.Append (Natural (Index));
                  if First_Selected = 0 then
                     First_Selected := Natural (Index);
                  end if;
                  if Path = Primary_Path then
                     Primary_Selected := Natural (Index);
                  end if;
               end if;
            end;
         end loop;
      end if;

      Model.Selected_Item_Index :=
        (if Primary_Selected /= 0 then Primary_Selected else First_Selected);
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Restore_Selection;

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

   procedure Clear_Folder_Size
     (Model : in out Window_Model) is
   begin
      --  Released, not driven: a measurement still running is stopped by its
      --  last handle going.
      Model.Folder_Scan := Released_Scan;
      if not Model.Folder_Sizes.Is_Empty then
         Touch_Header (Model);
         Model.Folder_Sizes.Clear;
      end if;
   end Clear_Folder_Size;

end Files.Model.Support;
