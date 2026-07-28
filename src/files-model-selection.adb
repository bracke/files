with Files.Model.Support;

package body Files.Model.Selection is
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Select_Visible_Internal (Model, Visible_Index);
   end Select_Visible;

   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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

   procedure Clear_Selection
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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

   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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

   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target is
   begin
      return Model.Focus_Value;
   end Focus;

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

end Files.Model.Selection;
