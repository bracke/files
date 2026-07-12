with Ada.Calendar;
with Ada.Strings.Fixed;

with Files.Command_Palette;
with Files.Localization;
with Files.Settings_Form;
with Files.Type_Ahead;
with Files.UTF8;

package body Files.Model is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Search_Scope;

   Temporary_Item_Index : constant Natural := Natural'Last;

   --  Clear the Quick Look overlay state. Declared early so the navigation and
   --  selection resets below can close a stale preview when the previewed item
   --  is no longer the single, current selection.
   procedure Reset_Quick_Look
     (Model : in out Window_Model) is
   begin
      Model.Quick_Look_Active        := False;
      Model.Quick_Look_Path_Value    := Null_Unbounded_String;
      Model.Quick_Look_Content_Value := (others => <>);
   end Reset_Quick_Look;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

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

   function Previous_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Previous_Boundary (Text, Cursor);
   end Previous_Text_Boundary;

   function Next_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Next_Boundary (Text, Cursor);
   end Next_Text_Boundary;

   function Text_Boundary_At_Or_Before
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Boundary_At_Or_Before (Text, Cursor);
   end Text_Boundary_At_Or_Before;

   --  Remove the byte range [First, Last) from Text (offsets are clamped).
   function Remove_Text_Segment
     (Text        : String;
      First, Last : Natural)
      return String
   is
      Start_Index : constant Natural := Natural'Min (First, Text'Length);
      End_Index   : constant Natural := Natural'Min (Last, Text'Length);
      Result      : Unbounded_String;
   begin
      if Text = "" or else Start_Index >= End_Index then
         return Text;
      end if;

      if Start_Index > 0 then
         Append (Result, Text (Text'First .. Text'First + Start_Index - 1));
      end if;

      if End_Index < Text'Length then
         Append (Result, Text (Text'First + End_Index .. Text'Last));
      end if;

      return To_String (Result);
   end Remove_Text_Segment;

   --  Insert Text into Old at the byte offset Cursor.
   function Insert_Text_At
     (Old    : String;
      Cursor : Natural;
      Text   : String)
      return String is
   begin
      if Cursor = 0 then
         return Text & Old;
      elsif Cursor >= Old'Length then
         return Old & Text;
      else
         return Old (Old'First .. Old'First + Cursor - 1)
           & Text
           & Old (Old'First + Cursor .. Old'Last);
      end if;
   end Insert_Text_At;

   --  Return the byte offset before a name's extension: the position of the
   --  last non-leading dot, or the name length when there is no extension.
   function Caret_Before_Extension
     (Name : String)
      return Natural
   is
      Dot : Natural := 0;
   begin
      for Index in Name'Range loop
         if Name (Index) = '.' and then Index > Name'First then
            Dot := Index - Name'First;
         end if;
      end loop;

      if Dot = 0 then
         return Name'Length;
      else
         return Files.UTF8.Boundary_At_Or_Before (Name, Dot);
      end if;
   end Caret_Before_Extension;

   --  Deactivate rename mode and discard every inline rename field.
   procedure Reset_Rename_State
     (Model : in out Window_Model) is
   begin
      Model.Rename_Active := False;
      Model.Rename_Fields.Clear;
   end Reset_Rename_State;

   --  Return the first rename field's text, or an empty string when inactive.
   function First_Rename_Value
     (Model : Window_Model)
      return String is
   begin
      if Model.Rename_Fields.Is_Empty then
         return "";
      else
         return To_String (Model.Rename_Fields.First_Element.Value);
      end if;
   end First_Rename_Value;

   --  Return the first rename field's caret, or zero when inactive.
   function First_Rename_Cursor
     (Model : Window_Model)
      return Natural is
   begin
      if Model.Rename_Fields.Is_Empty then
         return 0;
      else
         return Model.Rename_Fields.First_Element.Cursor;
      end if;
   end First_Rename_Cursor;

   --  Return whether the active rename is the temporary create-item field.
   function Is_Temporary_Rename
     (Model : Window_Model)
      return Boolean is
   begin
      if not Model.Temporary_Active then
         return False;
      end if;

      for Field of Model.Rename_Fields loop
         if Field.Item_Index = 0 then
            return True;
         end if;
      end loop;

      return False;
   end Is_Temporary_Rename;

   --  Update the temporary-item name buffer to track its rename field's value.
   procedure Sync_Temporary_From_Field
     (Model : in out Window_Model;
      Field : Rename_Field) is
   begin
      if Field.Item_Index = 0 and then Model.Temporary_Active then
         Model.Temporary_Name_Value := Field.Value;
      end if;
   end Sync_Temporary_From_Field;

   procedure Clear_Root_Selector_State
     (Model : in out Window_Model) is
   begin
      Model.Root_Selector_Open := False;
      Model.Root_Entries.Clear;
      Model.Root_Selected := 0;
   end Clear_Root_Selector_State;

   function Pair_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural is
   begin
      return Natural'Min (Natural (Keys.Length), Natural (Values.Length));
   end Pair_Count;

   procedure Trim_To_Count
     (Values : in out Files.Types.String_Vectors.Vector;
      Count  : Natural) is
   begin
      while Natural (Values.Length) > Count loop
         Values.Delete (Natural (Values.Length));
      end loop;
   end Trim_To_Count;

   procedure Normalize_Settings_Draft
     (Draft : in out Files.Settings.Settings_Draft)
   is
      procedure Normalize_Pair
        (Keys          : in out Files.Types.String_Vectors.Vector;
         Values        : in out Files.Types.String_Vectors.Vector;
         Index         : in out Natural;
         Selected_Key   : out Unbounded_String;
         Selected_Value : out Unbounded_String)
      is
         Count : constant Natural := Pair_Count (Keys, Values);
      begin
         Trim_To_Count (Keys, Count);
         Trim_To_Count (Values, Count);
         if Count = 0 then
            Index := 0;
            Selected_Key := Null_Unbounded_String;
            Selected_Value := Null_Unbounded_String;
         else
            if Index = 0 or else Index > Count then
               Index := 1;
            end if;
            Selected_Key := Keys.Element (Index);
            Selected_Value := Values.Element (Index);
         end if;
      end Normalize_Pair;
   begin
      Normalize_Pair
        (Draft.Filetype_Keys,
         Draft.Filetype_Values,
         Draft.Filetype_Index,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Normalize_Pair
        (Draft.Icon_Keys,
         Draft.Icon_Values,
         Draft.Icon_Index,
         Draft.Icon_Filetype,
         Draft.Icon_Value);
      Normalize_Pair
        (Draft.Open_Action_Keys,
         Draft.Open_Action_Commands,
         Draft.Open_Action_Index,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);
   end Normalize_Settings_Draft;

   function Item_Is_Visible
     (Model : Window_Model;
      Item  : Files.File_System.Directory_Item)
      return Boolean
   is
      Filter : constant String := To_String (Model.Filter_Value);
   begin
      return Filter = ""
        or else Files.Types.Contains_Case_Insensitive (To_String (Item.Name), Filter);
   end Item_Is_Visible;

   function Temporary_Is_Visible (Model : Window_Model) return Boolean is
   begin
      return Model.Temporary_Active;
   end Temporary_Is_Visible;

   function Visible_To_Item_Index
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Natural
   is
      Seen : Natural := 0;
   begin
      if not Model.Items.Is_Empty then
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Item_Is_Visible (Model, Model.Items.Element (Index)) then
               Seen := Seen + 1;
               if Seen = Visible_Index then
                  return Natural (Index);
               end if;
            end if;
         end loop;
      end if;

      return 0;
   end Visible_To_Item_Index;

   function Item_To_Visible_Index
     (Model      : Window_Model;
      Item_Index : Positive)
      return Natural
   is
      Seen : Natural := 0;
   begin
      if Model.Items.Is_Empty or else Item_Index > Model.Items.Last_Index then
         return 0;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index)) then
            Seen := Seen + 1;
            if Index = Item_Index then
               return Seen;
            end if;
         end if;
      end loop;

      return 0;
   end Item_To_Visible_Index;

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

   procedure Add_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural)
   is
   begin
      if Item_Index /= 0 and then not Selection_Contains (Model, Item_Index) then
         Model.Selected_Item_Indexes.Append (Item_Index);
      end if;
   end Add_Selected_Index;

   procedure Remove_Selected_Index
     (Model      : in out Window_Model;
      Item_Index : Natural)
   is
   begin
      if not Model.Selected_Item_Indexes.Is_Empty then
         for Index in reverse Model.Selected_Item_Indexes.First_Index .. Model.Selected_Item_Indexes.Last_Index loop
            if Model.Selected_Item_Indexes.Element (Index) = Item_Index then
               Model.Selected_Item_Indexes.Delete (Index);
            end if;
         end loop;
      end if;
   end Remove_Selected_Index;

   procedure Mark_Settings_Draft_Edited (Model : in out Window_Model) is
   begin
      Model.Settings_Draft_Value.Valid := True;
      Model.Settings_Draft_Value.Error_Key := Null_Unbounded_String;
   end Mark_Settings_Draft_Edited;

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
      if not Model.Rename_Active then
         return;
      end if;

      --  The temporary create item keeps its rename field until it is
      --  explicitly committed or cancelled, so leave it untouched here.
      if Model.Temporary_Active then
         return;
      end if;

      --  Drop the inline field for any item that is no longer selected. This
      --  keeps a synchronized multi-rename in step with the live selection.
      for Index in reverse Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         if not Selection_Contains (Model, Model.Rename_Fields.Element (Index).Item_Index) then
            Model.Rename_Fields.Delete (Index);
         end if;
      end loop;

      if Model.Rename_Fields.Is_Empty then
         Model.Rename_Active := False;
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      end if;
   end Reconcile_Rename_With_Selection;

   procedure Reconcile_Selection (Model : in out Window_Model) is
   begin
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
            if Item_Is_Visible (Model, Model.Items.Element (Index)) then
               Model.Selected_Item_Index := Natural (Index);
               Add_Selected_Index (Model, Model.Selected_Item_Index);
               Reconcile_Rename_With_Selection (Model);
               return;
            end if;
         end loop;
      end if;
      Reconcile_Rename_With_Selection (Model);
   end Reconcile_Selection;

   function Signature_From_Items
     (Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector)
      return Files.File_System.Directory_Signature
   is
      Result : Files.File_System.Directory_Signature :=
        (Path                  => To_Unbounded_String (Directory_Path),
         Exists                => True,
         Entry_Count           => Natural (Items.Length),
         Entry_State_Checksum  => 0,
         Latest_Modified       => Ada.Calendar.Time_Of (1901, 1, 1),
         Latest_Modified_Known => False);

      function Item_Checksum
        (Item : Files.File_System.Directory_Item)
         return Natural
      is
         Modulus : constant Long_Long_Integer := 1_000_000_007;
         Value   : Long_Long_Integer := Long_Long_Integer (Files.Types.Item_Kind'Pos (Item.Kind) + 1);
      begin
         for Character_Value of To_String (Item.Name) loop
            Value :=
              (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
         end loop;

         if Item.Size_Available then
            Value := (Value * 131 + Long_Long_Integer'Max (0, Item.Size)) mod Modulus;
         else
            Value := (Value * 131) mod Modulus;
         end if;

         return Natural (Value);
      end Item_Checksum;
   begin
      for Item of Items loop
         Result.Entry_State_Checksum :=
           (Result.Entry_State_Checksum + Item_Checksum (Item)) mod 1_000_000_007;
         if Item.Modified_Available
           and then (not Result.Latest_Modified_Known or else Item.Modified_Time > Result.Latest_Modified)
         then
            Result.Latest_Modified := Item.Modified_Time;
            Result.Latest_Modified_Known := True;
         end if;
      end loop;

      return Result;
   end Signature_From_Items;

   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.File_System.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons) is
   begin
      Model.Current_Path_Value := To_Unbounded_String (Directory_Path);
      Model.Home_Path_Value := To_Unbounded_String (Home_Path);
      Model.Items := Items;
      Model.Directory_Signature := Signature_From_Items (Directory_Path, Items);
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.View_Value := Default_View_Mode;
      Model.Sort_Field_Value := Sort_Name;
      Model.Sort_Ascending := True;
      Model.Sort_Menu_Open := False;
      Model.Back_History.Clear;
      Model.Forward_History.Clear;
      Model.Recent_View_Active := False;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Recent_Open_Queue.Clear;
      Model.Focus_Value := Files.Types.Focus_None;
      Model.Path_Input_Value := To_Unbounded_String (Directory_Path);
      Model.Path_Input_Cursor := Directory_Path'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Info_Pane_Open := False;
      Model.Main_View_Scroll := 0;
      Clear_Root_Selector_State (Model);
      Reset_Quick_Look (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Model.Last_Error := Null_Unbounded_String;
   end Initialize;

   function Current_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Current_Path_Value);
   end Current_Path;

   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature is
   begin
      return Model.Directory_Signature;
   end Directory_Signature_Of;

   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature) is
   begin
      Model.Directory_Signature := Signature;
   end Set_Directory_Signature;

   function Home_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Home_Path_Value);
   end Home_Path;

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is
   begin
      return Model.View_Value;
   end View_Mode_Of;

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is
   begin
      Model.View_Value := Mode;
      Model.Main_View_Scroll := 0;
   end Set_View_Mode;

   function Sort_Field_Of
     (Model : Window_Model)
      return Sort_Field is
   begin
      return Model.Sort_Field_Value;
   end Sort_Field_Of;

   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Ascending;
   end Sort_Is_Ascending;

   function Settings_Sort_Field (Field : Sort_Field) return Files.Settings.Sort_Field is
   begin
      case Field is
         when Sort_Name    => return Files.Settings.Sort_By_Name;
         when Sort_Size    => return Files.Settings.Sort_By_Size;
         when Sort_Type    => return Files.Settings.Sort_By_Filetype;
         when Sort_Created => return Files.Settings.Sort_By_Created;
         when Sort_Changed => return Files.Settings.Sort_By_Modified;
      end case;
   end Settings_Sort_Field;

   --  Reorder the stored items to match the model's current sort field and
   --  direction. Keyboard navigation walks the stored item order, so it must be
   --  identical to the displayed order the renderer sorts with -- otherwise a
   --  descending sort makes Up/Down move against the visible order. Selection
   --  and rename targets are index-based, so they are re-established by item
   --  identity (full path) after the reorder.
   procedure Resort_Items (Model : in out Window_Model) is
      Previous_Selection : Files.File_System.Item_Vectors.Vector;
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

      function Index_Of (Path : Unbounded_String) return Natural is
      begin
         if Path = Null_Unbounded_String then
            return 0;
         end if;
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Model.Items.Element (Index).Full_Path = Path then
               return Natural (Index);
            end if;
         end loop;
         return 0;
      end Index_Of;
   begin
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
      for Field of Model.Rename_Fields loop
         Rename_Old_Paths.Append (Path_At (Field.Item_Index));
      end loop;

      Files.File_System.Sort_Items
        (Model.Items,
         Settings_Sort_Field (Model.Sort_Field_Value),
         Model.Sort_Ascending);

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

      if not Primary_Sentinel then
         Model.Selected_Item_Index := Index_Of (Primary_Path);
      end if;

      --  Remap each rename field to its item's new index, preserving the
      --  temporary field and dropping fields whose item vanished.
      declare
         Rebuilt : Rename_Field_Vectors.Vector;
         Cursor  : Positive := Rename_Old_Paths.First_Index;
      begin
         for Field of Model.Rename_Fields loop
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
         Model.Rename_Fields := Rebuilt;
      end;
   end Resort_Items;

   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Sort_Field) is
   begin
      if Model.Sort_Field_Value = Field then
         Model.Sort_Ascending := not Model.Sort_Ascending;
      else
         Model.Sort_Field_Value := Field;
         Model.Sort_Ascending := True;
      end if;

      Model.Sort_Menu_Open := False;
      Model.Main_View_Scroll := 0;
      Resort_Items (Model);
   end Select_Sort_Field;

   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Sort_Field;
      Ascending : Boolean) is
   begin
      Model.Sort_Field_Value := Field;
      Model.Sort_Ascending   := Ascending;
      Resort_Items (Model);
   end Apply_Sort;

   procedure Toggle_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Sort_Menu_Open := not Model.Sort_Menu_Open;
   end Toggle_Sort_Menu;

   procedure Close_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Sort_Menu_Open := False;
   end Close_Sort_Menu;

   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Menu_Open;
   end Sort_Menu_Is_Open;

   function Item_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Items.Length);
   end Item_Count;

   function Visible_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      if not Model.Items.Is_Empty then
         for Item of Model.Items loop
            if Item_Is_Visible (Model, Item) then
               Count := Count + 1;
            end if;
         end loop;
      end if;

      if Temporary_Is_Visible (Model) then
         Count := Count + 1;
      end if;

      return Count;
   end Visible_Count;

   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural
   is
      Count : Natural := 0;
   begin
      for Item of Model.Items loop
         declare
            Name : constant String := To_String (Item.Name);
         begin
            if Name'Length > 0 and then Name (Name'First) = '.' then
               Count := Count + 1;
            end if;
         end;
      end loop;

      return Count;
   end Hidden_Item_Count;

   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item
   is
      Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      if Item_Index /= 0 then
         return Model.Items.Element (Positive (Item_Index));
      elsif Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model) then
         if Model.Temporary_Is_Directory then
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Directory_Item);
         else
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "text/plain");
         end if;
      else
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      end if;
   end Visible_Item;

   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Filter_Value := To_Unbounded_String (Text);
      Model.Filter_Cursor := Text'Length;
      Model.Main_View_Scroll := 0;
      Reconcile_Selection (Model);
   end Set_Filter;

   function Filter_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Filter_Value);
   end Filter_Text;

   procedure Clear_Filter
     (Model : in out Window_Model) is
   begin
      Set_Filter (Model, "");
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
   end Clear_Filter;

   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope is
   begin
      return Model.Search_Scope_Value;
   end Search_Scope_Of;

   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is
   begin
      Model.Search_Scope_Value := Scope;
   end Set_Search_Scope;

   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Search_Results_Active;
   end Search_Results_Are_Active;

   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is
   begin
      Model.Search_Scope_Value := Scope;
      Model.Search_Results_Active := Scope /= Files.Types.Filter_Here;
   end Note_Search_Results;

   procedure Clear_Search_Results
     (Model : in out Window_Model) is
   begin
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
   end Clear_Search_Results;

   --  Single-select a visible item without disturbing the type-ahead prefix.
   --  Type-ahead selection uses this so its own selection jumps do not clear the
   --  prefix it is accumulating; every other selection path goes through the
   --  public Select_Visible, which resets the prefix first.
   procedure Select_Visible_Internal
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      Model.Selected_Item_Index := Item_Index;
      Model.Selected_Item_Indexes.Clear;
      if Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Visible_Index = Visible_Count (Model)
      then
         Model.Selected_Item_Index := Temporary_Item_Index;
      end if;
      Add_Selected_Index (Model, Model.Selected_Item_Index);
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
      --  A changed selection invalidates any open Quick Look preview, which is
      --  bound to the item that was selected when it opened.
      Reset_Quick_Look (Model);
   end Select_Visible_Internal;

   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive) is
   begin
      Reset_Type_Ahead (Model);
      Select_Visible_Internal (Model, Visible_Index);
   end Select_Visible;

   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      Reset_Type_Ahead (Model);
      if Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Visible_Index = Visible_Count (Model)
      then
         Item_Index := Temporary_Item_Index;
      end if;

      if Item_Index = 0 then
         return;
      elsif Selection_Contains (Model, Item_Index) then
         Remove_Selected_Index (Model, Item_Index);
         if Model.Selected_Item_Index = Item_Index then
            Model.Selected_Item_Index :=
              (if Model.Selected_Item_Indexes.Is_Empty
               then 0
               else Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index));
         end if;
      else
         Add_Selected_Index (Model, Item_Index);
         Model.Selected_Item_Index := Item_Index;
      end if;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Toggle_Visible_Selection;

   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive)
   is
      Count : constant Natural := Visible_Count (Model);
      First : Natural;
      Last  : Natural;

      procedure Add_Visible_Index (Visible_Index : Positive) is
         Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
      begin
         if Item_Index = 0
           and then Temporary_Is_Visible (Model)
           and then Visible_Index = Count
         then
            Item_Index := Temporary_Item_Index;
         end if;

         Add_Selected_Index (Model, Item_Index);
      end Add_Visible_Index;
   begin
      Reset_Type_Ahead (Model);
      if Count = 0
        or else Natural (Anchor_Index) > Count
        or else Natural (Target_Index) > Count
      then
         Clear_Selection (Model);
         return;
      end if;

      First := Natural'Min (Natural (Anchor_Index), Natural (Target_Index));
      Last := Natural'Max (Natural (Anchor_Index), Natural (Target_Index));

      Model.Selected_Item_Indexes.Clear;
      for Visible_Index in First .. Last loop
         Add_Visible_Index (Positive (Visible_Index));
      end loop;

      Model.Selected_Item_Index := Visible_To_Item_Index (Model, Target_Index);
      if Model.Selected_Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Natural (Target_Index) = Count
      then
         Model.Selected_Item_Index := Temporary_Item_Index;
      end if;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Select_Visible_Range;

   procedure Select_All_Visible
     (Model : in out Window_Model) is
   begin
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Indexes.Clear;
      Model.Selected_Item_Index := 0;

      if Model.Items.Is_Empty then
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index)) then
            Add_Selected_Index (Model, Natural (Index));
            if Model.Selected_Item_Index = 0 then
               Model.Selected_Item_Index := Natural (Index);
            end if;
         end if;
      end loop;

      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Select_All_Visible;

   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model) is
   begin
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Clear_Overlay_State_For_Edit;

   procedure Clear_Selection
     (Model : in out Window_Model) is
   begin
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Clear_Selection;

   procedure Invert_Selection
     (Model : in out Window_Model)
   is
      Primary : Natural := 0;
   begin
      Reset_Type_Ahead (Model);

      if Model.Items.Is_Empty then
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index)) then
            if Selection_Contains (Model, Natural (Index)) then
               Remove_Selected_Index (Model, Natural (Index));
            else
               Add_Selected_Index (Model, Natural (Index));
            end if;
         end if;
      end loop;

      --  Items are stored in visible order, so the lowest selected index is
      --  the first visible selected item and makes a deterministic primary.
      for Selected of Model.Selected_Item_Indexes loop
         if Primary = 0 or else Selected < Primary then
            Primary := Selected;
         end if;
      end loop;

      Model.Selected_Item_Index := Primary;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Invert_Selection;

   procedure Deselect_All
     (Model : in out Window_Model) is
   begin
      Clear_Selection (Model);
   end Deselect_All;

   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Count   : constant Natural := Visible_Count (Model);
      Current : constant Natural := Selected_Index (Model);
      Stride  : constant Natural :=
        Natural'Max (1, Natural'Min (Natural (Model.Selection_Columns), Natural'Max (1, Count)));
      Next    : Natural;

      function Last_In_Column
        (Column : Positive)
         return Natural
      is
         Candidate : Natural := Natural (Column);
      begin
         while Candidate + Stride <= Count loop
            Candidate := Candidate + Stride;
         end loop;

         return Candidate;
      end Last_In_Column;
   begin
      if Count = 0 then
         Clear_Selection (Model);
         return;
      elsif Current = 0 then
         Select_Visible (Model, 1);
         return;
      end if;

      case Direction is
         when Guikit.Input.Move_Left =>
            if Current = 1 then
               Next := Count;
            else
               Next := Current - 1;
            end if;
         when Guikit.Input.Move_Right =>
            if Current = Count then
               Next := 1;
            else
               Next := Current + 1;
            end if;
         when Guikit.Input.Move_Up =>
            if Current = 1 then
               Next := Count;
            elsif Current > Stride then
               Next := Current - Stride;
            else
               Next := Last_In_Column (Positive (Current));
            end if;
         when Guikit.Input.Move_Down =>
            if Current = Count then
               Next := 1;
            elsif Current + Stride <= Count then
               Next := Current + Stride;
            else
               Next := ((Current - 1) mod Stride) + 1;
            end if;
      end case;

      Select_Visible (Model, Positive (Next));
   end Move_Selection;

   procedure Select_First_Visible
     (Model : in out Window_Model)
   is
      Count : constant Natural := Visible_Count (Model);
   begin
      if Count = 0 then
         Clear_Selection (Model);
      else
         Select_Visible (Model, 1);
      end if;
   end Select_First_Visible;

   procedure Select_Last_Visible
     (Model : in out Window_Model)
   is
      Count : constant Natural := Visible_Count (Model);
   begin
      if Count = 0 then
         Clear_Selection (Model);
      else
         Select_Visible (Model, Positive (Count));
      end if;
   end Select_Last_Visible;

   procedure Move_Selection_By_Page
     (Model     : in out Window_Model;
      Page_Rows : Positive;
      Down      : Boolean)
   is
      Count   : constant Natural := Visible_Count (Model);
      Current : constant Natural := Selected_Index (Model);
      Stride  : constant Natural :=
        Natural'Max (1, Natural'Min (Natural (Model.Selection_Columns), Natural'Max (1, Count)));
      Step    : constant Natural := Natural (Page_Rows) * Stride;
      Next    : Natural;
   begin
      if Count = 0 then
         Clear_Selection (Model);
         return;
      elsif Current = 0 then
         Select_Visible (Model, 1);
         return;
      end if;

      if Down then
         if Current + Step >= Count then
            Next := Count;
         else
            Next := Current + Step;
         end if;
      else
         if Current <= Step then
            Next := 1;
         else
            Next := Current - Step;
         end if;
      end if;

      Select_Visible (Model, Positive (Next));
   end Move_Selection_By_Page;

   procedure Reset_Type_Ahead
     (Model : in out Window_Model) is
   begin
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Reset_Type_Ahead;

   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Type_Ahead_Buffer_Value);
   end Type_Ahead_Buffer;

   --  A run is only fed to type-ahead when every byte is a printable glyph.
   --  Control bytes below the space and the DEL byte never start a prefix.
   function Is_Printable_Run (Text : String) return Boolean is
   begin
      if Text = "" then
         return False;
      end if;

      for Char of Text loop
         if Character'Pos (Char) < Character'Pos (' ')
           or else Character'Pos (Char) = 16#7F#
         then
            return False;
         end if;
      end loop;

      return True;
   end Is_Printable_Run;

   --  Return True when Text is a single UTF-8 codepoint repeated one or more
   --  times (case-insensitively), e.g. "d", "DD", "www". Used to detect the
   --  repeated-letter cycling gesture.
   function Is_Repeated_Single_Codepoint (Text : String) return Boolean is
      Lower : constant String := Files.Types.To_Lower (Text);
      First : Natural;
      Cursor : Natural := 0;
      Unit   : Natural;
   begin
      if Lower = "" then
         return False;
      end if;

      First := Files.UTF8.Next_Boundary (Lower, 0);
      declare
         Head : constant String := Lower (Lower'First .. Lower'First + First - 1);
      begin
         Cursor := First;
         while Cursor < Lower'Length loop
            Unit := Files.UTF8.Next_Boundary (Lower, Cursor) - Cursor;
            if Unit /= Head'Length
              or else Lower (Lower'First + Cursor .. Lower'First + Cursor + Unit - 1) /= Head
            then
               return False;
            end if;
            Cursor := Cursor + Unit;
         end loop;
      end;

      return True;
   end Is_Repeated_Single_Codepoint;

   --  Return the first UTF-8 codepoint of Text as a byte string.
   function First_Codepoint (Text : String) return String is
      Unit : constant Natural := Files.UTF8.Next_Boundary (Text, 0);
   begin
      if Text = "" or else Unit = 0 then
         return "";
      end if;

      return Text (Text'First .. Text'First + Unit - 1);
   end First_Codepoint;

   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean)
   is
      Combined : constant String := To_String (Model.Type_Ahead_Buffer_Value) & Text;
      Current  : constant Natural := Selected_Index (Model);
      Visible  : Files.File_System.Item_Vectors.Vector;
      Count    : constant Natural := Visible_Count (Model);
      Prefix   : Unbounded_String;
      Start    : Natural;
      Target   : Natural;
   begin
      Matched := False;

      if not Is_Printable_Run (Text) then
         return;
      end if;

      --  Snapshot the visible projection in display order so the pure matcher's
      --  returned index maps straight back to a visible index. Temporary
      --  create-file items are never type-ahead targets.
      for Visible_Index in 1 .. Count loop
         if Visible_To_Item_Index (Model, Visible_Index) /= 0 then
            Visible.Append (Visible_Item (Model, Visible_Index));
         else
            Visible.Append (Files.File_System.Directory_Item'(others => <>));
         end if;
      end loop;

      --  Repeatedly typing one letter cycles through the items beginning with
      --  it: collapse the prefix to that single codepoint and scan from just
      --  after the current selection. Any other run refines in place, scanning
      --  from the current selection so an already-matching item is kept.
      if Is_Repeated_Single_Codepoint (Combined) then
         Prefix := To_Unbounded_String (First_Codepoint (Combined));
         Start := Current + 1;
      else
         Prefix := To_Unbounded_String (Combined);
         Start := Current;
      end if;

      Model.Type_Ahead_Buffer_Value := Prefix;

      Target := Files.Type_Ahead.Type_Ahead_Target (Visible, To_String (Prefix), Start);
      if Target > 0 then
         Select_Visible_Internal (Model, Target);
         Matched := True;
      end if;
   end Type_Ahead_Input;

   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive) is
   begin
      Model.Selection_Columns := Columns;
   end Set_Selection_Grid_Columns;

   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive is
   begin
      return Model.Selection_Columns;
   end Selection_Grid_Columns;

   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      if Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Visible_Index = Visible_Count (Model)
      then
         Item_Index := Temporary_Item_Index;
      end if;

      return Selection_Contains (Model, Item_Index);
   end Is_Selected;

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

   function Selected_Name
     (Model : Window_Model)
      return String
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return "";
      elsif Item_Index = Temporary_Item_Index then
         return To_String (Model.Temporary_Name_Value);
      end if;

      return To_String (Model.Items.Element (Positive (Item_Index)).Name);
   end Selected_Name;

   function Selected_Item
     (Model : Window_Model)
      return Files.File_System.Directory_Item
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return Files.File_System.Make_Item ("", "", Files.Types.Unknown_Item);
      elsif Item_Index = Temporary_Item_Index then
         if Model.Temporary_Is_Directory then
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Directory_Item);
         else
            return Files.File_System.Make_Item
              (Parent_Path => Current_Path (Model),
               Name        => To_String (Model.Temporary_Name_Value),
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "text/plain");
         end if;
      end if;

      return Model.Items.Element (Positive (Item_Index));
   end Selected_Item;

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

   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean is
   begin
      return Effective_Selected_Item_Index (Model) = Temporary_Item_Index and then Temporary_Is_Visible (Model);
   end Selected_Item_Is_Temporary;

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

   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector) is
   begin
      --  Leaving the virtual recent view does not preserve it in history (its
      --  path is synthetic); an ordinary directory change pushes back history as
      --  usual.
      if not Model.Recent_View_Active and then Current_Path (Model) /= Directory_Path then
         Model.Back_History.Append (Model.Current_Path_Value);
         Model.Forward_History.Clear;
      end if;

      Model.Recent_View_Active := False;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Current_Path_Value := To_Unbounded_String (Directory_Path);
      Model.Items := Items;
      Model.Directory_Signature := Signature_From_Items (Directory_Path, Items);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Path_Input_Value := To_Unbounded_String (Directory_Path);
      Model.Path_Input_Cursor := Directory_Path'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
      Reset_Quick_Look (Model);
   end Navigate_To;

   procedure Navigate_Recent
     (Model : in out Window_Model;
      Items : Files.File_System.Item_Vectors.Vector) is
   begin
      --  Only the initial entry into the view records the departure point; a
      --  refresh or clear re-enters while already active and just swaps items.
      if not Model.Recent_View_Active then
         Model.Back_History.Append (Model.Current_Path_Value);
         Model.Forward_History.Clear;
      end if;

      Model.Recent_View_Active := True;
      Model.Current_Path_Value := Null_Unbounded_String;
      Model.Items := Items;
      Model.Directory_Signature := Signature_From_Items ("", Items);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Path_Input_Value := Null_Unbounded_String;
      Model.Path_Input_Cursor := 0;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
      Reset_Quick_Look (Model);
   end Navigate_Recent;

   function In_Recent_View
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Recent_View_Active;
   end In_Recent_View;

   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is
   begin
      if Path /= "" then
         Model.Recent_Open_Queue.Append (To_Unbounded_String (Path));
      end if;
   end Note_Recent_Open;

   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Drained : constant Files.Types.String_Vectors.Vector := Model.Recent_Open_Queue;
   begin
      Model.Recent_Open_Queue.Clear;
      return Drained;
   end Take_Recent_Opens;

   function Can_Go_Back
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Back_History.Is_Empty;
   end Can_Go_Back;

   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Forward_History.Is_Empty;
   end Can_Go_Forward;

   procedure Go_Back
     (Model : in out Window_Model) is
      Previous : UString;
   begin
      if not Can_Go_Back (Model) then
         return;
      end if;

      Previous := Model.Back_History.Last_Element;
      Model.Back_History.Delete_Last;
      --  The synthetic recent view is never preserved in forward history.
      if not Model.Recent_View_Active then
         Model.Forward_History.Append (Model.Current_Path_Value);
      end if;
      Model.Recent_View_Active := False;
      Model.Current_Path_Value := Previous;
      Model.Path_Input_Value := Previous;
      Model.Path_Input_Cursor := Length (Previous);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Go_Back;

   procedure Go_Forward
     (Model : in out Window_Model) is
      Next : UString;
   begin
      if not Can_Go_Forward (Model) then
         return;
      end if;

      Next := Model.Forward_History.Last_Element;
      Model.Forward_History.Delete_Last;
      --  The synthetic recent view is never preserved in back history.
      if not Model.Recent_View_Active then
         Model.Back_History.Append (Model.Current_Path_Value);
      end if;
      Model.Recent_View_Active := False;
      Model.Current_Path_Value := Next;
      Model.Path_Input_Value := Next;
      Model.Path_Input_Cursor := Length (Next);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Go_Forward;

   procedure Go_Home
     (Model : in out Window_Model)
   is
      Empty_Items : Files.File_System.Item_Vectors.Vector;
   begin
      Navigate_To (Model, Home_Path (Model), Empty_Items);
   end Go_Home;

   procedure Focus_Path_Input
     (Model : in out Window_Model) is
   begin
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Path_Input;
      Model.Path_Input_Value := Model.Current_Path_Value;
      Model.Path_Input_Cursor := Length (Model.Path_Input_Value);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Path_Input;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is
   begin
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Filter_Input;
      Model.Filter_Cursor := Length (Model.Filter_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Filter_Input;

   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model) is
   begin
      if Model.Command_Palette_Open then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Command_Palette;
      end if;
   end Focus_Command_Palette_Input;

   procedure Focus_Rename_Input
     (Model : in out Window_Model) is
   begin
      if Model.Rename_Active then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Rename_Input;
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      end if;
   end Focus_Rename_Input;

   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean)
   is
      Item : constant Files.File_System.Directory_Item := Selected_Item (Model);
   begin
      if Selected_Count (Model) /= 1
        or else Selection_Includes_Temporary (Model)
        or else not Files.File_System.Supports_Ownership
        or else not Item.Ownership_Available
        or else Current_Path (Model) = Files.File_System.Trash_Files_Directory
      then
         return;
      end if;

      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Ownership_Input;
      Model.Ownership_Editing_Group_Value := Editing_Group;
      declare
         Id   : constant Natural := (if Editing_Group then Item.Group_Id else Item.Owner_Id);
         --  Seed with the resolved name so the field matches its display; the
         --  commit path accepts a name or a number. Fall back to the number.
         Name : constant String :=
           (if Editing_Group
            then Files.File_System.Group_Name_For_Id (Id)
            else Files.File_System.User_Name_For_Id (Id));
      begin
         Model.Ownership_Input_Value :=
           To_Unbounded_String
             (if Name /= "" then Name
              else Ada.Strings.Fixed.Trim (Natural'Image (Id), Ada.Strings.Both));
      end;
      Model.Ownership_Input_Cursor := Length (Model.Ownership_Input_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Ownership_Input;

   function Ownership_Input_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Ownership_Input_Value);
   end Ownership_Input_Text;

   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Ownership_Input_Value := To_Unbounded_String (Text);
      Model.Ownership_Input_Cursor := Text'Length;
   end Set_Ownership_Input_Text;

   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Ownership_Editing_Group_Value;
   end Ownership_Editing_Group;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector)
   is
      Entries : Files.File_System.Root_Entry_Vectors.Vector;
   begin
      for Root of Roots loop
         Entries.Append
           (Files.File_System.Root_Entry'
              (Path  => Root,
               Label => Root,
               Kind  => Files.File_System.Root_Filesystem,
               Volume_Name => Root,
               Ready => Files.File_System.Root_Ready,
               Removable => False));
      end loop;

      Open_Root_Selector (Model, Entries);
   end Open_Root_Selector;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector) is
   begin
      Model.Root_Entries := Roots;
      Model.Root_Selector_Open := not Roots.Is_Empty;
      Model.Root_Selected := (if Model.Root_Selector_Open then 1 else 0);
      Model.Settings_Pane_Open := False;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Open_Root_Selector;

   procedure Close_Root_Selector
     (Model : in out Window_Model) is
   begin
      Clear_Root_Selector_State (Model);
   end Close_Root_Selector;

   function Root_Selector_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Root_Selector_Open;
   end Root_Selector_Is_Open;

   function Root_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Root_Entries.Length);
   end Root_Count;

   function Root_Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      if not Model.Root_Selector_Open
        or else Model.Root_Selected = 0
        or else Model.Root_Selected > Root_Count (Model)
      then
         return 0;
      end if;

      return Model.Root_Selected;
   end Root_Selected_Index;

   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      if not Model.Root_Selector_Open or else Root_Count (Model) = 0 then
         Model.Root_Selected := 0;
      elsif Index = 0 then
         Model.Root_Selected := 0;
      else
         Model.Root_Selected := Natural'Min (Index, Root_Count (Model));
      end if;
   end Set_Root_Selected_Index;

   procedure Move_Root_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Count   : constant Natural := Root_Count (Model);
      Current : constant Natural := Root_Selected_Index (Model);
   begin
      if not Model.Root_Selector_Open or else Count = 0 then
         Model.Root_Selected := 0;
      elsif Current = 0 then
         Model.Root_Selected := 1;
      elsif Direction = Guikit.Input.Move_Up or else Direction = Guikit.Input.Move_Left then
         Model.Root_Selected := (if Current = 1 then Count else Current - 1);
      else
         Model.Root_Selected := (if Current = Count then 1 else Current + 1);
      end if;
   end Move_Root_Selection;

   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Entries.Element (Index).Path);
   end Root_Path;

   function Root_Label
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Entries.Element (Index).Label);
   end Root_Label;

   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return Files.File_System.Root_Filesystem;
      end if;

      return Model.Root_Entries.Element (Index).Kind;
   end Root_Kind;

   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return False;
      end if;

      return Model.Root_Entries.Element (Index).Removable;
   end Root_Is_Removable;

   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target is
   begin
      return Model.Focus_Value;
   end Focus;

   function Focused_Text_Length
     (Model : Window_Model)
      return Natural is
   begin
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            return Length (Model.Path_Input_Value);
         when Files.Types.Focus_Filter_Input =>
            return Length (Model.Filter_Value);
         when Files.Types.Focus_Rename_Input =>
            return First_Rename_Value (Model)'Length;
         when Files.Types.Focus_Command_Palette =>
            return Guikit.Command_Palette.Query (Model.Command_Palette_View)'Length;
         when Files.Types.Focus_Settings_Input =>
            return Settings_Focused_Value (Model)'Length;
         when Files.Types.Focus_Ownership_Input =>
            return Length (Model.Ownership_Input_Value);
         when Files.Types.Focus_None =>
            return 0;
      end case;
   end Focused_Text_Length;

   function Focused_Text_Value
     (Model : Window_Model)
      return String is
   begin
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            return To_String (Model.Path_Input_Value);
         when Files.Types.Focus_Filter_Input =>
            return To_String (Model.Filter_Value);
         when Files.Types.Focus_Rename_Input =>
            return First_Rename_Value (Model);
         when Files.Types.Focus_Command_Palette =>
            return Guikit.Command_Palette.Query (Model.Command_Palette_View);
         when Files.Types.Focus_Settings_Input =>
            return Settings_Focused_Value (Model);
         when Files.Types.Focus_Ownership_Input =>
            return To_String (Model.Ownership_Input_Value);
         when Files.Types.Focus_None =>
            return "";
      end case;
   end Focused_Text_Value;

   function Text_Cursor_Position
     (Model : Window_Model)
      return Natural is
   begin
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            return Text_Boundary_At_Or_Before (To_String (Model.Path_Input_Value), Model.Path_Input_Cursor);
         when Files.Types.Focus_Filter_Input =>
            return Text_Boundary_At_Or_Before (To_String (Model.Filter_Value), Model.Filter_Cursor);
         when Files.Types.Focus_Rename_Input =>
            return Text_Boundary_At_Or_Before (First_Rename_Value (Model), First_Rename_Cursor (Model));
         when Files.Types.Focus_Command_Palette =>
            --  The palette query has no separate caret; it sits at the end.
            return Guikit.Command_Palette.Query (Model.Command_Palette_View)'Length;
         when Files.Types.Focus_Settings_Input =>
            --  The panel edits whole values; the caret sits at the end.
            return Settings_Focused_Value (Model)'Length;
         when Files.Types.Focus_Ownership_Input =>
            return Text_Boundary_At_Or_Before
                     (To_String (Model.Ownership_Input_Value), Model.Ownership_Input_Cursor);
         when Files.Types.Focus_None =>
            return 0;
      end case;
   end Text_Cursor_Position;

   procedure Set_Text_Cursor_Position
     (Model    : in out Window_Model;
      Position : Natural)
   is
      Clamped : constant Natural :=
        Text_Boundary_At_Or_Before (Focused_Text_Value (Model), Position);
   begin
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            Model.Path_Input_Cursor := Clamped;
         when Files.Types.Focus_Filter_Input =>
            Model.Filter_Cursor := Clamped;
         when Files.Types.Focus_Rename_Input =>
            if not Model.Rename_Fields.Is_Empty then
               declare
                  Field : Rename_Field := Model.Rename_Fields.First_Element;
               begin
                  Field.Cursor := Clamped;
                  Model.Rename_Fields.Replace_Element (Model.Rename_Fields.First_Index, Field);
               end;
            end if;
         when Files.Types.Focus_Command_Palette =>
            --  The palette query is append-only; it has no movable caret.
            null;
         when Files.Types.Focus_Settings_Input =>
            --  The panel edits whole values; there is no movable caret.
            null;
         when Files.Types.Focus_Ownership_Input =>
            Model.Ownership_Input_Cursor := Clamped;
         when Files.Types.Focus_None =>
            null;
      end case;
   end Set_Text_Cursor_Position;

   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Cursor : constant Natural := Text_Cursor_Position (Model);
   begin
      if Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up then
         if Cursor > 0 then
            Set_Text_Cursor_Position (Model, Previous_Text_Boundary (Focused_Text_Value (Model), Cursor));
         end if;
      elsif Cursor < Focused_Text_Length (Model) then
         Set_Text_Cursor_Position (Model, Next_Text_Boundary (Focused_Text_Value (Model), Cursor));
      end if;
   end Move_Text_Cursor;

   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Path_Input_Value := To_Unbounded_String (Text);
      Model.Path_Input_Cursor := Text'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
   end Set_Path_Input_Text;

   function Path_Input_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Value);
   end Path_Input_Text;

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector) is
   begin
      if Result.Status = Files.File_System.Path_Valid then
         Navigate_To (Model, To_String (Result.Directory_Path), Items);
         Model.Focus_Value := Files.Types.Focus_None;
      else
         Model.Path_Input_Valid := False;
         Model.Path_Input_Error := Result.Error_Key;
      end if;
   end Commit_Path_Input;

   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Path_Input_Valid;
   end Path_Input_Is_Valid;

   function Path_Input_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Error);
   end Path_Input_Error_Key;

   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model) is
   begin
      Clear_Root_Selector_State (Model);

      if Model.Focus_Value = Files.Types.Focus_Path_Input then
         Model.Path_Input_Value := Model.Current_Path_Value;
         Model.Path_Input_Cursor := Length (Model.Path_Input_Value);
         Model.Path_Input_Valid := True;
         Model.Path_Input_Error := Null_Unbounded_String;
      end if;

      if Is_Temporary_Rename (Model) then
         Cancel_Create_File (Model);
      elsif Model.Rename_Active then
         Reset_Rename_State (Model);
      end if;

      Model.Focus_Value := Files.Types.Focus_None;
   end Cancel_Focus_Or_Edit;

   procedure Toggle_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Tree_Panel_Open := not Model.Tree_Panel_Open;
   end Toggle_Tree_Panel;

   procedure Open_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Tree_Panel_Open := True;
   end Open_Tree_Panel;

   procedure Close_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Tree_Panel_Open := False;
      --  Closing the sidebar also abandons any in-flight destination picker so
      --  a later reopen starts clean.
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
   end Close_Tree_Panel;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String) is
   begin
      Model.Tree_Pick_Mode_Value := Mode;
      Model.Tree_Pick_Sources_Value := Sources;
      Model.Tree_Pick_Target_Value := To_Unbounded_String (Initial_Target);
   end Begin_Tree_Pick;

   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String) is
   begin
      Model.Tree_Pick_Target_Value := To_Unbounded_String (Target);
   end Set_Tree_Pick_Target;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is
   begin
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
   end Clear_Tree_Pick;

   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode is
   begin
      return Model.Tree_Pick_Mode_Value;
   end Tree_Pick_Mode_Of;

   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Pick_Mode_Value /= Pick_None;
   end Tree_Pick_Is_Active;

   function Tree_Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Tree_Pick_Sources_Value;
   end Tree_Pick_Sources;

   function Tree_Pick_Target
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Tree_Pick_Target_Value);
   end Tree_Pick_Target;

   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Panel_Open;
   end Tree_Panel_Is_Open;

   function Tree_Is_Seeded
     (Model : Window_Model)
      return Boolean is
   begin
      return Files.Folder_Tree.Is_Seeded (Model.Folder_Tree_Value);
   end Tree_Is_Seeded;

   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Files.Folder_Tree.Seed (Model.Folder_Tree_Value, Roots);
   end Seed_Tree;

   function Tree_Node_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Files.Folder_Tree.Node_Count (Model.Folder_Tree_Value);
   end Tree_Node_Count;

   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      return Files.Folder_Tree.Node_Path (Model.Folder_Tree_Value, Index);
   end Tree_Node_Path;

   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      return Files.Folder_Tree.Node_Is_Loaded (Model.Folder_Tree_Value, Index);
   end Tree_Node_Is_Loaded;

   function Tree_Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      return Files.Folder_Tree.Node_Is_Expanded (Model.Folder_Tree_Value, Index);
   end Tree_Node_Is_Expanded;

   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Files.Folder_Tree.Set_Children (Model.Folder_Tree_Value, Index, Children);
   end Tree_Set_Children;

   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      Files.Folder_Tree.Set_Expanded (Model.Folder_Tree_Value, Index, Expanded);
   end Tree_Set_Expanded;

   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Files.Folder_Tree.Toggle_Expanded (Model.Folder_Tree_Value, Index);
   end Tree_Toggle_Expanded;

   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector is
   begin
      return Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
   end Tree_Visible_Rows;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is
   begin
      Model.Info_Pane_Open := not Model.Info_Pane_Open;
      Model.Info_Pane_Scroll := 0;
   end Toggle_Info_Pane;

   procedure Ensure_Selected_Item_Extra
     (Model : in out Window_Model)
   is
      Idx : constant Natural := Model.Selected_Item_Index;
   begin
      if not Model.Info_Pane_Open
        or else Idx = 0
        or else Idx > Natural (Model.Items.Length)
      then
         return;
      end if;
      declare
         Item : Files.File_System.Directory_Item := Model.Items.Element (Idx);
      begin
         if Length (Item.Filetype_Extra) = 0 then
            Item.Filetype_Extra :=
              To_Unbounded_String
                (Files.File_System.Extra_Info_Token
                   (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype)));
            Model.Items.Replace_Element (Idx, Item);
         end if;
      end;
   end Ensure_Selected_Item_Extra;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Info_Pane_Open;
   end Info_Pane_Is_Open;

   --  Reset the panel component and rebuild its field list from the draft.
   procedure Reset_Settings_Panel (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Reset (Model.Settings_Panel_View);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Files.Settings_Form.Fields (Model));
   end Reset_Settings_Panel;

   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is
   begin
      Model.Settings_Pane_Open := not Model.Settings_Pane_Open;
      if Model.Settings_Pane_Open then
         Clear_Edit_State (Model);
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
         Reset_Settings_Panel (Model);
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      elsif Model.Focus_Value = Files.Types.Focus_Settings_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Toggle_Settings_Pane;

   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Settings_Pane_Open;
   end Settings_Pane_Is_Open;

   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Pane_Open := True;
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Reset_Settings_Panel (Model);
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Begin_Settings_Edit;

   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
   begin
      return Model.Settings_Draft_Value;
   end Settings_Draft_Of;

   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
   end Set_Settings_Draft;

   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Guikit.Settings_Panel.Move_Focus (Model.Settings_Panel_View, Delta_Rows);
   end Settings_Move_Focus;

   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is
   begin
      Guikit.Settings_Panel.Cycle_Choice (Model.Settings_Panel_View, Forward);
   end Settings_Cycle_Choice;

   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Settings_Panel.Set_Focused_Value (Model.Settings_Panel_View, Text);
   end Settings_Set_Focused_Value;

   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer) is
   begin
      Guikit.Settings_Panel.Scroll (Model.Settings_Panel_View, Lines);
   end Settings_Scroll;

   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      return Guikit.Settings_Panel.Click (Model.Settings_Panel_View, X, Y);
   end Settings_Click;

   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is
   begin
      return Guikit.Settings_Panel.Take_Change (Model.Settings_Panel_View);
   end Settings_Take_Change;

   function Settings_Focused_Value (Model : Window_Model) return String is
   begin
      return Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View);
   end Settings_Focused_Value;

   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is
   begin
      Guikit.Settings_Panel.Set_Active_Section (Model.Settings_Panel_View, Ordinal);
   end Settings_Set_Active_Section;

   function Settings_Section_Count (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Section_Count (Model.Settings_Panel_View);
   end Settings_Section_Count;

   function Settings_Active_Section (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Active_Section (Model.Settings_Panel_View);
   end Settings_Active_Section;

   procedure Settings_Begin_Capture (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Begin_Capture (Model.Settings_Panel_View);
   end Settings_Begin_Capture;

   function Settings_Is_Capturing (Model : Window_Model) return Boolean is
   begin
      return Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View);
   end Settings_Is_Capturing;

   function Settings_Capturing_Key (Model : Window_Model) return String is
   begin
      return Guikit.Settings_Panel.Capturing_Key (Model.Settings_Panel_View);
   end Settings_Capturing_Key;

   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Settings_Panel.Set_Captured_Shortcut (Model.Settings_Panel_View, Text);
   end Settings_Set_Captured_Shortcut;

   procedure Settings_Cancel_Capture (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
   end Settings_Cancel_Capture;

   procedure Settings_Build_Frame
     (Model         : in out Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      Config : Guikit.Settings_Panel.Configuration;
   begin
      Config.Line_Height := Line_Height;
      Config.Title := To_Unbounded_String (Files.Localization.Text ("settings.title"));
      Config.Switch_Tooltip := To_Unbounded_String (Files.Localization.Text ("settings.tabs.hint"));
      if Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View) then
         --  While a chord is being captured, the footer prompts for input
         --  instead of showing any pending validation error.
         Config.Status := To_Unbounded_String (Files.Localization.Text ("settings.shortcut.capturing"));
      elsif not Model.Settings_Draft_Value.Valid
        and then Length (Model.Settings_Draft_Value.Error_Key) > 0
      then
         Config.Status :=
           To_Unbounded_String (Files.Localization.Text (To_String (Model.Settings_Draft_Value.Error_Key)));
         Config.Status_Is_Error := True;
      end if;
      Guikit.Settings_Panel.Set_Configuration (Model.Settings_Panel_View, Config);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Files.Settings_Form.Fields (Model));
      Guikit.Settings_Panel.Build_Frame
        (P             => Model.Settings_Panel_View,
         Region_X      => Region_X,
         Region_Y      => Region_Y,
         Region_Width  => Region_Width,
         Region_Height => Region_Height,
         Clip_Width    => Clip_Width,
         Clip_Height   => Clip_Height,
         Focused       => Focused,
         Hover_X       => Hover_X,
         Hover_Y       => Hover_Y,
         Rectangles    => Rectangles,
         Text          => Text,
         Accessibility => Accessibility);
   end Settings_Build_Frame;

   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      if not Model.Info_Pane_Open or else Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Info_Pane_Scroll then
               Model.Info_Pane_Scroll := 0;
            else
               Model.Info_Pane_Scroll := Model.Info_Pane_Scroll - Step;
            end if;
         end;
      else
         Model.Info_Pane_Scroll := Saturating_Add (Model.Info_Pane_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Info_Pane;

   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Info_Pane_Scroll;
   end Info_Pane_Scroll_Lines;

   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is
   begin
      Model.Info_Pane_Scroll := Lines;
   end Set_Info_Pane_Scroll_Lines;

   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is
   begin
      Model.Main_View_Scroll := Lines;
   end Set_Main_View_Scroll_Lines;

   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      if Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Main_View_Scroll then
               Model.Main_View_Scroll := 0;
            else
               Model.Main_View_Scroll := Model.Main_View_Scroll - Step;
            end if;
         end;
      else
         Model.Main_View_Scroll := Saturating_Add (Model.Main_View_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Main_View;

   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Main_View_Scroll;
   end Main_View_Scroll_Lines;

   --  The presentation config for the command palette (overlay with shortcuts,
   --  the component owns the filtering).
   function Palette_Config
     (Line_Height : Positive;
      Mode        : Palette_Mode) return Guikit.Command_Palette.Configuration is
   begin
      return
        (Line_Height    => Line_Height,
         Show_Icons     => False,
         Show_Shortcuts => True,
         Overlay        => True,
         Wrap_Selection => True,
         Placeholder    => Null_Unbounded_String,
         Empty_State    => To_Unbounded_String (Files.Localization.Text ("command.palette.empty")),
         Title          => To_Unbounded_String
                             (Files.Localization.Text
                                (if Mode = Palette_Open_With
                                 then "command_palette.title.open_with"
                                 else "command_palette.title")));
   end Palette_Config;

   procedure Open_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := True;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette_View, Palette_Config (20, Palette_Commands));
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Model.Focus_Value := Files.Types.Focus_Command_Palette;
   end Open_Command_Palette;

   procedure Close_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Close_Command_Palette;

   procedure Toggle_Command_Palette
     (Model : in out Window_Model) is
   begin
      if Model.Command_Palette_Open then
         Close_Command_Palette (Model);
      else
         Open_Command_Palette (Model);
      end if;
   end Toggle_Command_Palette;

   function Command_Palette_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Command_Palette_Open;
   end Command_Palette_Is_Open;

   function Palette_Query (Model : Window_Model) return String is
   begin
      return Guikit.Command_Palette.Query (Model.Command_Palette_View);
   end Palette_Query;

   procedure Palette_Set_Query (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Command_Palette.Set_Query (Model.Command_Palette_View, Text);
   end Palette_Set_Query;

   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Guikit.Command_Palette.Move_Selection (Model.Command_Palette_View, Delta_Rows);
   end Palette_Move_Selection;

   procedure Palette_Select_First (Model : in out Window_Model) is
   begin
      Guikit.Command_Palette.Select_First (Model.Command_Palette_View);
   end Palette_Select_First;

   procedure Palette_Select_Last (Model : in out Window_Model) is
   begin
      Guikit.Command_Palette.Select_Last (Model.Command_Palette_View);
   end Palette_Select_Last;

   procedure Palette_Page (Model : in out Window_Model; Down : Boolean) is
   begin
      Guikit.Command_Palette.Page (Model.Command_Palette_View, Down);
   end Palette_Page;

   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      return Guikit.Command_Palette.Click (Model.Command_Palette_View, X, Y);
   end Palette_Click;

   function Palette_Selected_Id (Model : Window_Model) return Natural is
   begin
      return Guikit.Command_Palette.Selected_Id (Model.Command_Palette_View);
   end Palette_Selected_Id;

   function Palette_Result_Count (Model : Window_Model) return Natural is
   begin
      return Guikit.Command_Palette.Result_Count (Model.Command_Palette_View);
   end Palette_Result_Count;

   procedure Palette_Build_Frame
     (Model         : in out Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector) is
   begin
      --  Refresh the config (line height) and the command list (fresh enablement)
      --  each frame; the component preserves the query and selection.
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette_View, Palette_Config (Line_Height, Model.Command_Palette_Mode));
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Guikit.Command_Palette.Build_Frame
        (P             => Model.Command_Palette_View,
         Region_X      => Region_X,
         Region_Y      => Region_Y,
         Region_Width  => Region_Width,
         Region_Height => Region_Height,
         Clip_Width    => Clip_Width,
         Clip_Height   => Clip_Height,
         Focused       => Focused,
         Hover_X       => -1,
         Hover_Y       => -1,
         Rectangles    => Rectangles,
         Text          => Text,
         Icons         => Icons,
         Accessibility => Accessibility);
   end Palette_Build_Frame;

   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode is
   begin
      return Model.Command_Palette_Mode;
   end Command_Palette_Mode_Of;

   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode) is
   begin
      Model.Command_Palette_Mode := Mode;
      --  The command list is mode-specific; reload it and reset the query.
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
   end Set_Command_Palette_Mode;

   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector) is
   begin
      Model.Open_With_Targets_Value := Targets;
   end Set_Open_With_Targets;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Open_With_Targets_Value;
   end Open_With_Targets;

   procedure Open_Quick_Look
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content) is
   begin
      Model.Quick_Look_Active        := True;
      Model.Quick_Look_Path_Value    := Selected_Item (Model).Full_Path;
      Model.Quick_Look_Content_Value := Content;
   end Open_Quick_Look;

   procedure Close_Quick_Look
     (Model : in out Window_Model) is
   begin
      Reset_Quick_Look (Model);
   end Close_Quick_Look;

   procedure Toggle_Quick_Look
     (Model : in out Window_Model) is
   begin
      if Model.Quick_Look_Active then
         Reset_Quick_Look (Model);
      elsif Selected_Count (Model) = 1 then
         declare
            Item    : constant Files.File_System.Directory_Item := Selected_Item (Model);
            Content : constant Files.Quick_Look.Quick_Look_Content :=
              Files.Quick_Look.Prepare_Content
                (Name           => To_String (Item.Name),
                 Filetype       => To_String (Item.Filetype),
                 Icon_Id        => To_String (Item.Icon_Id),
                 Kind           => Item.Kind,
                 Size_Available => Item.Size_Available,
                 Size           => Item.Size,
                 Is_Image       => False,
                 Image_Path     => To_String (Item.Full_Path),
                 Raw_Bytes      => "");
         begin
            Model.Quick_Look_Active        := True;
            Model.Quick_Look_Path_Value    := Item.Full_Path;
            Model.Quick_Look_Content_Value := Content;
         end;
      end if;
   end Toggle_Quick_Look;

   function Quick_Look_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Quick_Look_Active;
   end Quick_Look_Is_Open;

   function Quick_Look_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Quick_Look_Path_Value);
   end Quick_Look_Path;

   function Quick_Look_Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content is
   begin
      return Model.Quick_Look_Content_Value;
   end Quick_Look_Content_Of;

   procedure Open_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Label_Picker_Active := True;
   end Open_Label_Picker;

   procedure Close_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Label_Picker_Active := False;
   end Close_Label_Picker;

   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Label_Picker_Active;
   end Label_Picker_Is_Open;

   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is
   begin
      return Selected_Count (Model) >= 1 and then not Selection_Includes_Temporary (Model);
   end Rename_Is_Enabled;

   function Rename_Behavior return Rename_Policy is
   begin
      return
        (Single_Item_Only       => False,
         Synchronized_Multi     => True,
         Atomic_Multi_Rename    => False,
         Requires_One_Selection => False);
   end Rename_Behavior;

   --  Return the loaded-item indexes of the current real (non-temporary)
   --  selection, in loaded order, for populating rename fields.
   function Selected_Loaded_Indexes
     (Model : Window_Model)
      return Natural_Vectors.Vector
   is
      Result : Natural_Vectors.Vector;
   begin
      if Model.Items.Is_Empty then
         return Result;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Selection_Contains (Model, Natural (Index))
           and then Item_Is_Visible (Model, Model.Items.Element (Index))
         then
            Result.Append (Natural (Index));
         end if;
      end loop;

      return Result;
   end Selected_Loaded_Indexes;

   --  Return the 1-based index into Rename_Fields for the field shown at
   --  Visible_Index, or zero when that row has no active rename field.
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

      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         if Model.Rename_Fields.Element (Index).Item_Index = Target then
            return Index;
         end if;
      end loop;

      return 0;
   end Find_Rename_Field;

   procedure Toggle_Rename
     (Model : in out Window_Model) is
   begin
      if Model.Rename_Active then
         if Is_Temporary_Rename (Model) then
            Cancel_Create_File (Model);
            if Model.Focus_Value = Files.Types.Focus_Rename_Input then
               Model.Focus_Value := Files.Types.Focus_None;
            end if;
            return;
         end if;

         Reset_Rename_State (Model);
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      elsif Rename_Is_Enabled (Model) then
         Clear_Overlay_State_For_Edit (Model);
         Model.Rename_Fields.Clear;
         declare
            Indexes : constant Natural_Vectors.Vector := Selected_Loaded_Indexes (Model);
         begin
            for Item_Index of Indexes loop
               declare
                  Name : constant String :=
                    To_String (Model.Items.Element (Positive (Item_Index)).Name);
               begin
                  Model.Rename_Fields.Append
                    (Rename_Field'
                       (Item_Index => Item_Index,
                        Value      => To_Unbounded_String (Name),
                        Cursor     => Caret_Before_Extension (Name)));
               end;
            end loop;
         end;

         if not Model.Rename_Fields.Is_Empty then
            Model.Rename_Active := True;
            Model.Focus_Value := Files.Types.Focus_Rename_Input;
         end if;
      end if;
   end Toggle_Rename;

   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Rename_Active;
   end Rename_Is_Active;

   function Rename_Field_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Rename_Fields.Length);
   end Rename_Field_Count;

   function Rename_Text
     (Model : Window_Model)
      return String is
   begin
      return First_Rename_Value (Model);
   end Rename_Text;

   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      if Model.Rename_Active and then not Model.Rename_Fields.Is_Empty then
         declare
            Field : Rename_Field := Model.Rename_Fields.First_Element;
         begin
            Field.Value := To_Unbounded_String (Text);
            Field.Cursor := Text'Length;
            Model.Rename_Fields.Replace_Element (Model.Rename_Fields.First_Index, Field);
            Sync_Temporary_From_Field (Model, Field);
         end;
      end if;
   end Set_Rename_Text;

   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      if Text = "" then
         return False;
      end if;

      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Old   : constant String := To_String (Field.Value);
            Base  : constant Natural := Natural'Min (Field.Cursor, Old'Length);
         begin
            Field.Value := To_Unbounded_String (Insert_Text_At (Old, Base, Text));
            Field.Cursor := Base + Text'Length;
            Model.Rename_Fields.Replace_Element (Index, Field);
            Sync_Temporary_From_Field (Model, Field);
            Changed := True;
         end;
      end loop;

      return Changed;
   end Rename_Insert_At_Carets;

   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Text  : constant String := To_String (Field.Value);
         begin
            if Field.Cursor > 0 and then Text'Length > 0 then
               declare
                  Previous : constant Natural := Files.UTF8.Previous_Boundary (Text, Field.Cursor);
               begin
                  Field.Value := To_Unbounded_String (Remove_Text_Segment (Text, Previous, Field.Cursor));
                  Field.Cursor := Previous;
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Backward;

   function Rename_Delete_Forward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Text  : constant String := To_String (Field.Value);
         begin
            if Field.Cursor < Text'Length then
               declare
                  Next : constant Natural := Files.UTF8.Next_Boundary (Text, Field.Cursor);
               begin
                  Field.Value := To_Unbounded_String (Remove_Text_Segment (Text, Field.Cursor, Next));
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Forward;

   function Rename_Delete_Word_Backward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field    : Rename_Field := Model.Rename_Fields.Element (Index);
            Text     : constant String := To_String (Field.Value);
            Boundary : constant Natural := Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor);
         begin
            if Field.Cursor > 0 and then Boundary < Field.Cursor then
               Field.Value := To_Unbounded_String (Remove_Text_Segment (Text, Boundary, Field.Cursor));
               Field.Cursor := Boundary;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Sync_Temporary_From_Field (Model, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Word_Backward;

   function Rename_Delete_Word_Forward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field    : Rename_Field := Model.Rename_Fields.Element (Index);
            Text     : constant String := To_String (Field.Value);
            Boundary : constant Natural := Files.UTF8.Next_Word_Boundary (Text, Field.Cursor);
         begin
            if Field.Cursor < Text'Length and then Boundary > Field.Cursor then
               Field.Value := To_Unbounded_String (Remove_Text_Segment (Text, Field.Cursor, Boundary));
               Model.Rename_Fields.Replace_Element (Index, Field);
               Sync_Temporary_From_Field (Model, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Word_Forward;

   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename_Fields.Element (Index);
            Text       : constant String := To_String (Field.Value);
            New_Cursor : Natural := Field.Cursor;
         begin
            if Backward then
               if Field.Cursor > 0 then
                  New_Cursor := Files.UTF8.Previous_Boundary (Text, Field.Cursor);
               end if;
            elsif Field.Cursor < Text'Length then
               New_Cursor := Files.UTF8.Next_Boundary (Text, Field.Cursor);
            end if;

            if New_Cursor /= Field.Cursor then
               Field.Cursor := New_Cursor;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Move_All_Carets;

   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename_Fields.Element (Index);
            Text       : constant String := To_String (Field.Value);
            New_Cursor : constant Natural :=
              (if Backward then Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor)
               else Files.UTF8.Next_Word_Boundary (Text, Field.Cursor));
         begin
            if New_Cursor /= Field.Cursor then
               Field.Cursor := New_Cursor;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Move_All_Carets_Word;

   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
         begin
            if Field.Cursor /= 0 then
               Field.Cursor := 0;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Set_All_Carets_Home;

   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Last  : constant Natural := Length (Field.Value);
         begin
            if Field.Cursor /= Last then
               Field.Cursor := Last;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Set_All_Carets_End;

   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural) is
   begin
      if Visible_Index = 0 or else not Model.Rename_Active then
         return;
      end if;

      declare
         Field_Index : constant Natural := Find_Rename_Field (Model, Positive (Visible_Index));
      begin
         if Field_Index /= 0 then
            declare
               Field : Rename_Field := Model.Rename_Fields.Element (Field_Index);
            begin
               Field.Cursor := Files.UTF8.Boundary_At_Or_Before (To_String (Field.Value), Position);
               Model.Rename_Fields.Replace_Element (Field_Index, Field);
            end;
         end if;
      end;
   end Set_Rename_Caret;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
   is
      Field_Index : constant Natural :=
        (if Model.Rename_Active then Find_Rename_Field (Model, Visible_Index) else 0);
   begin
      if Field_Index = 0 then
         Active := False;
         Value  := Null_Unbounded_String;
         Cursor := 0;
      else
         declare
            Field : constant Rename_Field := Model.Rename_Fields.Element (Field_Index);
         begin
            Active := True;
            Value  := Field.Value;
            Cursor := Field.Cursor;
         end;
      end if;
   end Rename_State_For_Visible;

   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector
   is
      Result : Rename_Target_Vectors.Vector;
   begin
      for Field of Model.Rename_Fields loop
         if Field.Item_Index in 1 .. Natural (Model.Items.Last_Index) then
            declare
               Item : constant Files.File_System.Directory_Item :=
                 Model.Items.Element (Positive (Field.Item_Index));
            begin
               Result.Append
                 (Rename_Target'
                    (Item_Index    => Field.Item_Index,
                     Old_Full_Path => Item.Full_Path,
                     Old_Name      => Item.Name,
                     New_Name      => Field.Value));
            end;
         end if;
      end loop;

      return Result;
   end Rename_Targets;

   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is
   begin
      if not Rename_Is_Enabled (Model) then
         return;
      end if;

      Clear_Overlay_State_For_Edit (Model);
      Model.Rename_Fields.Clear;
      Model.Rename_Fields.Append
        (Rename_Field'
           (Item_Index => Effective_Selected_Item_Index (Model),
            Value      => To_Unbounded_String (Text),
            Cursor     => Text'Length));
      Model.Rename_Active := True;
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Resume_Rename;

   procedure Begin_Create_Temporary
      (Model        : in out Window_Model;
       Name         : String;
       Is_Directory : Boolean) is
   begin
      Clear_Overlay_State_For_Edit (Model);
      Model.Temporary_Active := True;
      Model.Temporary_Is_Directory := Is_Directory;
      Model.Temporary_Name_Value := To_Unbounded_String (Name);
      Model.Rename_Fields.Clear;
      Model.Rename_Fields.Append
        (Rename_Field'
           (Item_Index => 0,
            Value      => To_Unbounded_String (Name),
            Cursor     => Name'Length));
      Model.Rename_Active := True;
      Model.Main_View_Scroll := 0;
      Model.Selected_Item_Index := Temporary_Item_Index;
      Model.Selected_Item_Indexes.Clear;
      Add_Selected_Index (Model, Temporary_Item_Index);
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Begin_Create_Temporary;

   procedure Begin_Create_File
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Begin_Create_Temporary (Model, Name, Is_Directory => False);
   end Begin_Create_File;

   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Begin_Create_Temporary (Model, Name, Is_Directory => True);
   end Begin_Create_Folder;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Active;
   end Temporary_Item_Is_Active;

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Is_Directory;
   end Temporary_Item_Is_Directory;

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Temporary_Name_Value);
   end Temporary_Item_Name;

   procedure Cancel_Create_File
     (Model : in out Window_Model) is
   begin
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      if Model.Selected_Item_Index = Temporary_Item_Index then
         Model.Selected_Item_Index := 0;
      end if;
      Remove_Selected_Index (Model, Temporary_Item_Index);
      --  The temporary item owns the only rename field while it is active, so
      --  clearing rename state here discards exactly that field.
      Reset_Rename_State (Model);
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Cancel_Create_File;

   procedure Clear_Edit_State
     (Model : in out Window_Model) is
   begin
      Reset_Rename_State (Model);
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      if Model.Selected_Item_Index = Temporary_Item_Index then
         Model.Selected_Item_Index := 0;
      end if;
      Remove_Selected_Index (Model, Temporary_Item_Index);
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Clear_Edit_State;

   procedure Replace_Items
     (Model : in out Window_Model;
      Items : Files.File_System.Item_Vectors.Vector) is
   begin
      if Model.Temporary_Active then
         Cancel_Create_File (Model);
      elsif Model.Rename_Active then
         Reset_Rename_State (Model);
      end if;
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Items := Items;
      --  Order the loaded items by the active sort so the model's order matches
      --  the displayed order. Without this, arrow navigation (which walks the
      --  model's order) would move opposite to the display under descending sort
      --  or any non-default sort, because Build_Snapshot sorts for display but
      --  Load_Directory cannot know the model's current sort direction.
      Files.File_System.Sort_Items
        (Model.Items,
         Settings_Sort_Field (Model.Sort_Field_Value),
         Model.Sort_Ascending);
      Model.Directory_Signature := Signature_From_Items (Current_Path (Model), Items);
      Model.Main_View_Scroll := 0;
      Model.Info_Pane_Scroll := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
   end Replace_Items;

   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean is
   begin
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

   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String) is
   begin
      Model.Last_Error := To_Unbounded_String (Error_Key);
   end Set_Error;

   function Last_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Last_Error);
   end Last_Error_Key;

   procedure Set_System_Clipboard_Request
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.System_Clipboard_Request_Value := To_Unbounded_String (Text);
      Model.System_Clipboard_Request_Pending := True;
   end Set_System_Clipboard_Request;

   function System_Clipboard_Request_Pending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.System_Clipboard_Request_Pending;
   end System_Clipboard_Request_Pending;

   function System_Clipboard_Request_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.System_Clipboard_Request_Value);
   end System_Clipboard_Request_Text;

   procedure Clear_System_Clipboard_Request
     (Model : in out Window_Model) is
   begin
      Model.System_Clipboard_Request_Value := Null_Unbounded_String;
      Model.System_Clipboard_Request_Pending := False;
   end Clear_System_Clipboard_Request;

   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode) is
   begin
      Model.Clipboard_Paths_Value := Paths;
      Model.Clipboard_Mode_Value :=
        (if Paths.Is_Empty then Clipboard_None else Mode);
   end Set_Clipboard;

   procedure Clear_Clipboard
     (Model : in out Window_Model) is
   begin
      Model.Clipboard_Paths_Value.Clear;
      Model.Clipboard_Mode_Value := Clipboard_None;
   end Clear_Clipboard;

   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Clipboard_Paths_Value;
   end Clipboard_Paths;

   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is
   begin
      return Model.Clipboard_Mode_Value;
   end Clipboard_Mode_Of;

   function Clipboard_Has_Items
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Clipboard_Paths_Value.Is_Empty
        and then Model.Clipboard_Mode_Value /= Clipboard_None;
   end Clipboard_Has_Items;

   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True) is
   begin
      if Kind = Undo_None or else From.Is_Empty then
         return;
      end if;

      Model.Undo_Stack.Append
        (Undo_Entry'
           (Kind        => Kind,
            From        => From,
            To          => To,
            Forward     => Forward,
            Create_Kind => Create_Kind,
            Redoable    => Redoable));
      Model.Redo_Stack.Clear;
   end Record_Undo;

   procedure Clear_Undo
     (Model : in out Window_Model) is
   begin
      Model.Undo_Stack.Clear;
      Model.Redo_Stack.Clear;
   end Clear_Undo;

   function Undo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Undo_Stack.Is_Empty;
   end Undo_Available;

   function Redo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Redo_Stack.Is_Empty;
   end Redo_Available;

   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      if Model.Undo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Undo_Stack.Last_Element;
      Model.Undo_Stack.Delete_Last;
      Found := True;
   end Take_Undo;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      if Model.Redo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Redo_Stack.Last_Element;
      Model.Redo_Stack.Delete_Last;
      Found := True;
   end Take_Redo;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Redo_Stack.Append (Action);
   end Push_Redo;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Undo_Stack.Append (Action);
   end Push_Undo;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Undo_None;
      end if;

      return Model.Undo_Stack.Last_Element.Kind;
   end Undo_Kind_Of;

   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.From;
   end Undo_From_Paths;

   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.To;
   end Undo_To_Paths;

   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is
   begin
      Model.Paste_Conflict_Active_Value := True;
      Model.Paste_Conflict_Items_Value := Items;
      Model.Paste_Conflict_Existing_Value := Existing;
      Model.Paste_Conflict_Mode_Value := Mode;
      Model.Paste_Conflict_Clears_Clip_Val := Clear_Clipboard;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Index_Value := Index;
      Model.Paste_Conflict_Overrides_Value.Clear;
      for Ignore in Items.First_Index .. Items.Last_Index loop
         Model.Paste_Conflict_Overrides_Value.Append (Files.Paste.Decision_Pending);
      end loop;
   end Begin_Paste_Conflict;

   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Active_Value;
   end Paste_Conflict_Is_Active;

   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Items_Value;
   end Paste_Conflict_Items;

   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Existing_Value;
   end Paste_Conflict_Existing;

   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector is
   begin
      return Model.Paste_Conflict_Overrides_Value;
   end Paste_Conflict_Overrides;

   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy is
   begin
      return Model.Paste_Conflict_Policy_Value;
   end Paste_Conflict_Policy;

   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Conflict_Mode_Value;
   end Paste_Conflict_Mode;

   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Clears_Clip_Val;
   end Paste_Conflict_Clears_Clipboard;

   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Conflict_Index_Value;
   end Paste_Conflict_Index;

   function Paste_Conflict_Name
     (Model : Window_Model)
      return String is
   begin
      if Model.Paste_Conflict_Active_Value
        and then Model.Paste_Conflict_Index_Value
                 in Model.Paste_Conflict_Items_Value.First_Index
                    .. Model.Paste_Conflict_Items_Value.Last_Index
      then
         return To_String
           (Model.Paste_Conflict_Items_Value.Element
              (Model.Paste_Conflict_Index_Value).Dest_Name);
      end if;
      return "";
   end Paste_Conflict_Name;

   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Apply_All_Value;
   end Paste_Conflict_Apply_All;

   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model) is
   begin
      Model.Paste_Conflict_Apply_All_Value := not Model.Paste_Conflict_Apply_All_Value;
   end Toggle_Paste_Conflict_Apply_All;

   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is
   begin
      Model.Paste_Conflict_Policy_Value := Policy;
   end Set_Paste_Conflict_Policy;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is
   begin
      if Index <= Natural (Model.Paste_Conflict_Overrides_Value.Length) then
         Model.Paste_Conflict_Overrides_Value.Replace_Element (Index, Decision);
      end if;
   end Set_Paste_Conflict_Override;

   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Paste_Conflict_Index_Value := Index;
   end Set_Paste_Conflict_Index;

   procedure Clear_Paste_Conflict
     (Model : in out Window_Model) is
   begin
      Model.Paste_Conflict_Active_Value := False;
      Model.Paste_Conflict_Items_Value.Clear;
      Model.Paste_Conflict_Existing_Value.Clear;
      Model.Paste_Conflict_Overrides_Value.Clear;
      Model.Paste_Conflict_Policy_Value := Files.Paste.Policy_Ask;
      Model.Paste_Conflict_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Conflict_Index_Value := 0;
      Model.Paste_Conflict_Apply_All_Value := False;
      Model.Paste_Conflict_Clears_Clip_Val := True;
   end Clear_Paste_Conflict;

   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;

      Model.Paste_Exec_Active_Value := True;
      Model.Paste_Exec_Actions_Value := Actions;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := Writes;
      Model.Paste_Exec_Mode_Value := Mode;
      Model.Paste_Exec_Clears_Clip_Value := Clear_Clipboard;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
   end Begin_Paste_Execution;

   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Active_Value;
   end Paste_Execution_Is_Active;

   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Done_Value;
   end Paste_Execution_Done;

   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Total_Value;
   end Paste_Execution_Total;

   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_Current_Value);
   end Paste_Execution_Current_Name;

   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Exec_Mode_Value;
   end Paste_Execution_Mode;

   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Clears_Clip_Value;
   end Paste_Execution_Clears_Clipboard;

   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Cancelled_Value;
   end Paste_Execution_Cancelled;

   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Cursor_Value;
   end Paste_Execution_Cursor;

   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Paste_Exec_Actions_Value.Length);
   end Paste_Execution_Action_Count;

   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is
   begin
      return Model.Paste_Exec_Actions_Value.Element (Index);
   end Paste_Execution_Action;

   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Undo_From_Value;
   end Paste_Execution_Undo_From;

   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Undo_To_Value;
   end Paste_Execution_Undo_To;

   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_First_Dest_Value);
   end Paste_Execution_First_Dest;

   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model) is
   begin
      Model.Paste_Exec_Cursor_Value := Model.Paste_Exec_Cursor_Value + 1;
   end Skip_Paste_Execution_Action;

   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String) is
   begin
      Model.Paste_Exec_Cursor_Value := Model.Paste_Exec_Cursor_Value + 1;
      Model.Paste_Exec_Done_Value := Model.Paste_Exec_Done_Value + 1;
      Model.Paste_Exec_Current_Value := To_Unbounded_String (Name);
      if Length (Model.Paste_Exec_First_Dest_Value) = 0 then
         Model.Paste_Exec_First_Dest_Value := Dest_Path;
      end if;
      Model.Paste_Exec_Undo_From_Value.Append (Dest_Path);
      Model.Paste_Exec_Undo_To_Value.Append (Source_Path);
   end Record_Paste_Execution_Write;

   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Paste_Exec_Cancelled_Value := True;
   end Cancel_Paste_Execution;

   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Paste_Exec_Active_Value := False;
      Model.Paste_Exec_Actions_Value.Clear;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := 0;
      Model.Paste_Exec_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Exec_Clears_Clip_Value := True;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
   end Clear_Paste_Execution;

   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result) is
   begin
      Model.Folder_Sizes.Include (To_Unbounded_String (Path), Value);
   end Set_Folder_Size;

   procedure Clear_Folder_Size
     (Model : in out Window_Model) is
   begin
      Model.Folder_Sizes.Clear;
   end Clear_Folder_Size;

   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model) is
      use type Files.Types.Item_Kind;
      Kept : Folder_Size_Maps.Map;
   begin
      --  Rebuild the cache keeping only entries for directories still selected.
      for Item of Selected_Items (Model) loop
         if Item.Kind = Files.Types.Directory_Item
           and then Model.Folder_Sizes.Contains (Item.Full_Path)
         then
            Kept.Include (Item.Full_Path, Model.Folder_Sizes.Element (Item.Full_Path));
         end if;
      end loop;
      Model.Folder_Sizes := Kept;
   end Prune_Folder_Sizes_To_Selection;

   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean is
   begin
      return Model.Folder_Sizes.Contains (To_Unbounded_String (Path));
   end Folder_Size_Cached_For;

   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result is
      Key : constant UString := To_Unbounded_String (Path);
   begin
      if Model.Folder_Sizes.Contains (Key) then
         return Model.Folder_Sizes.Element (Key);
      else
         return (others => <>);
      end if;
   end Folder_Size_Value;

   function Is_Selected_Directory
     (Model : Window_Model;
      Path  : String)
      return Boolean is
      use type Files.Types.Item_Kind;
   begin
      for Item of Selected_Items (Model) loop
         if Item.Kind = Files.Types.Directory_Item
           and then To_String (Item.Full_Path) = Path
         then
            return True;
         end if;
      end loop;
      return False;
   end Is_Selected_Directory;

   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0) is
   begin
      Model.Context_Menu_Open_Value := True;
      Model.Context_Menu_X_Value := X;
      Model.Context_Menu_Y_Value := Y;
      Model.Context_Menu_Target_Value := Target;
      Model.Context_Menu_Item_Index_Value := Item_Index;
   end Open_Context_Menu;

   procedure Close_Context_Menu
     (Model : in out Window_Model) is
   begin
      Model.Context_Menu_Open_Value := False;
      Model.Context_Menu_Target_Value := Context_Menu_None;
      Model.Context_Menu_Item_Index_Value := 0;
   end Close_Context_Menu;

   function Context_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Context_Menu_Open_Value;
   end Context_Menu_Is_Open;

   function Context_Menu_X
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_X_Value;
   end Context_Menu_X;

   function Context_Menu_Y
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_Y_Value;
   end Context_Menu_Y;

   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target is
   begin
      return Model.Context_Menu_Target_Value;
   end Context_Menu_Target_Of;

   function Context_Menu_Item_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_Item_Index_Value;
   end Context_Menu_Item_Index;

end Files.Model;
