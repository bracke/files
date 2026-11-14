with Files.Type_Ahead;
with Guikit.Utf8.Editing;
with Files.Model.Support;

package body Files.Model.Selection is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  A run is only fed to type-ahead when every byte is a printable glyph.
   --  Control bytes below the space and the DEL byte never start a prefix.
   --
   --  @param Text Candidate input run.
   --  @return True when every byte is printable.
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
   --
   --  @param Text Candidate input run.
   --  @return True when Text is one repeated codepoint.
   function Is_Repeated_Single_Codepoint (Text : String) return Boolean is
      Lower : constant String := Files.Types.To_Lower (Text);
      First : Natural;
      Cursor : Natural := 0;
      Unit   : Natural;
   begin
      if Lower = "" then
         return False;
      end if;

      First := Guikit.Utf8.Editing.Next_Boundary (Lower, 0);
      declare
         Head : constant String := Lower (Lower'First .. Lower'First + First - 1);
      begin
         Cursor := First;
         while Cursor < Lower'Length loop
            Unit := Guikit.Utf8.Editing.Next_Boundary (Lower, Cursor) - Cursor;
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
   --
   --  @param Text Source text.
   --  @return The leading codepoint's bytes, or "" when Text is empty.
   function First_Codepoint (Text : String) return String is
      Unit : constant Natural := Guikit.Utf8.Editing.Next_Boundary (Text, 0);
   begin
      if Text = "" or else Unit = 0 then
         return "";
      end if;

      return Text (Text'First .. Text'First + Unit - 1);
   end First_Codepoint;

   --  Single-select a visible item without disturbing the type-ahead prefix.
   --  Type-ahead selection uses this so its own selection jumps do not clear the
   --  prefix it is accumulating; every other selection path goes through the
   --  public Select_Visible, which resets the prefix first.
   --
   --  @param Model Model to update.
   --  @param Visible_Index 1-based visible row to select.
   procedure Select_Visible_Internal
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : constant Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      Touch_Selection (Model);
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

   procedure Reset_Type_Ahead
     (Model : in out Window_Model)
     renames Files.Model.Support.Reset_Type_Ahead;

   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String is
     (To_String (Model.Type_Ahead_Buffer_Value));

   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean)
   is
      Combined : constant String := To_String (Model.Type_Ahead_Buffer_Value) & Text;
      Current  : constant Natural := Selected_Index (Model);
      Visible  : Files.Types.String_Vectors.Vector;
      Prefix   : Unbounded_String;
      Start    : Natural;
      Target   : Natural;
   begin
      Touch (Model);
      Matched := False;

      if not Is_Printable_Run (Text) then
         return;
      end if;

      --  Snapshot the visible projection in display order so the pure matcher's
      --  returned index maps straight back to a visible index. Temporary
      --  create-file items are never type-ahead targets.
      declare
         procedure Add (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
            pragma Unreferenced (Selected);
         begin
            Visible.Append (if Item_Index /= 0 then Item.Name else Null_Unbounded_String);
         end Add;
      begin
         Visible.Reserve_Capacity (Ada.Containers."+" (Model.Items.Length, 1));
         For_Each_Visible_Row (Model, Add'Access);
      end;

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

   --  Make the item at Visible_Index the Range_Anchor (none past the end).
   procedure Note_Range_Anchor
     (Model         : in out Window_Model;
      Visible_Index : Positive) is
   begin
      Model.Range_Anchor_Path :=
        (if Natural (Visible_Index) <= Visible_Count (Model)
         then Visible_Item (Model, Visible_Index).Full_Path
         else Null_Unbounded_String);
   end Note_Range_Anchor;

   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive) is
   begin
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);
      Select_Visible_Internal (Model, Visible_Index);
      Note_Range_Anchor (Model, Visible_Index);
   end Select_Visible;

   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is
      Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
   begin
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);
      if Item_Index = 0
        and then Temporary_Is_Visible (Model)
        and then Visible_Index = Visible_Count (Model)
      then
         Item_Index := Temporary_Item_Index;
      end if;

      if Item_Index = 0 then
         return;
      end if;
      --  The next shift-click ranges from here, whether this selected or not.
      Note_Range_Anchor (Model, Visible_Index);
      if Selection_Contains (Model, Item_Index) then
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

   begin
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);
      if Count = 0
        or else Natural (Anchor_Index) > Count
        or else Natural (Target_Index) > Count
      then
         Clear_Selection (Model);
         return;
      end if;

      --  The range's fixed end stays its anchor, though a cursor move on the
      --  way here (Move_Selection) noted the target as the anchor.
      Note_Range_Anchor (Model, Anchor_Index);
      First := Natural'Min (Natural (Anchor_Index), Natural (Target_Index));
      Last := Natural'Max (Natural (Anchor_Index), Natural (Target_Index));

      Model.Selected_Item_Indexes.Clear;
      declare
         --  Map rows to items in one pass; a per-row scan made a long
         --  shift-click range quadratic.
         Rows : Natural_Vectors.Vector;
         Position : Natural := 0;

         procedure Note (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
            pragma Unreferenced (Item, Selected);
         begin
            Position := Position + 1;
            if Position in First .. Last then
               --  Rows are distinct and the list was cleared, so append directly
               --  rather than pay Add_Selected_Index's duplicate scan.
               Rows.Append (if Item_Index /= 0 then Item_Index else Temporary_Item_Index);
            end if;
         end Note;
      begin
         For_Each_Visible_Row (Model, Note'Access);
         Model.Selected_Item_Indexes := Rows;
      end;

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
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Indexes.Clear;
      Model.Selected_Item_Index := 0;

      if Model.Items.Is_Empty then
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items (Index)) then
            --  The list was cleared and indexes ascend, so each is new.
            Model.Selected_Item_Indexes.Append (Natural (Index));
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
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Range_Anchor_Path := Null_Unbounded_String;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Clear_Selection;

   procedure Invert_Selection
     (Model : in out Window_Model)
   is
      Primary : Natural := 0;
   begin
      Touch_Selection (Model);
      Reset_Type_Ahead (Model);

      if Model.Items.Is_Empty then
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      declare
         --  Rebuild in one pass: visible items flip, hidden ones keep their
         --  state, and the pending create row's marker survives.
         Was_Selected : constant Selection_Flags := Selected_Flags (Model);
         Temporary    : constant Boolean :=
           Model.Selected_Item_Indexes.Contains (Temporary_Item_Index);
      begin
         Model.Selected_Item_Indexes.Clear;
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Item_Is_Visible (Model, Model.Items (Index)) /= Was_Selected (Index) then
               Model.Selected_Item_Indexes.Append (Natural (Index));
            end if;
         end loop;
         if Temporary then
            Model.Selected_Item_Indexes.Append (Temporary_Item_Index);
         end if;
      end;

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
      Touch (Model);
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
      Touch_Selection (Model);
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
      Touch_Selection (Model);
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
      Touch_Selection (Model);
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
      Touch_Selection (Model);
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
      --  Called before every key dispatch; an unconditional bump invalidated
      --  the render cache and forced a full snapshot rebuild per keystroke.
      if Model.Selection_Columns = Columns then
         return;
      end if;
      Touch (Model);
      Model.Selection_Columns := Columns;
   end Set_Selection_Grid_Columns;

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
      return Natural
     renames Files.Model.Support.Selected_Index;

   function Selected_Count
     (Model : Window_Model)
      return Natural
     renames Files.Model.Support.Selected_Count;

   function Selected_Name
     (Model : Window_Model)
      return String
   is
      Item_Index : constant Natural := Effective_Selected_Item_Index (Model);
   begin
      if Selected_Count (Model) = 0 then
         return "";
      elsif Item_Index = Temporary_Item_Index then
         return To_String (Model.Temporary.Name);
      end if;

      return To_String (Model.Items.Element (Positive (Item_Index)).Name);
   end Selected_Name;

   function Selected_Item
     (Model : Window_Model)
      return Files.Items.Directory_Item
     renames Files.Model.Support.Selected_Item;

   function Selected_Items
     (Model : Window_Model;
      Limit : Natural := Natural'Last)
      return Files.Items.Item_Vectors.Vector
     renames Files.Model.Support.Selected_Items;

   procedure For_Each_Selected_Item
     (Model : Window_Model;
      Visit : not null access procedure (Item : Files.Items.Directory_Item))
   is
   begin
      if Selected_Count (Model) = 0 or else Model.Items.Is_Empty then
         return;
      end if;
      declare
         Selected : constant Selection_Flags := Selected_Flags (Model);
      begin
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Selected (Index) then
               Visit (Model.Items (Index));
            end if;
         end loop;
      end;
   end For_Each_Selected_Item;

   procedure Restore_Selection
     (Model        : in out Window_Model;
      Items        : Files.Items.Item_Vectors.Vector;
      Primary_Path : String)
     renames Files.Model.Support.Restore_Selection;

   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean
     renames Files.Model.Support.Selection_Includes_Temporary;

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
               Model.Reveal_Pending := True;
               return True;
            end if;
         end loop;
      end if;

      Reconcile_Rename_With_Selection (Model);
      return False;
   end Select_By_Name;

   procedure Set_Selection_Page_Rows (Model : in out Window_Model; Rows : Positive) is
   begin
      Model.Selection_Page_Rows_Value := Rows;
   end Set_Selection_Page_Rows;

   function Selection_Page_Rows (Model : Window_Model) return Positive is
     (Model.Selection_Page_Rows_Value);

   procedure Select_Visible_Set
     (Model   : in out Window_Model;
      Indexes : Visible_Index_List)
   is
      package Flag_Vectors is new Ada.Containers.Vectors (Positive, Boolean);
      --  Each visible index's item, worked out once (on the heap: a folder
      --  can be too big for the stack).
      Visible_Items : Visible_Index_Lists.Vector;
      Visible_Count : Natural := 0;
      Taken         : Flag_Vectors.Vector := Flag_Vectors.To_Vector (False, Model.Items.Length);
      Temporary_Taken : Boolean := False;
      Chosen        : Natural_Vectors.Vector;
      Primary       : Natural := 0;
   begin
      --  From the cached visible-row map: a marquee drag selects on every
      --  move, and testing each item against the filter again was most of it.
      Support.Ensure_Visible_Map (Model);
      for Index of Model.Visible_Items loop
         Visible_Count := Visible_Count + 1;
         Visible_Items.Append (Index);
      end loop;
      if Temporary_Is_Visible (Model) then
         Visible_Count := Visible_Count + 1;
         Visible_Items.Append (Temporary_Item_Index);
      end if;
      for Visible of Indexes loop
         if Visible <= Visible_Count then
            declare
               Item : constant Natural := Visible_Items (Visible);
            begin
               if Item = Temporary_Item_Index then
                  if not Temporary_Taken then
                     Temporary_Taken := True;
                     Chosen.Append (Item);
                  end if;
                  Primary := Item;
               elsif Item in 1 .. Natural (Taken.Length) then
                  if not Taken (Item) then
                     Taken (Item) := True;
                     Chosen.Append (Item);
                  end if;
                  Primary := Item;
               end if;
            end;
         end if;
      end loop;
      --  A rubber band that has not moved asks for the selection it already
      --  has; changing nothing then leaves the snapshot to be reused.
      if Natural_Vectors."=" (Chosen, Model.Selected_Item_Indexes) and then Primary = Model.Selected_Item_Index then
         return;
      end if;
      Clear_Selection (Model);
      Model.Selected_Item_Indexes := Chosen;
      Model.Selected_Item_Index := Primary;
      Reconcile_Rename_With_Selection (Model);
   end Select_Visible_Set;

   function Range_Anchor
     (Model : Window_Model)
      return Natural
   is
      Anchor : constant Natural :=
        (if Length (Model.Range_Anchor_Path) = 0 then 0
         else Visible_Index_Of (Model, To_String (Model.Range_Anchor_Path)));
   begin
      if Anchor > 0 and then Selected_Count (Model) > 0 then
         return Anchor;
      end if;
      return Selected_Index (Model);
   end Range_Anchor;

   function Selection_Move_Would_Wrap
     (Model     : Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Count   : constant Natural := Visible_Count (Model);
      Current : constant Natural := Selected_Index (Model);
      --  As Move_Selection steps a row.
      Stride  : constant Natural :=
        Natural'Max (1, Natural'Min (Natural (Model.Selection_Columns), Natural'Max (1, Count)));
   begin
      if Count = 0 or else Current = 0 then
         return False;
      end if;
      case Direction is
         when Guikit.Input.Move_Left  => return Current = 1;
         when Guikit.Input.Move_Right => return Current = Count;
         when Guikit.Input.Move_Up    => return Current <= Stride;
         when Guikit.Input.Move_Down  => return Current + Stride > Count;
      end case;
   end Selection_Move_Would_Wrap;

end Files.Model.Selection;
