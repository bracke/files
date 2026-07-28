with Ada.Calendar;

with Files.Localization;
with Files.Settings_Form;
with Files.UTF8;

package body Files.Model.Support is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.Types.Focus_Target;

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

   procedure Reset_Rename_State
     (Model : in out Window_Model) is
   begin
      Model.Rename_Active := False;
      Model.Rename_Fields.Clear;
   end Reset_Rename_State;

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

   procedure Clear_Overlay_State_For_Edit
     (Model : in out Window_Model) is
   begin
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Clear_Overlay_State_For_Edit;

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

   function First_Codepoint (Text : String) return String is
      Unit : constant Natural := Files.UTF8.Next_Boundary (Text, 0);
   begin
      if Text = "" or else Unit = 0 then
         return "";
      end if;

      return Text (Text'First .. Text'First + Unit - 1);
   end First_Codepoint;

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

   procedure Reset_Settings_Panel (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Reset (Model.Settings_Panel_View);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Files.Settings_Form.Fields (Model));
   end Reset_Settings_Panel;

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

end Files.Model.Support;
