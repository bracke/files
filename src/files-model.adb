with Ada.Calendar;
with Ada.Strings.Unbounded;

with Files.UTF8;

package body Files.Model is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Navigation_Direction;

   Temporary_Item_Index : constant Natural := Natural'Last;

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
      if Model.Rename_Active
        and then not (Model.Temporary_Active and then Model.Rename_Item_Index = 0)
        and then
          (Selected_Count (Model) /= 1
           or else Effective_Selected_Item_Index (Model) /= Model.Rename_Item_Index)
      then
         Model.Rename_Active := False;
         Model.Rename_Item_Index := 0;
         Model.Rename_Value := Null_Unbounded_String;
         Model.Rename_Cursor := 0;
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
      Model.Focus_Value := Files.Types.Focus_None;
      Model.Path_Input_Value := To_Unbounded_String (Directory_Path);
      Model.Path_Input_Cursor := Directory_Path'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Info_Pane_Open := False;
      Model.Main_View_Scroll := 0;
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Cursor := 0;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Rename_Active := False;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := Null_Unbounded_String;
      Model.Rename_Cursor := 0;
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
   end Select_Sort_Field;

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
   end Clear_Filter;

   procedure Select_Visible
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
   end Select_Visible;

   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
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
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
   end Clear_Overlay_State_For_Edit;

   procedure Clear_Selection
     (Model : in out Window_Model) is
   begin
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Clear_Selection;

   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction)
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
         when Files.Types.Move_Left =>
            if Current = 1 then
               Next := Count;
            else
               Next := Current - 1;
            end if;
         when Files.Types.Move_Right =>
            if Current = Count then
               Next := 1;
            else
               Next := Current + 1;
            end if;
         when Files.Types.Move_Up =>
            if Current = 1 then
               Next := Count;
            elsif Current > Stride then
               Next := Current - Stride;
            else
               Next := Last_In_Column (Positive (Current));
            end if;
         when Files.Types.Move_Down =>
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
      if Current_Path (Model) /= Directory_Path then
         Model.Back_History.Append (Model.Current_Path_Value);
         Model.Forward_History.Clear;
      end if;

      Model.Current_Path_Value := To_Unbounded_String (Directory_Path);
      Model.Items := Items;
      Model.Directory_Signature := Signature_From_Items (Directory_Path, Items);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Path_Input_Value := To_Unbounded_String (Directory_Path);
      Model.Path_Input_Cursor := Directory_Path'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Rename_Active := False;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := Null_Unbounded_String;
      Model.Rename_Cursor := 0;
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
      Model.Focus_Value := Files.Types.Focus_None;
   end Navigate_To;

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
      Model.Forward_History.Append (Model.Current_Path_Value);
      Model.Current_Path_Value := Previous;
      Model.Path_Input_Value := Previous;
      Model.Path_Input_Cursor := Length (Previous);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Rename_Active := False;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := Null_Unbounded_String;
      Model.Rename_Cursor := 0;
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
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
      Model.Back_History.Append (Model.Current_Path_Value);
      Model.Current_Path_Value := Next;
      Model.Path_Input_Value := Next;
      Model.Path_Input_Cursor := Length (Next);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Rename_Active := False;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := Null_Unbounded_String;
      Model.Rename_Cursor := 0;
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
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
      Model.Focus_Value := Files.Types.Focus_Path_Input;
      Model.Path_Input_Value := Model.Current_Path_Value;
      Model.Path_Input_Cursor := Length (Model.Path_Input_Value);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
   end Focus_Path_Input;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is
   begin
      Model.Focus_Value := Files.Types.Focus_Filter_Input;
      Model.Filter_Cursor := Length (Model.Filter_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
   end Focus_Filter_Input;

   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model) is
   begin
      if Model.Command_Palette_Open then
         Model.Focus_Value := Files.Types.Focus_Command_Palette;
      end if;
   end Focus_Command_Palette_Input;

   procedure Focus_Rename_Input
     (Model : in out Window_Model) is
   begin
      if Model.Rename_Active then
         Model.Focus_Value := Files.Types.Focus_Rename_Input;
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Model.Command_Palette_Query := Null_Unbounded_String;
         Model.Command_Palette_Selected := 0;
         Model.Command_Palette_Offset := 0;
         Model.Command_Palette_Cursor := 0;
      end if;
   end Focus_Rename_Input;

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
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
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
      Direction : Files.Types.Navigation_Direction)
   is
      Count   : constant Natural := Root_Count (Model);
      Current : constant Natural := Root_Selected_Index (Model);
   begin
      if not Model.Root_Selector_Open or else Count = 0 then
         Model.Root_Selected := 0;
      elsif Current = 0 then
         Model.Root_Selected := 1;
      elsif Direction = Files.Types.Move_Up or else Direction = Files.Types.Move_Left then
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
            return Length (Model.Rename_Value);
         when Files.Types.Focus_Command_Palette =>
            return Length (Model.Command_Palette_Query);
         when Files.Types.Focus_Settings_Input =>
            return Settings_Field_Text (Model)'Length;
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
            return To_String (Model.Rename_Value);
         when Files.Types.Focus_Command_Palette =>
            return To_String (Model.Command_Palette_Query);
         when Files.Types.Focus_Settings_Input =>
            return Settings_Field_Text (Model);
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
            return Text_Boundary_At_Or_Before (To_String (Model.Rename_Value), Model.Rename_Cursor);
         when Files.Types.Focus_Command_Palette =>
            return Text_Boundary_At_Or_Before (To_String (Model.Command_Palette_Query), Model.Command_Palette_Cursor);
         when Files.Types.Focus_Settings_Input =>
            return Text_Boundary_At_Or_Before (Settings_Field_Text (Model), Model.Settings_Field_Cursor);
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
            Model.Rename_Cursor := Clamped;
         when Files.Types.Focus_Command_Palette =>
            Model.Command_Palette_Cursor := Clamped;
         when Files.Types.Focus_Settings_Input =>
            Model.Settings_Field_Cursor := Clamped;
         when Files.Types.Focus_None =>
            null;
      end case;
   end Set_Text_Cursor_Position;

   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction)
   is
      Cursor : constant Natural := Text_Cursor_Position (Model);
   begin
      if Direction = Files.Types.Move_Left or else Direction = Files.Types.Move_Up then
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

      if Model.Temporary_Active and then Model.Rename_Active and then Model.Rename_Item_Index = 0 then
         Cancel_Create_File (Model);
      elsif Model.Rename_Active then
         Model.Rename_Active := False;
         Model.Rename_Item_Index := 0;
         Model.Rename_Value := Null_Unbounded_String;
         Model.Rename_Cursor := 0;
      end if;

      Model.Focus_Value := Files.Types.Focus_None;
   end Cancel_Focus_Or_Edit;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is
   begin
      Model.Info_Pane_Open := not Model.Info_Pane_Open;
      Model.Info_Pane_Scroll := 0;
   end Toggle_Info_Pane;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Info_Pane_Open;
   end Info_Pane_Is_Open;

   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is
   begin
      Model.Settings_Pane_Open := not Model.Settings_Pane_Open;
      Model.Settings_Pane_Scroll := 0;
      if Model.Settings_Pane_Open then
         Clear_Edit_State (Model);
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Model.Command_Palette_Query := Null_Unbounded_String;
         Model.Command_Palette_Selected := 0;
         Model.Command_Palette_Offset := 0;
         Model.Command_Palette_Cursor := 0;
         Model.Settings_Field := 1;
         Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
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
      Draft : Files.Settings.Settings_Draft) is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Pane_Open := True;
      Model.Settings_Pane_Scroll := 0;
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
      Model.Settings_Field := 1;
      Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
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
      Draft : Files.Settings.Settings_Draft) is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Field_Cursor := Natural'Min (Model.Settings_Field_Cursor, Settings_Field_Text (Model)'Length);
   end Set_Settings_Draft;

   function Settings_Field_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Settings_Field;
   end Settings_Field_Index;

   procedure Set_Settings_Field_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      if Index = 0 then
         Model.Settings_Field := 1;
      elsif Index > 13 then
         Model.Settings_Field := 13;
      else
         Model.Settings_Field := Index;
      end if;
      Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Set_Settings_Field_Index;

   procedure Move_Settings_Field
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction) is
   begin
      case Direction is
         when Files.Types.Move_Left | Files.Types.Move_Up =>
            Set_Settings_Field_Index (Model, (if Model.Settings_Field <= 1 then 13 else Model.Settings_Field - 1));
         when Files.Types.Move_Right | Files.Types.Move_Down =>
            Set_Settings_Field_Index (Model, (if Model.Settings_Field >= 13 then 1 else Model.Settings_Field + 1));
      end case;
   end Move_Settings_Field;

   procedure Move_Settings_Entry
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction)
   is
      Draft : Files.Settings.Settings_Draft := Model.Settings_Draft_Value;

      procedure Select_Filetype (Index : Natural) is
      begin
         Draft.Filetype_Index := Index;
         if Index > 0
           and then Index <= Pair_Count (Draft.Filetype_Keys, Draft.Filetype_Values)
         then
            Draft.Filetype_Extension := Draft.Filetype_Keys.Element (Index);
            Draft.Filetype_Value := Draft.Filetype_Values.Element (Index);
         end if;
      end Select_Filetype;

      procedure Select_Icon (Index : Natural) is
      begin
         Draft.Icon_Index := Index;
         if Index > 0
           and then Index <= Pair_Count (Draft.Icon_Keys, Draft.Icon_Values)
         then
            Draft.Icon_Filetype := Draft.Icon_Keys.Element (Index);
            Draft.Icon_Value := Draft.Icon_Values.Element (Index);
         end if;
      end Select_Icon;

      procedure Select_Action (Index : Natural) is
      begin
         Draft.Open_Action_Index := Index;
         if Index > 0
           and then Index <= Pair_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands)
         then
            Draft.Open_Action_Token := Draft.Open_Action_Keys.Element (Index);
            Draft.Open_Action_Command := Draft.Open_Action_Commands.Element (Index);
         end if;
      end Select_Action;

      function Next_Index
        (Current : Natural;
         Count   : Natural)
         return Natural is
      begin
         if Count = 0 then
            return 0;
         elsif Direction = Files.Types.Move_Left or else Direction = Files.Types.Move_Up then
            return (if Current <= 1 then Count else Current - 1);
         else
            return (if Current >= Count then 1 else Current + 1);
         end if;
      end Next_Index;
   begin
      case Model.Settings_Field is
         when 8 | 9 =>
            Select_Filetype
              (Next_Index
                 (Draft.Filetype_Index,
                  Pair_Count (Draft.Filetype_Keys, Draft.Filetype_Values)));
         when 10 | 11 =>
            Select_Icon (Next_Index (Draft.Icon_Index, Pair_Count (Draft.Icon_Keys, Draft.Icon_Values)));
         when 12 | 13 =>
            Select_Action
              (Next_Index
                 (Draft.Open_Action_Index,
                  Pair_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands)));
         when others =>
            return;
      end case;

      Model.Settings_Draft_Value := Draft;
      Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Move_Settings_Entry;

   procedure Add_Settings_Entry
     (Model : in out Window_Model)
   is
      Draft : Files.Settings.Settings_Draft := Model.Settings_Draft_Value;
      Edited : Boolean := True;
   begin
      case Model.Settings_Field is
         when 8 | 9 =>
            Draft.Filetype_Keys.Append (Null_Unbounded_String);
            Draft.Filetype_Values.Append (Null_Unbounded_String);
            Draft.Filetype_Index := Natural (Draft.Filetype_Keys.Length);
            Draft.Filetype_Extension := Null_Unbounded_String;
            Draft.Filetype_Value := Null_Unbounded_String;
            Model.Settings_Field := 8;
         when 10 | 11 =>
            Draft.Icon_Keys.Append (Null_Unbounded_String);
            Draft.Icon_Values.Append (Null_Unbounded_String);
            Draft.Icon_Index := Natural (Draft.Icon_Keys.Length);
            Draft.Icon_Filetype := Null_Unbounded_String;
            Draft.Icon_Value := Null_Unbounded_String;
            Model.Settings_Field := 10;
         when 12 | 13 =>
            Draft.Open_Action_Keys.Append (Null_Unbounded_String);
            Draft.Open_Action_Commands.Append (Null_Unbounded_String);
            Draft.Open_Action_Index := Natural (Draft.Open_Action_Keys.Length);
            Draft.Open_Action_Token := Null_Unbounded_String;
            Draft.Open_Action_Command := Null_Unbounded_String;
            Model.Settings_Field := 12;
         when others =>
            Edited := False;
      end case;

      if Edited then
         Model.Settings_Draft_Value := Draft;
         Mark_Settings_Draft_Edited (Model);
         Model.Settings_Field_Cursor := 0;
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      end if;
   end Add_Settings_Entry;

   procedure Remove_Settings_Entry
     (Model : in out Window_Model)
   is
      Draft : Files.Settings.Settings_Draft := Model.Settings_Draft_Value;
      Edited : Boolean := True;

      function Clamped_After_Remove
        (Index : Natural;
         Count : Natural)
         return Natural is
      begin
         if Count = 0 then
            return 0;
         elsif Index = 0 then
            return 1;
         else
            return Natural'Min (Index, Count);
         end if;
      end Clamped_After_Remove;

      procedure Delete_If_Present
        (Values : in out Files.Types.String_Vectors.Vector;
         Index  : Natural) is
      begin
         if Index > 0 and then Index <= Natural (Values.Length) then
            Values.Delete (Index);
         end if;
      end Delete_If_Present;

   begin
      case Model.Settings_Field is
         when 8 | 9 =>
            if Draft.Filetype_Index = 0
              or else
                (Draft.Filetype_Index > Natural (Draft.Filetype_Keys.Length)
                 and then Draft.Filetype_Index > Natural (Draft.Filetype_Values.Length))
            then
               return;
            end if;
            Delete_If_Present (Draft.Filetype_Keys, Draft.Filetype_Index);
            Delete_If_Present (Draft.Filetype_Values, Draft.Filetype_Index);
            Draft.Filetype_Index :=
              Clamped_After_Remove
                (Draft.Filetype_Index,
                 Pair_Count (Draft.Filetype_Keys, Draft.Filetype_Values));
            if Draft.Filetype_Index = 0 then
               Draft.Filetype_Extension := Null_Unbounded_String;
               Draft.Filetype_Value := Null_Unbounded_String;
            else
               Draft.Filetype_Extension := Draft.Filetype_Keys.Element (Draft.Filetype_Index);
               Draft.Filetype_Value := Draft.Filetype_Values.Element (Draft.Filetype_Index);
            end if;
            Model.Settings_Field := 8;
         when 10 | 11 =>
            if Draft.Icon_Index = 0
              or else
                (Draft.Icon_Index > Natural (Draft.Icon_Keys.Length)
                 and then Draft.Icon_Index > Natural (Draft.Icon_Values.Length))
            then
               return;
            end if;
            Delete_If_Present (Draft.Icon_Keys, Draft.Icon_Index);
            Delete_If_Present (Draft.Icon_Values, Draft.Icon_Index);
            Draft.Icon_Index :=
              Clamped_After_Remove
                (Draft.Icon_Index,
                 Pair_Count (Draft.Icon_Keys, Draft.Icon_Values));
            if Draft.Icon_Index = 0 then
               Draft.Icon_Filetype := Null_Unbounded_String;
               Draft.Icon_Value := Null_Unbounded_String;
            else
               Draft.Icon_Filetype := Draft.Icon_Keys.Element (Draft.Icon_Index);
               Draft.Icon_Value := Draft.Icon_Values.Element (Draft.Icon_Index);
            end if;
            Model.Settings_Field := 10;
         when 12 | 13 =>
            if Draft.Open_Action_Index = 0
              or else
                (Draft.Open_Action_Index > Natural (Draft.Open_Action_Keys.Length)
                 and then Draft.Open_Action_Index > Natural (Draft.Open_Action_Commands.Length))
            then
               return;
            end if;
            Delete_If_Present (Draft.Open_Action_Keys, Draft.Open_Action_Index);
            Delete_If_Present (Draft.Open_Action_Commands, Draft.Open_Action_Index);
            Draft.Open_Action_Index :=
              Clamped_After_Remove
                (Draft.Open_Action_Index,
                 Pair_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands));
            if Draft.Open_Action_Index = 0 then
               Draft.Open_Action_Token := Null_Unbounded_String;
               Draft.Open_Action_Command := Null_Unbounded_String;
            else
               Draft.Open_Action_Token := Draft.Open_Action_Keys.Element (Draft.Open_Action_Index);
               Draft.Open_Action_Command := Draft.Open_Action_Commands.Element (Draft.Open_Action_Index);
            end if;
            Model.Settings_Field := 12;
         when others =>
            Edited := False;
      end case;

      if Edited then
         Model.Settings_Draft_Value := Draft;
         Mark_Settings_Draft_Edited (Model);
         Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      end if;
   end Remove_Settings_Entry;

   function Settings_Field_Text
     (Model : Window_Model)
      return String is
   begin
      case Model.Settings_Field is
         when 1 =>
            return To_String (Model.Settings_Draft_Value.Default_View_Mode);
         when 2 =>
            return To_String (Model.Settings_Draft_Value.Show_Hidden_Files);
         when 3 =>
            return To_String (Model.Settings_Draft_Value.Sort_Field_Value);
         when 4 =>
            return To_String (Model.Settings_Draft_Value.Sort_Ascending);
         when 5 =>
            return To_String (Model.Settings_Draft_Value.High_Contrast_Theme);
         when 6 =>
            return To_String (Model.Settings_Draft_Value.Icon_Theme_Name);
         when 7 =>
            return To_String (Model.Settings_Draft_Value.Font_Pixel_Size);
         when 8 =>
            return To_String (Model.Settings_Draft_Value.Filetype_Extension);
         when 9 =>
            return To_String (Model.Settings_Draft_Value.Filetype_Value);
         when 10 =>
            return To_String (Model.Settings_Draft_Value.Icon_Filetype);
         when 11 =>
            return To_String (Model.Settings_Draft_Value.Icon_Value);
         when 12 =>
            return To_String (Model.Settings_Draft_Value.Open_Action_Token);
         when 13 =>
            return To_String (Model.Settings_Draft_Value.Open_Action_Command);
         when others =>
            return "";
      end case;
   end Settings_Field_Text;

   procedure Set_Settings_Field_Text
     (Model : in out Window_Model;
      Text  : String)
   is
      Edited : Boolean := True;

      function Replace_List_Value
        (Values : in out Files.Types.String_Vectors.Vector;
         Index  : Natural;
         Value  : String)
         return Boolean is
      begin
         if Index > 0 and then Index <= Natural (Values.Length) then
            Values.Replace_Element (Index, To_Unbounded_String (Value));
            return True;
         end if;

         return False;
      end Replace_List_Value;
   begin
      case Model.Settings_Field is
         when 1 =>
            Model.Settings_Draft_Value.Default_View_Mode := To_Unbounded_String (Text);
         when 2 =>
            Model.Settings_Draft_Value.Show_Hidden_Files := To_Unbounded_String (Text);
         when 3 =>
            Model.Settings_Draft_Value.Sort_Field_Value := To_Unbounded_String (Text);
         when 4 =>
            Model.Settings_Draft_Value.Sort_Ascending := To_Unbounded_String (Text);
         when 5 =>
            Model.Settings_Draft_Value.High_Contrast_Theme := To_Unbounded_String (Text);
         when 6 =>
            Model.Settings_Draft_Value.Icon_Theme_Name := To_Unbounded_String (Text);
         when 7 =>
            Model.Settings_Draft_Value.Font_Pixel_Size := To_Unbounded_String (Text);
         when 8 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Filetype_Keys,
                  Model.Settings_Draft_Value.Filetype_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Filetype_Extension := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when 9 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Filetype_Values,
                  Model.Settings_Draft_Value.Filetype_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Filetype_Value := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when 10 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Icon_Keys,
                  Model.Settings_Draft_Value.Icon_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Icon_Filetype := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when 11 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Icon_Values,
                  Model.Settings_Draft_Value.Icon_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Icon_Value := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when 12 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Open_Action_Keys,
                  Model.Settings_Draft_Value.Open_Action_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Open_Action_Token := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when 13 =>
            if Replace_List_Value
                 (Model.Settings_Draft_Value.Open_Action_Commands,
                  Model.Settings_Draft_Value.Open_Action_Index,
                  Text)
            then
               Model.Settings_Draft_Value.Open_Action_Command := To_Unbounded_String (Text);
            else
               Edited := False;
            end if;
         when others =>
            Edited := False;
      end case;
      if Edited then
         Mark_Settings_Draft_Edited (Model);
      end if;
      Model.Settings_Field_Cursor := Settings_Field_Text (Model)'Length;
   end Set_Settings_Field_Text;

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

   procedure Scroll_Settings_Pane
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      if not Model.Settings_Pane_Open or else Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Settings_Pane_Scroll then
               Model.Settings_Pane_Scroll := 0;
            else
               Model.Settings_Pane_Scroll := Model.Settings_Pane_Scroll - Step;
            end if;
         end;
      else
         Model.Settings_Pane_Scroll :=
           Saturating_Add (Model.Settings_Pane_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Settings_Pane;

   function Settings_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Settings_Pane_Scroll;
   end Settings_Pane_Scroll_Lines;

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

   procedure Open_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := True;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
      Model.Focus_Value := Files.Types.Focus_Command_Palette;
   end Open_Command_Palette;

   procedure Close_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
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

   procedure Set_Command_Palette_Query
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Command_Palette_Query := To_Unbounded_String (Text);
      Model.Command_Palette_Cursor := Text'Length;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
   end Set_Command_Palette_Query;

   function Command_Palette_Query
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Command_Palette_Query);
   end Command_Palette_Query;

   procedure Set_Command_Palette_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      Model.Command_Palette_Selected := Index;
   end Set_Command_Palette_Selected_Index;

   function Command_Palette_Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Command_Palette_Selected;
   end Command_Palette_Selected_Index;

   procedure Set_Command_Palette_Result_Offset
     (Model  : in out Window_Model;
      Offset : Natural) is
   begin
      Model.Command_Palette_Offset := Offset;
   end Set_Command_Palette_Result_Offset;

   function Command_Palette_Result_Offset
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Command_Palette_Offset;
   end Command_Palette_Result_Offset;

   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is
   begin
      return Selected_Count (Model) = 1 and then not Selected_Item_Is_Temporary (Model);
   end Rename_Is_Enabled;

   function Rename_Behavior return Rename_Policy is
   begin
      return
        (Single_Item_Only       => True,
         Synchronized_Multi     => False,
         Atomic_Multi_Rename    => False,
         Requires_One_Selection => True);
   end Rename_Behavior;

   procedure Toggle_Rename
     (Model : in out Window_Model) is
   begin
      if Model.Rename_Active then
         if Model.Temporary_Active and then Model.Rename_Item_Index = 0 then
            Cancel_Create_File (Model);
            if Model.Focus_Value = Files.Types.Focus_Rename_Input then
               Model.Focus_Value := Files.Types.Focus_None;
            end if;
            return;
         end if;

         Model.Rename_Active := False;
         Model.Rename_Item_Index := 0;
         Model.Rename_Value := Null_Unbounded_String;
         Model.Rename_Cursor := 0;
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      elsif Rename_Is_Enabled (Model) then
         Clear_Overlay_State_For_Edit (Model);
         Model.Rename_Active := True;
         Model.Rename_Item_Index := Model.Selected_Item_Index;
         Model.Rename_Value := To_Unbounded_String (Selected_Name (Model));
         Model.Rename_Cursor := Length (Model.Rename_Value);
         Model.Focus_Value := Files.Types.Focus_Rename_Input;
      end if;
   end Toggle_Rename;

   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Rename_Active;
   end Rename_Is_Active;

   function Rename_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Rename_Value);
   end Rename_Text;

   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      if Model.Rename_Active then
         Model.Rename_Value := To_Unbounded_String (Text);
         Model.Rename_Cursor := Text'Length;
         if Model.Temporary_Active and then Model.Rename_Item_Index = 0 then
            Model.Temporary_Name_Value := To_Unbounded_String (Text);
         end if;
      end if;
   end Set_Rename_Text;

   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is
   begin
      if not Rename_Is_Enabled (Model) then
         return;
      end if;

      Clear_Overlay_State_For_Edit (Model);
      Model.Rename_Active := True;
      Model.Rename_Item_Index := Model.Selected_Item_Index;
      Model.Rename_Value := To_Unbounded_String (Text);
      Model.Rename_Cursor := Text'Length;
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
      Model.Rename_Active := True;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := To_Unbounded_String (Name);
      Model.Rename_Cursor := Name'Length;
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
      if Model.Rename_Active and then Model.Rename_Item_Index = 0 then
         Model.Rename_Active := False;
         Model.Rename_Value := Null_Unbounded_String;
         Model.Rename_Cursor := 0;
      end if;
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Cancel_Create_File;

   procedure Clear_Edit_State
     (Model : in out Window_Model) is
   begin
      Model.Rename_Active := False;
      Model.Rename_Item_Index := 0;
      Model.Rename_Value := Null_Unbounded_String;
      Model.Rename_Cursor := 0;
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
         Model.Rename_Active := False;
         Model.Rename_Item_Index := 0;
         Model.Rename_Value := Null_Unbounded_String;
         Model.Rename_Cursor := 0;
      end if;
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Query := Null_Unbounded_String;
      Model.Command_Palette_Selected := 0;
      Model.Command_Palette_Offset := 0;
      Model.Command_Palette_Cursor := 0;
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Items := Items;
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
