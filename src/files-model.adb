with Files.Extra_Info;
with Files.Item_Lists;
with Guikit.Layout;
with Guikit.Bidi;
with Guikit.Utf8.Editing;

with Files.Model.Support;

package body Files.Model is

   use Ada.Strings.Unbounded;

   use type Ada.Calendar.Time;
   use type Files.File_System_Types.Path_Status;
   use type Files.UI_Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;
   use type Files.UI_Types.Search_Scope;

   use Files.Model.Support;

   --  Reorder the stored items to match the model's current sort field and
   --  direction. Keyboard navigation walks the stored item order, so it must be
   --  identical to the displayed order the renderer sorts with -- otherwise a
   --  descending sort makes Up/Down move against the visible order. Selection
   --  and rename targets are index-based, so they are re-established by item
   --  identity (full path) after the reorder.
   --
   --  Under a grouping (Sync_Grouping) the sorted items are then stably
   --  partitioned into bands, matching the drawn order.
   --
   --  @param Model Model whose items are re-sorted in place.
   --  @param Field_Sort False to keep the current order and only regroup it,
   --    which does nothing while the items are still in band order.
   --  @param Recency When not empty (with Field_Sort False), the items are
   --    first put back in this path order (the Recent view's recency, which
   --    an earlier grouping partitioned), items it does not name after them
   --    in their current order, and then regrouped.
   procedure Resort_Items
     (Model      : in out Window_Model;
      Field_Sort : Boolean := True;
      Recency    : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector)
     is separate;

   function Scroll_Revision (Model : Window_Model) return Natural is (Model.Scroll_Revision_Value);

   function Rows_Revision (Model : Window_Model) return Natural is (Model.Rows_Revision_Value);

   function Overlay_Revision (Model : Window_Model) return Natural is (Model.Overlay_Revision_Value);

   function Info_Revision (Model : Window_Model) return Natural is (Model.Info_Revision_Value);

   function Selection_Revision (Model : Window_Model) return Natural is (Model.Selection_Revision_Value);

   function Rename_Revision (Model : Window_Model) return Natural is (Model.Rename_Revision_Value);

   function Revision
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Revision_Value;
   end Revision;

   function Settings_Revision
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Settings_Revision_Value;
   end Settings_Revision;

   procedure Note_Settings_Changed
     (Model : in out Window_Model) is
   begin
      Model.Settings_Revision_Value := Bumped (Model.Settings_Revision_Value);
   end Note_Settings_Changed;

   function Listing_Revision
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Listing_Revision_Value;
   end Listing_Revision;

   function View_Incarnation
     (Model : Window_Model)
      return Natural is
   begin
      return Model.View_Incarnation_Value;
   end View_Incarnation;

   procedure Note_Owed_Refresh
     (Model       : in out Window_Model;
      Force       : Boolean;
      Select_Name : String)
   is
      --  A debt for an earlier view is moot: this one starts afresh.
      Earlier : constant Owed_Refresh_State :=
        (if Refresh_Is_Owed (Model) then Model.Owed_Refresh else (others => <>));
   begin
      Model.Owed_Refresh :=
        (Owed        => True,
         Incarnation => Model.View_Incarnation_Value,
         Forced      => Earlier.Forced or else Force,
         Selection   => (if Select_Name /= "" then To_Unbounded_String (Select_Name) else Earlier.Selection));
   end Note_Owed_Refresh;

   function Refresh_Is_Owed
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Owed_Refresh.Owed
        and then Model.Owed_Refresh.Incarnation = Model.View_Incarnation_Value;
   end Refresh_Is_Owed;

   function Owed_Refresh_Force
     (Model : Window_Model)
      return Boolean is
   begin
      return Refresh_Is_Owed (Model) and then Model.Owed_Refresh.Forced;
   end Owed_Refresh_Force;

   function Owed_Refresh_Selection
     (Model : Window_Model)
      return String is
   begin
      return (if Refresh_Is_Owed (Model) then To_String (Model.Owed_Refresh.Selection) else "");
   end Owed_Refresh_Selection;

   procedure Clear_Owed_Refresh
     (Model : in out Window_Model) is
   begin
      Model.Owed_Refresh := (others => <>);
   end Clear_Owed_Refresh;

   --  Every overlay is either the first or another than the first.
   function Input_Owning_Overlay_Is_Open
     (Model : Window_Model)
      return Boolean is
     (Overlay_Is_Open (Model, Input_Overlay'First)
      or else Other_Input_Owning_Overlay_Is_Open (Model, Except => Input_Overlay'First));

   function Overlay_Is_Open
     (Model   : Window_Model;
      Overlay : Input_Overlay)
      return Boolean is
   begin
      case Overlay is
         when Settings_Pane_Overlay   => return Model.Settings_Pane_Open;
         when Command_Palette_Overlay => return Model.Command_Palette.Open;
         when Root_Selector_Overlay   => return Model.Root_Selector.Open;
         when Sort_Menu_Overlay       => return Model.Sort_Menu.Open;
         when Context_Menu_Overlay    => return Model.Context_Menu.Open;
         when Label_Picker_Overlay    => return Model.Label_Picker.Open;
         when Quick_Look_Overlay      => return Model.Quick_Look.Open;
         when Tree_Pick_Overlay       => return Model.Tree_Pick.Mode /= Pick_None;
         when Paste_Conflict_Overlay  => return Model.Paste_Conflict.Active;
         when Foreground_Job_Overlay => return Model.Foreground_Kind /= No_Foreground_Job;
      end case;
   end Overlay_Is_Open;

   function Topmost_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean is
   begin
      for Candidate of Files.UI_Types.Overlay_Stack loop
         if Overlay_Is_Open (Model, Candidate) then
            Overlay := Candidate;
            return True;
         end if;
      end loop;
      Overlay := Files.UI_Types.Overlay_Stack (Files.UI_Types.Overlay_Stack'First);
      return False;
   end Topmost_Overlay;

   function Window_Overlay_Shown (Model : Window_Model; Overlay : Text_Input_Overlay) return Boolean is
   begin
      if not Overlay_Is_Open (Model, Overlay) then
         return False;
      end if;
      --  Nothing above it in Overlay_Stack is open.
      for Candidate of Files.UI_Types.Overlay_Stack loop
         exit when Candidate = Overlay;
         if Overlay_Is_Open (Model, Candidate) then
            return False;
         end if;
      end loop;
      return True;
   end Window_Overlay_Shown;

   function Escape_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean is
     (Topmost_Overlay (Model, Overlay) and then Overlay in Escape_Closable_Overlay);

   function Has_Something_To_Close (Model : Window_Model) return Boolean is
      Overlay : Input_Overlay;
   begin
      return Escape_Overlay (Model, Overlay)
        or else Model.Focus /= Files.UI_Types.Focus_None
        or else Model.Rename.Active
        or else Model.Temporary.Active;
   end Has_Something_To_Close;

   procedure Close_Overlay (Model : in out Window_Model; Overlay : Escape_Closable_Overlay) is
   begin
      case Overlay is
         when Label_Picker_Overlay    => Close_Label_Picker (Model);
         when Context_Menu_Overlay    => Close_Context_Menu (Model);
         when Command_Palette_Overlay => Close_Command_Palette (Model);
         when Root_Selector_Overlay   => Close_Root_Selector (Model);
         when Sort_Menu_Overlay       => Close_Sort_Menu (Model);
         when Quick_Look_Overlay      => Close_Quick_Look (Model);
         --  Cancels the pick, closing the tree when the pick opened it.
         when Tree_Pick_Overlay       => End_Tree_Pick (Model);
         --  Closed the way Escape in the pane closes it; reopening starts a fresh draft.
         when Settings_Pane_Overlay   => Close_Settings_Pane (Model);
      end case;
   end Close_Overlay;

   function Other_Input_Owning_Overlay_Is_Open
     (Model  : Window_Model;
      Except : Input_Overlay)
      return Boolean is
   begin
      for Overlay in Input_Overlay loop
         if Overlay /= Except and then Overlay_Is_Open (Model, Overlay) then
            return True;
         end if;
      end loop;
      return False;
   end Other_Input_Owning_Overlay_Is_Open;

   function Character_Input_Is_Contained
     (Model : Window_Model)
      return Boolean
   is
      Top : Input_Overlay;
   begin
      if not Topmost_Overlay (Model, Top) then
         return False;
      end if;
      case Top is
         when Command_Palette_Overlay =>
            return Model.Focus_Value /= Files.UI_Types.Focus_Command_Palette;
         when Settings_Pane_Overlay =>
            return Model.Focus_Value /= Files.UI_Types.Focus_Settings_Input;
         when Root_Selector_Overlay
            | Sort_Menu_Overlay
            | Context_Menu_Overlay
            | Label_Picker_Overlay
            | Quick_Look_Overlay
            | Tree_Pick_Overlay
            | Paste_Conflict_Overlay
            | Foreground_Job_Overlay =>
            return True;
      end case;
   end Character_Input_Is_Contained;

   --  Every change of directory goes through here: it starts a new view
   --  incarnation. Whether the new directory is the trash takes a disk check,
   --  so it starts out False and Files.Operations settles it, once, through
   --  Set_Current_Is_Trash; the commands and the snapshot then ask without
   --  touching the disk.
   procedure Set_Current_Path
     (Model : in out Window_Model;
      Path  : UString) is
   begin
      Model.Current_Path_Value := Path;
      Model.View_Incarnation_Value := Bumped (Model.View_Incarnation_Value);
      Model.Current_Is_Trash_Value := False;
   end Set_Current_Path;

   procedure Set_Current_Is_Trash
     (Model    : in out Window_Model;
      Is_Trash : Boolean) is
   begin
      if Model.Current_Is_Trash_Value /= Is_Trash then
         Model.Current_Is_Trash_Value := Is_Trash;
         Support.Touch (Model);
      end if;
   end Set_Current_Is_Trash;

   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.Items.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons) is
   begin
      Clear_Folder_Size (Model);
      Support.Touch (Model);
      Support.Touch_Listing (Model);
      Set_Current_Path (Model, To_Unbounded_String (Directory_Path));
      Model.Refresh_Job := Released_Process;
      Model.Home_Path_Value := To_Unbounded_String (Home_Path);
      Model.Items := Items;
      Model.Grouping.Banded := False;
      Model.Directory_Signature := Files.File_System_Types.Unknown_Signature (Directory_Path);
      Model.Filter.Text := Null_Unbounded_String;
      Model.Folded_Filter := Null_Unbounded_String;
      Model.Filter.Cursor := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      --  A model met again (Model is by reference) keeps no typed prefix or
      --  range anchor of the folder it showed before.
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
      Model.Range_Anchor_Path := Null_Unbounded_String;
      Model.Range_Anchor_Item := 0;
      Model.View_Value := Default_View_Mode;
      Model.Sort_Field_Value := Files.Types.Sort_Name;
      Model.Sort_Ascending := True;
      Model.Sort_Menu.Open := False;
      Model.Back_History.Clear;
      Model.Forward_History.Clear;
      Model.Recent_View_Active := False;
      Model.Search_Scope_Value := Files.UI_Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Results_Hide_Hidden := False;
      Support.Invalidate_Visible (Model);
      Model.Recent_Open_Queue.Clear;
      Model.Focus_Value := Files.UI_Types.Focus_None;
      Model.Path_Input :=
        (Edit => (Text => To_Unbounded_String (Directory_Path), Cursor => Directory_Path'Length), others => <>);
      Model.Info_Pane_Open := False;
      Model.Main_View_Scroll := 0;
      Clear_Root_Selector_State (Model);
      Reset_Quick_Look (Model);
      Hide_Command_Palette (Model);
      Reset_Rename_State (Model);
      Model.Temporary := (others => <>);
      Model.Last_Error := Null_Unbounded_String;
      Model.Last_Error_Path_Value := Null_Unbounded_String;
      Model.Last_Error_Notice_Key := Null_Unbounded_String;
      Model.Reveal_Pending := False;
   end Initialize;

   function Current_Path
     (Model : Window_Model)
      return String is
     (To_String (Model.Current_Path_Value));

   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System_Types.Directory_Signature is
     (Model.Directory_Signature);

   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System_Types.Directory_Signature) is separate;

   function Home_Path
     (Model : Window_Model)
      return String is
     (To_String (Model.Home_Path_Value));

   function Item_Count
     (Model : Window_Model)
      return Natural is
     (Natural (Model.Items.Length));

   --  How many items are visible (the pending create row not counted).
   --
   --  @param Model Model to inspect.
   --  @return The count.
   function Visible_Item_Count (Model : Window_Model) return Natural is
   begin
      Ensure_Visible_Map (Model);
      return Natural (Model.Visible_Items.Length);
   end Visible_Item_Count;

   function Visible_Count
     (Model : Window_Model)
      return Natural is
     (Visible_Item_Count (Model) + (if Temporary_Is_Visible (Model) then 1 else 0));

   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural
   is separate;

   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.Items.Directory_Item
   is separate;

   function Visible_Index_Of
     (Model     : Window_Model;
      Full_Path : String)
      return Natural
   is
   begin
      Ensure_Visible_Map (Model);
      for Position in 1 .. Natural (Model.Visible_Items.Length) loop
         if Model.Items (Model.Visible_Items (Position)).Full_Path = Full_Path then
            return Position;
         end if;
      end loop;
      if Temporary_Is_Visible (Model)
        and then Visible_Item (Model, Visible_Count (Model)).Full_Path = Full_Path
      then
         return Visible_Count (Model);
      end if;
      return 0;
   end Visible_Index_Of;

   function Visible_Rows
     (Model : Window_Model)
      return Visible_Row_Vectors.Vector
   is separate;

   procedure For_Each_Visible_Row
     (Model : Window_Model;
      Visit : not null access procedure
        (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean))
   is separate;

   function Can_Go_Back
     (Model : Window_Model)
      return Boolean is
     (not Model.Back_History.Is_Empty);

   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean is
     (not Model.Forward_History.Is_Empty);

   function Current_Is_Trash (Model : Window_Model) return Boolean is (Model.Current_Is_Trash_Value);

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Preference_Types.View_Mode is
     (Model.View_Value);

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Preference_Types.View_Mode) is separate;

   function Sort_Field_Of
     (Model : Window_Model)
      return Files.Types.Sort_Field is
     (Model.Sort_Field_Value);

   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean is
     (Model.Sort_Ascending);

   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Files.Types.Sort_Field) is separate;

   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean) is separate;

   procedure Sync_Grouping
     (Model    : in out Window_Model;
      Settings : Files.Settings.Settings_Model)
   is separate;

   function Grouping_Day (Model : Window_Model) return Ada.Calendar.Time is (Model.Grouping.Day);

   function Grouped (Model : Window_Model; Settings : Files.Settings.Settings_Model) return Window_Model is
   begin
      return Result : Window_Model := Model do
         Sync_Grouping (Result, Settings);
      end return;
   end Grouped;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is separate;

   function Focus
     (Model : Window_Model)
      return Files.UI_Types.Focus_Target is
     (Model.Focus_Value);

   function Reveal_Is_Pending
     (Model : Window_Model)
      return Boolean is
     (Model.Reveal_Pending);

   procedure Clear_Reveal
     (Model : in out Window_Model) is
   begin
      Model.Reveal_Pending := False;
   end Clear_Reveal;

   --  Cap on the back navigation history so a session that keeps navigating does
   --  not grow it without bound. Forward history is already bounded (cleared on
   --  every forward navigation); this bounds the back list the same way a
   --  browser does, dropping the oldest (least likely to be revisited) entry.
   Max_Back_History : constant := 200;

   --  Replace the items in view, keeping the view (a refresh): edits in
   --  progress, selection and scroll go; Sorted orders them by the model's sort.
   procedure Swap_Items
     (Model  : in out Window_Model;
      Items  : Files.Items.Item_Vectors.Vector;
      Sorted : Boolean);

   procedure Reapply_Listing_Settings
     (Model      : in out Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Reclassify : Boolean) is separate;

   --  Add the current path to the back navigation history, dropping the
   --  oldest entries past Max_Back_History.
   procedure Append_Back_History (Model : in out Window_Model) is
   begin
      Model.Back_History.Append (Model.Current_Path_Value);
      while Natural (Model.Back_History.Length) > Max_Back_History loop
         Model.Back_History.Delete_First;
      end loop;
   end Append_Back_History;

   --  A new navigation: the current path goes onto the back navigation
   --  history and the forward one ends.
   procedure Push_Back_History (Model : in out Window_Model) is
   begin
      Append_Back_History (Model);
      Model.Forward_History.Clear;
   end Push_Back_History;

   --  Leave the current view for New_Path ("" for the virtual recent view):
   --  what belongs to a view -- its selection, edits in progress, search,
   --  filter, scroll, folder sizes, the command palette, the root selector
   --  and Quick Look -- does not carry over. History and the listing are each
   --  caller's.
   procedure Leave_View (Model : in out Window_Model; New_Path : UString) is
   begin
      Clear_Folder_Size (Model);
      Support.Touch_Listing (Model);
      Model.Search_Scope_Value := Files.UI_Types.Filter_Here;
      Model.Search_Results_Active := False;
      Model.Results_Hide_Hidden := False;
      Set_Current_Path (Model, New_Path);
      Model.Path_Input := (Edit => (Text => New_Path, Cursor => Length (New_Path)), others => <>);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Reset_Rename_State (Model);
      Model.Temporary := (others => <>);
      Clear_Root_Selector_State (Model);
      Model.Info_Pane_Scroll := 0;
      Model.Main_View_Scroll := 0;
      Model.Filter.Text := Null_Unbounded_String;
      Model.Folded_Filter := Null_Unbounded_String;
      Model.Filter.Cursor := 0;
      --  Once, after the search state and the filter are both reset: nothing
      --  above reads the visible rows.
      Support.Invalidate_Visible (Model);
      Hide_Command_Palette (Model);
      Model.Focus_Value := Files.UI_Types.Focus_None;
      Reset_Quick_Look (Model);
   end Leave_View;

   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.Items.Item_Vectors.Vector) is
   begin
      Support.Touch (Model);
      --  Leaving the virtual recent view does not preserve it in history (its
      --  path is synthetic); an ordinary directory change pushes back history as
      --  usual.
      if not Model.Recent_View_Active and then Current_Path (Model) /= Directory_Path then
         Push_Back_History (Model);
      end if;

      Model.Recent_View_Active := False;
      Leave_View (Model, To_Unbounded_String (Directory_Path));
      Model.Items := Items;
      Model.Grouping.Banded := False;
      Support.Invalidate_Visible (Model);
      --  The model's order is the displayed order: keyboard and range
      --  selection walk it, so it must already be sorted by the model's field.
      Files.Item_Lists.Sort_Items
        (Model.Items, Model.Sort_Field_Value, Model.Sort_Ascending);
      Model.Directory_Signature := Files.File_System_Types.Unknown_Signature (Directory_Path);
   end Navigate_To;

   procedure Navigate_Recent
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector) is
   begin
      --  A refresh or clear re-enters while already active: the view stays,
      --  only its items change (as a folder's refresh), in recency order,
      --  which is also the order drawn.
      if Model.Recent_View_Active then
         Swap_Items (Model, Items, Sorted => False);
         return;
      end if;
      Support.Touch (Model);
      --  The initial entry records the departure point.
      Push_Back_History (Model);
      Model.Recent_View_Active := True;
      Leave_View (Model, Null_Unbounded_String);
      Model.Items := Items;
      Model.Grouping.Banded := False;
      Support.Invalidate_Visible (Model);
      Model.Directory_Signature := Files.File_System_Types.Unknown_Signature ("");
   end Navigate_Recent;

   procedure Go_Back
     (Model : in out Window_Model) is
      Previous : UString;
   begin
      Support.Touch (Model);
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
      Leave_View (Model, Previous);
   end Go_Back;

   procedure Go_Forward
     (Model : in out Window_Model) is
      Next : UString;
   begin
      Support.Touch (Model);
      if not Can_Go_Forward (Model) then
         return;
      end if;

      Next := Model.Forward_History.Last_Element;
      Model.Forward_History.Delete_Last;
      --  The synthetic recent view is never preserved in back history.
      if not Model.Recent_View_Active then
         Append_Back_History (Model);
      end if;
      Model.Recent_View_Active := False;
      Leave_View (Model, Next);
   end Go_Forward;

   function Mark_Navigation (Model : Window_Model) return Navigation_Mark is
     ((Path    => Model.Current_Path_Value,
       Recent  => Model.Recent_View_Active,
       Back    => Model.Back_History,
       Forward => Model.Forward_History));

   procedure Return_To (Model : in out Window_Model; Mark : Navigation_Mark) is
   begin
      Support.Touch (Model);
      Model.Back_History := Mark.Back;
      Model.Forward_History := Mark.Forward;
      Model.Recent_View_Active := Mark.Recent;
      Leave_View (Model, Mark.Path);
   end Return_To;

   procedure Focus_Path_Input
     (Model : in out Window_Model) is separate;

   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Path_Input_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Path_Input.Edit.Text));

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System_Types.Path_Result;
      Items  : Files.Items.Item_Vectors.Vector) is separate;

   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean is
     (Model.Path_Input.Valid);

   function Path_Input_Error_Key
     (Model : Window_Model)
      return String is
     (To_String (Model.Path_Input.Error));

   procedure Focus_Rename_Input
     (Model : in out Window_Model) is separate;

   --  The currently focused text input (path, filter, rename, palette,
   --  settings or ownership field): its text and caret. The palette query
   --  and a settings value are edited whole, so their caret is at the end.
   --  The empty field when none is focused.
   function Focused_Field
     (Model : Window_Model)
      return Text_Field_State
   is
      --  A field edited as a whole value: the caret sits at its end.
      function At_End (Text : String) return Text_Field_State is
        ((Text => To_Unbounded_String (Text), Cursor => Text'Length));
   begin
      case Model.Focus_Value is
         when Files.UI_Types.Focus_Path_Input =>
            return Model.Path_Input.Edit;
         when Files.UI_Types.Focus_Filter_Input =>
            return Model.Filter;
         when Files.UI_Types.Focus_Rename_Input =>
            return (if Model.Rename.Fields.Is_Empty then (others => <>) else Model.Rename.Fields.First_Element.Edit);
         when Files.UI_Types.Focus_Command_Palette =>
            --  The palette query has no separate caret.
            return At_End (Guikit.Command_Palette.Query (Model.Command_Palette.View));
         when Files.UI_Types.Focus_Settings_Input =>
            --  The panel keeps a text field's caret; any other field's value
            --  (a choice, a number) has its caret at its end.
            if Guikit.Settings_Panel.Focused_Kind (Model.Settings_Panel_View) in Guikit.Settings_Panel.Text then
               return
                 (Text   => To_Unbounded_String (Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View)),
                  Cursor => Guikit.Settings_Panel.Focused_Caret (Model.Settings_Panel_View));
            else
               return At_End (Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View));
            end if;
         when Files.UI_Types.Focus_Ownership_Input =>
            return Model.Ownership_Input.Edit;
         when Files.UI_Types.Focus_None =>
            return (others => <>);
      end case;
   end Focused_Field;

   function Focused_Text
     (Model : Window_Model)
      return String is
     (To_String (Focused_Field (Model).Text));

   function Text_Cursor_Position
     (Model : Window_Model)
      return Natural
   is
      Field : constant Text_Field_State := Focused_Field (Model);
   begin
      return Guikit.Utf8.Editing.Boundary_At_Or_Before (To_String (Field.Text), Field.Cursor);
   end Text_Cursor_Position;

   procedure Set_Text_Cursor_Position
     (Model    : in out Window_Model;
      Position : Natural)
   is
      Clamped : constant Natural :=
        Guikit.Utf8.Editing.Boundary_At_Or_Before (Focused_Text (Model), Position);
   begin
      --  Only the rename caret is drawn inside a row; the other fields are
      --  the window's chrome, so their caret leaves the rows standing.
      if Model.Focus_Value = Files.UI_Types.Focus_Rename_Input then
         Support.Touch_Rename (Model);
      elsif Model.Focus_Value = Files.UI_Types.Focus_Settings_Input then
         --  The settings pane is drawn from the model, not the snapshot.
         Support.Touch_Overlay (Model);
      else
         Support.Touch_Header (Model);
      end if;
      case Model.Focus_Value is
         when Files.UI_Types.Focus_Path_Input =>
            Model.Path_Input.Edit.Cursor := Clamped;
         when Files.UI_Types.Focus_Filter_Input =>
            Model.Filter.Cursor := Clamped;
         when Files.UI_Types.Focus_Rename_Input =>
            if not Model.Rename.Fields.Is_Empty then
               declare
                  Field : Rename_Field := Model.Rename.Fields.First_Element;
               begin
                  Field.Edit.Cursor := Clamped;
                  Model.Rename.Fields.Replace_Element (Model.Rename.Fields.First_Index, Field);
               end;
            end if;
         when Files.UI_Types.Focus_Command_Palette =>
            --  The palette query is append-only; it has no movable caret.
            null;
         when Files.UI_Types.Focus_Settings_Input =>
            Guikit.Settings_Panel.Set_Focused_Caret (Model.Settings_Panel_View, Clamped);
         when Files.UI_Types.Focus_Ownership_Input =>
            Model.Ownership_Input.Edit.Cursor := Clamped;
         when Files.UI_Types.Focus_None =>
            null;
      end case;
   end Set_Text_Cursor_Position;

   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Cursor : constant Natural := Text_Cursor_Position (Model);
      Text   : constant String := Focused_Text (Model);
   begin
      --  Set_Text_Cursor_Position notes the change the caret makes.
      Support.Touch_Header (Model);
      case Direction is
         when Guikit.Input.Move_Left | Guikit.Input.Move_Right =>
            Set_Text_Cursor_Position
              (Model,
               Guikit.Bidi.Caret_Step
                 (Text, Cursor, Rightward => Direction = Guikit.Input.Move_Right));
         when Guikit.Input.Move_Up =>
            if Cursor > 0 then
               Set_Text_Cursor_Position (Model, Guikit.Utf8.Editing.Previous_Boundary (Text, Cursor));
            end if;
         when Guikit.Input.Move_Down =>
            if Cursor < Text'Length then
               Set_Text_Cursor_Position (Model, Guikit.Utf8.Editing.Next_Boundary (Text, Cursor));
            end if;
      end case;
   end Move_Text_Cursor;

   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model) is
   begin
      --  Nothing to leave: a plain click on an item lands here, so it must
      --  not move a revision. Focus and the root selector are drawn outside
      --  the rows (Touch_Header); ending a rename or the pending create row
      --  rebuilds the rows itself.
      if Model.Focus_Value = Files.UI_Types.Focus_None
        and then not Model.Root_Selector.Open
        and then Model.Root_Selector.Entries.Is_Empty
        and then not Model.Rename.Active
        and then not Is_Temporary_Rename (Model)
      then
         return;
      end if;
      Support.Touch_Header (Model);
      Clear_Root_Selector_State (Model);

      if Model.Focus_Value = Files.UI_Types.Focus_Path_Input then
         Model.Path_Input :=
           (Edit => (Text => Model.Current_Path_Value, Cursor => Length (Model.Current_Path_Value)), others => <>);
      end if;

      if Is_Temporary_Rename (Model) then
         Cancel_Create_File (Model);
      elsif Model.Rename.Active then
         Reset_Rename_State (Model);
      end if;

      Model.Focus_Value := Files.UI_Types.Focus_None;
   end Cancel_Focus_Or_Edit;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is separate;

   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is separate;

   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer)
   is separate;

   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural is
     (Model.Main_View_Scroll);

   procedure Cancel_Create_File
     (Model : in out Window_Model) is separate;

   procedure Clear_Edit_State
     (Model : in out Window_Model) is
   begin
      --  Ends both: the pending create and any rename (and with it the
      --  listing revision moves, so a click keyed on it is not stale).
      Cancel_Create_File (Model);
   end Clear_Edit_State;

   procedure Replace_Items
     (Model : in out Window_Model;
      Items : Files.Items.Item_Vectors.Vector) is
   begin
      Swap_Items (Model, Items, Sorted => True);
   end Replace_Items;

   procedure Swap_Items
     (Model  : in out Window_Model;
      Items  : Files.Items.Item_Vectors.Vector;
      Sorted : Boolean)
   is
      package Time_Maps is new Ada.Containers.Ordered_Maps
        (Key_Type => UString, Element_Type => Ada.Calendar.Time, "<" => Ada.Strings.Unbounded."<");
      --  The listed times of the folders whose sizes are kept.
      Measured_At : Time_Maps.Map;
   begin
      --  A refresh of the same folder keeps the sizes measured, and the
      --  helper measuring the rest: clearing them on every reload restarted
      --  a large folder's walk each time a download in the folder grew.
      --  A folder whose own listing changed (its time moved) is measured
      --  again; Update_Folder_Size prunes whatever is no longer selected.
      if not Model.Folder_Sizes.Is_Empty then
         for Item of Model.Items loop
            if Model.Folder_Sizes.Contains (Item.Full_Path) then
               Measured_At.Include (Item.Full_Path, Item.Modified_Time);
            end if;
         end loop;
         for Item of Items loop
            if Model.Folder_Sizes.Contains (Item.Full_Path)
              and then
                (not Measured_At.Contains (Item.Full_Path)
                 or else Measured_At.Element (Item.Full_Path) /= Item.Modified_Time)
            then
               Model.Folder_Sizes.Delete (Item.Full_Path);
               Support.Note_Folder_Sizes (Model);
            end if;
         end loop;
      end if;
      Support.Touch (Model);
      Support.Touch_Listing (Model);
      if Model.Temporary.Active then
         Cancel_Create_File (Model);
      elsif Model.Rename.Active then
         Reset_Rename_State (Model);
      end if;
      Hide_Command_Palette (Model);
      if Model.Focus_Value = Files.UI_Types.Focus_Command_Palette then
         Model.Focus_Value := Files.UI_Types.Focus_None;
      end if;
      Model.Items := Items;
      Model.Grouping.Banded := False;
      Support.Invalidate_Visible (Model);
      --  Order the loaded items by the active sort so the model's order matches
      --  the displayed order. Without this, arrow navigation (which walks the
      --  model's order) would move opposite to the display under descending sort
      --  or any non-default sort, because Build_Snapshot sorts for display but
      --  Load_Directory cannot know the model's current sort direction.
      if Sorted then
         Files.Item_Lists.Sort_Items
           (Model.Items,
            Model.Sort_Field_Value,
            Model.Sort_Ascending);
      end if;
      Model.Directory_Signature := Files.File_System_Types.Unknown_Signature (Current_Path (Model));
      Model.Main_View_Scroll := 0;
      Model.Info_Pane_Scroll := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
   end Swap_Items;

   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String;
      Path      : String := "") is separate;

   function Last_Error_Key
     (Model : Window_Model)
      return String is
     (To_String (Model.Last_Error));

   function Last_Error_Path
     (Model : Window_Model)
      return String is (To_String (Model.Last_Error_Path_Value));

   procedure Set_Error_Notice
     (Model      : in out Window_Model;
      Notice_Key : String) is
   begin
      Support.Touch_Header (Model);
      Model.Last_Error_Notice_Key := To_Unbounded_String (Notice_Key);
   end Set_Error_Notice;

   function Last_Error_Notice
     (Model : Window_Model)
      return String is (To_String (Model.Last_Error_Notice_Key));

end Files.Model;
