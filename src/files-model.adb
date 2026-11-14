with Guikit.Layout;
with Guikit.Utf8.Editing;

with Files.Model.Support;

package body Files.Model is

   use Ada.Strings.Unbounded;

   procedure Set_Created
     (Action : in out Undo_Entry; Index : Positive; Identity, Tree_Revision : UString) is
   begin
      while Action.Created_Identities.Last_Index < Index loop
         Action.Created_Identities.Append (Null_Unbounded_String);
      end loop;
      while Action.Created_Tree_Revisions.Last_Index < Index loop
         Action.Created_Tree_Revisions.Append (Null_Unbounded_String);
      end loop;
      Action.Created_Identities.Replace_Element (Index, Identity);
      Action.Created_Tree_Revisions.Replace_Element (Index, Tree_Revision);
   end Set_Created;

   procedure Set_Background_Transfers (Model : in out Window_Model; Enabled : Boolean) is
   begin
      Model.Background_Transfers_Value := Enabled;
   end Set_Background_Transfers;

   function Background_Transfers (Model : Window_Model) return Boolean is (Model.Background_Transfers_Value);

   procedure Set_Background_Operation
     (Model : in out Window_Model; Job : Files.Process_Jobs.Session; Label_Key : String) is
   begin
      Model.Operation_Job := Job;
      Model.Operation_Label_Key := To_Unbounded_String (Label_Key);
      Model.Paste_Exec.Current := To_Unbounded_String (Current_Path (Model));
      Support.Touch (Model);
   end Set_Background_Operation;

   function Background_Operation_Label (Model : Window_Model) return String is (To_String (Model.Operation_Label_Key));

   function Background_Operation (Model : Window_Model) return Files.Process_Jobs.Session is (Model.Operation_Job);

   procedure Set_Background_Refresh (Model : in out Window_Model; Job : Files.Process_Jobs.Session) is
   begin
      Model.Refresh_Job := Job;
   end Set_Background_Refresh;

   function Background_Refresh (Model : Window_Model) return Files.Process_Jobs.Session is (Model.Refresh_Job);

   use type Ada.Calendar.Time;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Search_Scope;

   use Files.Model.Support;

   function Scroll_Revision (Model : Window_Model) return Natural is (Model.Scroll_Revision_Value);

   function Rows_Revision (Model : Window_Model) return Natural is (Model.Rows_Revision_Value);

   function Selection_Revision (Model : Window_Model) return Natural is (Model.Selection_Revision_Value);

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
      Model.Settings_Revision_Value :=
        (if Model.Settings_Revision_Value = Natural'Last then 0 else Model.Settings_Revision_Value + 1);
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

   function Input_Owning_Overlay_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      for Overlay in Input_Overlay loop
         if Overlay_Is_Open (Model, Overlay) then
            return True;
         end if;
      end loop;
      return False;
   end Input_Owning_Overlay_Is_Open;

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
         when Paste_Execution_Overlay => return Model.Paste_Exec.Active;
      end case;
   end Overlay_Is_Open;

   type Overlay_Order is array (Positive range <>) of Input_Overlay;

   --  The first open overlay of Order.
   function First_Open (Model : Window_Model; Order : Overlay_Order; Overlay : out Input_Overlay) return Boolean is
   begin
      for Candidate of Order loop
         if Overlay_Is_Open (Model, Candidate) then
            Overlay := Candidate;
            return True;
         end if;
      end loop;
      Overlay := Order (Order'First);
      return False;
   end First_Open;

   --  Top to bottom as they are drawn: the paste dialogs over everything (the
   --  window layer gives way to them, Window_Overlay_Shown), then the window
   --  layer's palette over its settings pane, then the frame's popups in the
   --  reverse of their drawing order, and the tree pick, which is part of the
   --  frame itself.
   function Topmost_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean is
     (First_Open
        (Model,
         [Paste_Execution_Overlay, Paste_Conflict_Overlay, Command_Palette_Overlay, Settings_Pane_Overlay,
          Context_Menu_Overlay, Root_Selector_Overlay, Sort_Menu_Overlay, Label_Picker_Overlay,
          Quick_Look_Overlay, Tree_Pick_Overlay],
         Overlay));

   function Window_Overlay_Shown (Model : Window_Model; Overlay : Text_Input_Overlay) return Boolean is
     (Overlay_Is_Open (Model, Overlay)
      and then not Model.Paste_Exec.Active
      and then not Model.Paste_Conflict.Active
      and then (Overlay = Command_Palette_Overlay or else not Model.Command_Palette.Open));

   function Escape_Overlay (Model : Window_Model; Overlay : out Input_Overlay) return Boolean is
     (Topmost_Overlay (Model, Overlay) and then Overlay in Escape_Closable_Overlay);

   procedure Close_Overlay (Model : in out Window_Model; Overlay : Escape_Closable_Overlay) is
   begin
      case Overlay is
         when Label_Picker_Overlay    => Close_Label_Picker (Model);
         when Context_Menu_Overlay    => Close_Context_Menu (Model);
         when Command_Palette_Overlay => Close_Command_Palette (Model);
         when Root_Selector_Overlay   => Close_Root_Selector (Model);
         when Sort_Menu_Overlay       => Close_Sort_Menu (Model);
         --  Closed the way Escape in the pane closes it; reopening starts a fresh draft.
         when Settings_Pane_Overlay   => Toggle_Settings_Pane (Model);
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

   function Non_Text_Overlay_Owns_Input
     (Model : Window_Model)
      return Boolean is
   begin
      for Overlay in Input_Overlay loop
         if Overlay not in Text_Input_Overlay
           and then Overlay_Is_Open (Model, Overlay)
           and then not (Overlay = Root_Selector_Overlay and then Model.Command_Palette.Open)
         then
            return True;
         end if;
      end loop;
      return False;
   end Non_Text_Overlay_Owns_Input;

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
      Model.View_Incarnation_Value := Model.View_Incarnation_Value + 1;
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
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons) is
   begin
      Clear_Folder_Size (Model);
      Support.Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Set_Current_Path (Model, To_Unbounded_String (Directory_Path));
      Model.Refresh_Job := Released_Process;
      Model.Home_Path_Value := To_Unbounded_String (Home_Path);
      Model.Items := Items;
      Support.Invalidate_Visible (Model);
      Model.Directory_Signature := Files.File_System.Unknown_Signature (Directory_Path);
      Model.Filter.Text := Null_Unbounded_String;
      Support.Invalidate_Visible (Model);
      Model.Filter.Cursor := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.View_Value := Default_View_Mode;
      Model.Sort_Field_Value := Files.Types.Sort_Name;
      Model.Sort_Ascending := True;
      Model.Sort_Menu.Open := False;
      Model.Back_History.Clear;
      Model.Forward_History.Clear;
      Model.Recent_View_Active := False;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
      Support.Invalidate_Visible (Model);
      Model.Recent_Open_Queue.Clear;
      Model.Focus_Value := Files.Types.Focus_None;
      Model.Path_Input :=
        (Edit => (Text => To_Unbounded_String (Directory_Path), Cursor => Directory_Path'Length), others => <>);
      Model.Info_Pane_Open := False;
      Model.Main_View_Scroll := 0;
      Clear_Root_Selector_State (Model);
      Reset_Quick_Look (Model);
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
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
      return Files.File_System.Directory_Signature is
     (Model.Directory_Signature);

   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature) is separate;

   function Home_Path
     (Model : Window_Model)
      return String is
     (To_String (Model.Home_Path_Value));

   function Item_Count
     (Model : Window_Model)
      return Natural is
     (Natural (Model.Items.Length));

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

   function In_Recent_View
     (Model : Window_Model)
      return Boolean is
     (Model.Recent_View_Active);

   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is separate;

   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
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

   procedure Note_Path_Move
     (Model : in out Window_Model;
      From  : String;
      To    : String) is
   begin
      if From /= "" and then To /= "" and then From /= To then
         Model.Path_Move_Queue.Append
           (Files.Types.Path_Move'
              (From => To_Unbounded_String (From), To => To_Unbounded_String (To), Kind => Files.Types.Moved));
      end if;
   end Note_Path_Move;

   procedure Note_Path_Removed
     (Model : in out Window_Model;
      Path  : String) is
   begin
      if Path /= "" then
         Model.Path_Move_Queue.Append
           (Files.Types.Path_Move'
              (From => To_Unbounded_String (Path), To => Null_Unbounded_String, Kind => Files.Types.Removed));
      end if;
   end Note_Path_Removed;

   function Take_Path_Moves
     (Model : in out Window_Model)
      return Files.Types.Path_Move_Vectors.Vector is
   begin
      return Moves : constant Files.Types.Path_Move_Vectors.Vector := Model.Path_Move_Queue do
         Model.Path_Move_Queue.Clear;
      end return;
   end Take_Path_Moves;

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is
     (Model.View_Value);

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is separate;

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

   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Filter_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Filter.Text));

   procedure Clear_Filter
     (Model : in out Window_Model) is separate;

   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope is
     (Model.Search_Scope_Value);

   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is separate;

   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Search_Results_Active);

   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is separate;

   procedure Clear_Search_Results
     (Model : in out Window_Model) is separate;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is separate;

   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target is
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

   --  Cap on the back-navigation history so a session that keeps navigating does
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

   procedure Push_Back_History (Model : in out Window_Model) is
   begin
      Model.Back_History.Append (Model.Current_Path_Value);
      while Natural (Model.Back_History.Length) > Max_Back_History loop
         Model.Back_History.Delete_First;
      end loop;
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
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
      Support.Invalidate_Visible (Model);
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
      Support.Invalidate_Visible (Model);
      Model.Filter.Cursor := 0;
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      Model.Focus_Value := Files.Types.Focus_None;
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
      Support.Invalidate_Visible (Model);
      --  The model's order is the displayed order: keyboard and range
      --  selection walk it, so it must already be sorted by the model's field.
      Files.File_System.Sort_Items
        (Model.Items, Model.Sort_Field_Value, Model.Sort_Ascending);
      Model.Directory_Signature := Files.File_System.Unknown_Signature (Directory_Path);
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
      Support.Invalidate_Visible (Model);
      Model.Directory_Signature := Files.File_System.Unknown_Signature ("");
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
         Model.Back_History.Append (Model.Current_Path_Value);
         while Natural (Model.Back_History.Length) > Max_Back_History loop
            Model.Back_History.Delete_First;
         end loop;
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
      Result : Files.File_System.Path_Result;
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

   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean;
      Account_Name  : String)
   is separate;

   function Ownership_Input_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Ownership_Input.Edit.Text));

   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean is
     (Model.Ownership_Input.Editing_Group);

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
        Guikit.Utf8.Editing.Boundary_At_Or_Before (Focused_Text_Value (Model), Position);
   begin
      Support.Touch (Model);
      case Model.Focus_Value is
         when Files.Types.Focus_Path_Input =>
            Model.Path_Input.Edit.Cursor := Clamped;
         when Files.Types.Focus_Filter_Input =>
            Model.Filter.Cursor := Clamped;
         when Files.Types.Focus_Rename_Input =>
            if not Model.Rename.Fields.Is_Empty then
               declare
                  Field : Rename_Field := Model.Rename.Fields.First_Element;
               begin
                  Field.Edit.Cursor := Clamped;
                  Model.Rename.Fields.Replace_Element (Model.Rename.Fields.First_Index, Field);
               end;
            end if;
         when Files.Types.Focus_Command_Palette =>
            --  The palette query is append-only; it has no movable caret.
            null;
         when Files.Types.Focus_Settings_Input =>
            --  The panel edits whole values; there is no movable caret.
            null;
         when Files.Types.Focus_Ownership_Input =>
            Model.Ownership_Input.Edit.Cursor := Clamped;
         when Files.Types.Focus_None =>
            null;
      end case;
   end Set_Text_Cursor_Position;

   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Cursor : constant Natural := Text_Cursor_Position (Model);
      Text   : constant String := Focused_Text_Value (Model);
   begin
      Support.Touch (Model);
      if Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up then
         if Cursor > 0 then
            Set_Text_Cursor_Position (Model, Guikit.Utf8.Editing.Previous_Boundary (Text, Cursor));
         end if;
      elsif Cursor < Text'Length then
         Set_Text_Cursor_Position (Model, Guikit.Utf8.Editing.Next_Boundary (Text, Cursor));
      end if;
   end Move_Text_Cursor;

   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model) is
   begin
      Support.Touch (Model);
      Clear_Root_Selector_State (Model);

      if Model.Focus_Value = Files.Types.Focus_Path_Input then
         Model.Path_Input :=
           (Edit => (Text => Model.Current_Path_Value, Cursor => Length (Model.Current_Path_Value)), others => <>);
      end if;

      if Is_Temporary_Rename (Model) then
         Cancel_Create_File (Model);
      elsif Model.Rename.Active then
         Reset_Rename_State (Model);
      end if;

      Model.Focus_Value := Files.Types.Focus_None;
   end Cancel_Focus_Or_Edit;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is separate;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is separate;

   function Selected_Item_Needs_Extra
     (Model : Window_Model)
      return Boolean is separate;

   procedure Set_Selected_Item_Extra
     (Model : in out Window_Model;
      Extra : Files.Extra_Info.Info) is separate;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Info_Pane_Open);

   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer)
   is separate;

   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is
     (Model.Info_Pane_Scroll);

   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is separate;

   procedure Keep_Info_Pane
     (Model      : in out Window_Model;
      Previous   : Files.Items.Directory_Item;
      Scroll     : Natural;
      Keep_Extra : Boolean) is separate;

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

   procedure Begin_Create_File
      (Model : in out Window_Model;
       Name  : String) is separate;

   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is separate;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Active);

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Is_Directory);

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
     (To_String (Model.Temporary.Name));

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
            end if;
         end loop;
      end if;
      Support.Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      if Model.Temporary.Active then
         Cancel_Create_File (Model);
      elsif Model.Rename.Active then
         Reset_Rename_State (Model);
      end if;
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
      Model.Items := Items;
      Support.Invalidate_Visible (Model);
      --  Order the loaded items by the active sort so the model's order matches
      --  the displayed order. Without this, arrow navigation (which walks the
      --  model's order) would move opposite to the display under descending sort
      --  or any non-default sort, because Build_Snapshot sorts for display but
      --  Load_Directory cannot know the model's current sort direction.
      if Sorted then
         Files.File_System.Sort_Items
           (Model.Items,
            Model.Sort_Field_Value,
            Model.Sort_Ascending);
      end if;
      Model.Directory_Signature := Files.File_System.Unknown_Signature (Current_Path (Model));
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
      Support.Touch (Model);
      Model.Last_Error_Notice_Key := To_Unbounded_String (Notice_Key);
   end Set_Error_Notice;

   function Last_Error_Notice
     (Model : Window_Model)
      return String is (To_String (Model.Last_Error_Notice_Key));

   procedure Set_Volume_Space
     (Model   : in out Window_Model;
      Path    : String;
      Space   : Volume_Space;
      Sampled : Ada.Calendar.Time) is
   begin
      --  The bar and the free-space text are header: no row changes.
      if Model.Volume_Sample.Space /= Space or else To_String (Model.Volume_Sample.Path) /= Path then
         Support.Touch_Header (Model);
      end if;
      Model.Volume_Sample := (Space => Space, Path => To_Unbounded_String (Path), Sampled => Sampled);
   end Set_Volume_Space;

   function Volume_Space_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean is
   begin
      return Length (Model.Volume_Sample.Path) > 0
        and then To_String (Model.Volume_Sample.Path) = Current_Path (Model)
        --  A clock set back since the sample is no reason to keep it.
        and then Now >= Model.Volume_Sample.Sampled
        and then Now <= Model.Volume_Sample.Sampled + Volume_Space_Refresh_Interval;
   end Volume_Space_Is_Current;

   function Volume_Space_Of
     (Model : Window_Model)
      return Volume_Space is
     (if To_String (Model.Volume_Sample.Path) = Current_Path (Model) then Model.Volume_Sample.Space
      else (others => <>));

   procedure Set_Account_Name
     (Model : in out Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String)
   is
      --  Ids on one host are few, but bound the table so a long session over
      --  many foreign volumes cannot grow it without limit.
      Max_Account_Names : constant := 4096;
      Names : Account_Name_Maps.Map renames Model.Account_Names.Names (Kind);
      Found : constant Account_Name_Maps.Cursor := Names.Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         if To_String (Account_Name_Maps.Element (Found)) /= Name then
            Names.Replace_Element (Found, To_Unbounded_String (Name));
            Support.Touch (Model);
         end if;
         return;
      end if;
      if Natural (Names.Length) >= Max_Account_Names then
         Names.Clear;
      end if;
      Names.Insert (Id, To_Unbounded_String (Name));
      Support.Touch (Model);
   end Set_Account_Name;

   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean is
     (Model.Account_Names.Names (Kind).Contains (Id));

   function Account_Name
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return String
   is
      Found : constant Account_Name_Maps.Cursor := Model.Account_Names.Names (Kind).Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         return To_String (Account_Name_Maps.Element (Found));
      end if;
      return "";
   end Account_Name;

   procedure Note_Account_Names_Sampled
     (Model : in out Window_Model) is
   begin
      Model.Account_Names.Sampled := Model.Revision_Value;
   end Note_Account_Names_Sampled;

   function Account_Names_Current
     (Model : Window_Model)
      return Boolean is
     (Model.Account_Names.Sampled = Model.Revision_Value);

end Files.Model;
