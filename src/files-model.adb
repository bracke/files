with Ada.Containers.Ordered_Sets;
with Ada.Directories;
with Ada.Strings.Fixed;

with GNAT.OS_Lib;

with Files.Command_Palette;
with Files.Localization;
with Files.Settings_Form;
with Files.Type_Ahead;
with Files.UTF8;

with Files.Model.Support;

package body Files.Model is
   use Ada.Strings.Unbounded;

   package UString_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => UString);

   function Undo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector is (Model.Undo_Stack);
   function Redo_History (Model : Window_Model) return Undo_Entry_Vectors.Vector is (Model.Redo_Stack);

   function Same_Length
     (Left, Right : Files.Types.String_Vectors.Vector) return Boolean is
     (Natural (Left.Length) = Natural (Right.Length));

   function Nonempty_Values
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      for Value of Values loop
         if Length (Value) = 0 then
            return False;
         end if;
      end loop;
      return True;
   end Nonempty_Values;

   function Unique_Nonempty_Values
     (Values : Files.Types.String_Vectors.Vector) return Boolean
   is
      Seen : UString_Sets.Set;
   begin
      for Value of Values loop
         if Length (Value) = 0 or else Seen.Contains (Value) then
            return False;
         end if;
         Seen.Insert (Value);
      end loop;
      return True;
   end Unique_Nonempty_Values;

   function Valid_Absolute_Path (Value : UString) return Boolean is
      Path : constant String := To_String (Value);
   begin
      if Path = "" then
         return False;
      end if;
      for Item of Path loop
         if Item = ASCII.NUL then
            return False;
         end if;
      end loop;
      return GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others =>
         return False;
   end Valid_Absolute_Path;

   function Absolute_Paths
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      for Value of Values loop
         if not Valid_Absolute_Path (Value) then
            return False;
         end if;
      end loop;
      return True;
   end Absolute_Paths;

   function Unique_Absolute_Paths
     (Values : Files.Types.String_Vectors.Vector) return Boolean is
   begin
      return Unique_Nonempty_Values (Values) and then Absolute_Paths (Values);
   end Unique_Absolute_Paths;

   function Completion_Markers_Valid
     (Markers, Allowed : Files.Types.String_Vectors.Vector) return Boolean
   is
      Seen : UString_Sets.Set;
      Allowed_Values : UString_Sets.Set;
   begin
      for Value of Allowed loop
         Allowed_Values.Include (Value);
      end loop;
      for Marker of Markers loop
         if Length (Marker) = 0
           or else not Allowed_Values.Contains (Marker)
           or else Seen.Contains (Marker)
         then
            return False;
         end if;
         Seen.Insert (Marker);
      end loop;
      return True;
   end Completion_Markers_Valid;

   function Valid_Natural_Image (Value : UString) return Boolean is separate;

   function Valid_Ownership_Image (Value : UString) return Boolean is separate;

   function Valid_Copy_Records
     (Values : Files.Types.String_Vectors.Vector) return Boolean
   is
      Index : Positive := 1;
      Keys  : UString_Sets.Set;
   begin
      if Natural (Values.Length) mod 6 /= 0 or else not Nonempty_Values (Values) then
         return False;
      end if;
      while Index <= Values.Last_Index loop
         if Keys.Contains (Values (Index))
           or else not Valid_Absolute_Path (Values (Index + 3))
         then
            return False;
         end if;
         Keys.Insert (Values (Index));
         Index := Index + 6;
      end loop;
      return True;
   end Valid_Copy_Records;

   function History_Entry_Usable
     (Action : Undo_Entry; For_Redo : Boolean) return Boolean
   is
      Main_Count : constant Natural := Natural (Action.From.Length);
      Restore_Count : constant Natural := Natural (Action.Restore_Trash.Length);

      function Payload_Images_Valid
        (Values : Files.Types.String_Vectors.Vector;
         Ownership : Boolean) return Boolean is
      begin
         if Natural (Values.Length) /= Main_Count then
            return False;
         end if;
         for Value of Values loop
            if (if Ownership then not Valid_Ownership_Image (Value)
                else not Valid_Natural_Image (Value))
            then
               return False;
            end if;
         end loop;
         return True;
      end Payload_Images_Valid;

      Forward_Markers_Valid : Boolean := False;
   begin
      if Action.Kind = Undo_None
        or else Main_Count = 0
        or else not Unique_Absolute_Paths (Action.From)
        or else not Same_Length (Action.From, Action.Created_Identities)
        or else not Same_Length (Action.From, Action.Created_Tree_Revisions)
        or else not Nonempty_Values (Action.Created_Identities)
        or else (For_Redo and then not Action.Redoable)
      then
         return False;
      end if;

      if Restore_Count = 0 then
         if not Action.Restore_Identities.Is_Empty
           or else not Action.Restore_Targets.Is_Empty
           or else not Action.Restores_Completed.Is_Empty
         then
            return False;
         end if;
      elsif Action.Redoable
        or else Action.Kind not in Undo_Move | Undo_Delete_Created
        or else not Unique_Absolute_Paths (Action.Restore_Trash)
        or else not Same_Length (Action.Restore_Trash, Action.Restore_Identities)
        or else not Same_Length (Action.Restore_Trash, Action.Restore_Targets)
        or else not Nonempty_Values (Action.Restore_Identities)
        or else not Unique_Absolute_Paths (Action.Restore_Targets)
        or else not Completion_Markers_Valid
          (Action.Restores_Completed, Action.Restore_Trash)
      then
         return False;
      end if;

      case Action.Kind is
         when Undo_Rename | Undo_Move =>
            if not Same_Length (Action.From, Action.To)
              or else not Unique_Absolute_Paths (Action.To)
              or else not Action.Forward.Is_Empty
              or else Action.Create_Kind /= Create_None
            then
               return False;
            end if;
            Forward_Markers_Valid :=
              Completion_Markers_Valid (Action.Forward_Completed, Action.To);

         when Undo_Restore_Trash =>
            if Action.Redoable
              or else not Same_Length (Action.From, Action.To)
              or else not Unique_Absolute_Paths (Action.To)
              or else not Action.Forward.Is_Empty
              or else Action.Create_Kind /= Create_None
              or else Restore_Count /= 0
              or else not Action.Forward_Completed.Is_Empty
            then
               return False;
            end if;
            Forward_Markers_Valid := True;

         when Undo_Delete_Created =>
            if not Action.To.Is_Empty
              or else (Action.Redoable
                and then (Action.Create_Kind = Create_None
                  or else not Same_Length (Action.From, Action.Forward)
                  or else not Absolute_Paths (Action.Forward)))
              or else (not Action.Redoable and then not Action.Forward.Is_Empty)
            then
               return False;
            end if;
            Forward_Markers_Valid :=
              Completion_Markers_Valid (Action.Forward_Completed, Action.From);

         when Undo_Set_Permissions =>
            if Action.Create_Kind /= Create_None
              or else Restore_Count /= 0
              or else not Payload_Images_Valid (Action.To, False)
              or else (Action.Redoable and then not Payload_Images_Valid (Action.Forward, False))
              or else (not Action.Redoable and then not Action.Forward.Is_Empty)
              or else not Action.Reverse_Completed.Is_Empty
              or else not Action.Forward_Completed.Is_Empty
            then
               return False;
            end if;
            Forward_Markers_Valid := True;

         when Undo_Set_Ownership =>
            if Action.Create_Kind /= Create_None
              or else Restore_Count /= 0
              or else not Payload_Images_Valid (Action.To, True)
              or else (Action.Redoable and then not Payload_Images_Valid (Action.Forward, True))
              or else (not Action.Redoable and then not Action.Forward.Is_Empty)
              or else not Action.Reverse_Completed.Is_Empty
              or else not Action.Forward_Completed.Is_Empty
            then
               return False;
            end if;
            Forward_Markers_Valid := True;

         when Undo_None =>
            return False;
      end case;

      return Forward_Markers_Valid
        and then Completion_Markers_Valid (Action.Reverse_Completed, Action.From)
        and then (not For_Redo or else
          (Action.Reverse_Completed.Is_Empty and then Action.Restores_Completed.Is_Empty))
        and then (For_Redo or else Action.Forward_Completed.Is_Empty)
        and then
          ((Action.Copy_Records.Is_Empty)
           or else (Action.Kind = Undo_Delete_Created
             and then Action.Redoable
             and then Action.Create_Kind = Create_Copy
             and then Valid_Copy_Records (Action.Copy_Records)));
   exception
      when others =>
         return False;
   end History_Entry_Usable;

   procedure Set_History (Model : in out Window_Model; Undo, Redo : Undo_Entry_Vectors.Vector) is
      Sanitized_Undo, Sanitized_Redo : Undo_Entry_Vectors.Vector;
   begin
      for Action of Undo loop
         if History_Entry_Usable (Action, For_Redo => False) then
            Sanitized_Undo.Append (Action);
         end if;
      end loop;
      for Action of Redo loop
         if History_Entry_Usable (Action, For_Redo => True) then
            Sanitized_Redo.Append (Action);
         end if;
      end loop;
      Model.Undo_Stack := Sanitized_Undo;
      Model.Redo_Stack := Sanitized_Redo;
      Model.Revision_Value := Model.Revision_Value + 1;
   end Set_History;

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
      Model.Revision_Value := Model.Revision_Value + 1;
   end Set_Background_Operation;

   function Background_Operation_Label (Model : Window_Model) return String is (To_String (Model.Operation_Label_Key));

   function Background_Operation (Model : Window_Model) return Files.Process_Jobs.Session is (Model.Operation_Job);

   procedure Set_Background_Refresh (Model : in out Window_Model; Job : Files.Process_Jobs.Session) is
   begin
      Model.Refresh_Job := Job;
   end Set_Background_Refresh;

   function Background_Refresh (Model : Window_Model) return Files.Process_Jobs.Session is (Model.Refresh_Job);

   procedure Advance_Background_Paste
     (Model : in out Window_Model; Finished : out Boolean; Result : out Files.Transfer_Jobs.Job_Result)
   is
   begin
      if not Files.Transfer_Jobs.Active (Model.Paste_Exec_Job) then
         if Model.Paste_Exec.Cancelled then
            Finished := True;
            Result := (Cancelled => True, others => <>);
            return;
         end if;
         Files.Transfer_Jobs.Start
           (Model.Paste_Exec_Job,
            Model.Paste_Exec.Actions.Element (Model.Paste_Exec.Cursor + 1),
            Model.Paste_Exec.Mode, Model.Paste_Exec.Copy_Context);
         Model.Paste_Exec.Current :=
           To_Unbounded_String
             (Ada.Directories.Simple_Name
                (To_String (Model.Paste_Exec.Actions.Element (Model.Paste_Exec.Cursor + 1).Source_Path)));
         Model.Revision_Value := Model.Revision_Value + 1;
      end if;
      Files.Transfer_Jobs.Poll (Model.Paste_Exec_Job, Finished, Result);
      if Finished then
         Files.Transfer_Jobs.Reset (Model.Paste_Exec_Job);
      end if;
   end Advance_Background_Paste;

   use type Ada.Calendar.Time;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Search_Scope;

   use Files.Model.Support;

   function Revision
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Revision_Value;
   end Revision;

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
      Select_Name : String) is
   begin
      if not Refresh_Is_Owed (Model) then
         Model.Owed_Refresh_Forced := False;
         Model.Owed_Refresh_Select := Null_Unbounded_String;
      end if;
      Model.Owed_Refresh := True;
      Model.Owed_Refresh_Incarnation := Model.View_Incarnation_Value;
      Model.Owed_Refresh_Forced := Model.Owed_Refresh_Forced or else Force;
      if Select_Name /= "" then
         Model.Owed_Refresh_Select := To_Unbounded_String (Select_Name);
      end if;
   end Note_Owed_Refresh;

   function Refresh_Is_Owed
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Owed_Refresh
        and then Model.Owed_Refresh_Incarnation = Model.View_Incarnation_Value;
   end Refresh_Is_Owed;

   function Owed_Refresh_Force
     (Model : Window_Model)
      return Boolean is
   begin
      return Refresh_Is_Owed (Model) and then Model.Owed_Refresh_Forced;
   end Owed_Refresh_Force;

   function Owed_Refresh_Selection
     (Model : Window_Model)
      return String is
   begin
      return (if Refresh_Is_Owed (Model) then To_String (Model.Owed_Refresh_Select) else "");
   end Owed_Refresh_Selection;

   procedure Clear_Owed_Refresh
     (Model : in out Window_Model) is
   begin
      Model.Owed_Refresh := False;
      Model.Owed_Refresh_Forced := False;
      Model.Owed_Refresh_Select := Null_Unbounded_String;
   end Clear_Owed_Refresh;

   function Input_Owning_Overlay_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return
        Model.Settings_Pane_Open
        or else Model.Command_Palette_Open
        or else Model.Root_Selector_Open
        or else Model.Sort_Menu_Open
        or else Model.Context_Menu.Open
        or else Model.Label_Picker_Active
        or else Model.Quick_Look_Active
        or else Model.Tree_Pick_Mode_Value /= Pick_None
        or else Model.Paste_Conflict.Active
        or else Model.Paste_Exec.Active;
   end Input_Owning_Overlay_Is_Open;

   --  Opening an overlay ends the grid's current type-to-select session.  Every
   --  caller already advances the model revision, so clear the private buffer
   --  directly rather than adding a second revision for Reset_Type_Ahead.
   procedure Claim_Overlay_Input
     (Model : in out Window_Model) is
   begin
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Claim_Overlay_Input;

   --  Every change of directory goes through here: it starts a new view
   --  incarnation and settles, once, whether the new directory is the trash,
   --  so the commands and the snapshot can ask without touching the disk.
   procedure Set_Current_Path
     (Model : in out Window_Model;
      Path  : UString) is
   begin
      Model.Current_Path_Value := Path;
      Model.View_Incarnation_Value := Model.View_Incarnation_Value + 1;
      Model.Current_Is_Trash_Value := Files.File_System.Is_Trash_Files_Directory (To_String (Path));
   end Set_Current_Path;

   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.File_System.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons) is
   begin
      Clear_Folder_Size (Model);
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      Set_Current_Path (Model, To_Unbounded_String (Directory_Path));
      Files.Process_Jobs.Reset (Model.Refresh_Job);
      Model.Home_Path_Value := To_Unbounded_String (Home_Path);
      Model.Items := Items;
      Model.Directory_Signature := Signature_From_Items (Directory_Path, Items);
      Model.Filter_Value := Null_Unbounded_String;
      Model.Filter_Cursor := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.View_Value := Default_View_Mode;
      Model.Sort_Field_Value := Files.Types.Sort_Name;
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
      return String is separate;

   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature is separate;

   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature) is separate;

   function Home_Path
     (Model : Window_Model)
      return String is separate;

   function Item_Count
     (Model : Window_Model)
      return Natural is separate;

   function Visible_Count
     (Model : Window_Model)
      return Natural
   is separate;

   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural
   is separate;

   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item
   is separate;

   function Visible_Rows
     (Model : Window_Model)
      return Visible_Row_Vectors.Vector
   is separate;

   function In_Recent_View
     (Model : Window_Model)
      return Boolean is separate;

   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String) is separate;

   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector
   is separate;

   function Can_Go_Back
     (Model : Window_Model)
      return Boolean is separate;

   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean is separate;

   function Current_Is_Trash (Model : Window_Model) return Boolean is (Model.Current_Is_Trash_Value);

   procedure Note_Path_Move
     (Model : in out Window_Model;
      From  : String;
      To    : String) is
   begin
      if From /= "" and then To /= "" and then From /= To then
         Model.Moved_From_Queue.Append (To_Unbounded_String (From));
         Model.Moved_To_Queue.Append (To_Unbounded_String (To));
      end if;
   end Note_Path_Move;

   procedure Note_Path_Removed
     (Model : in out Window_Model;
      Path  : String) is
   begin
      if Path /= "" then
         Model.Moved_From_Queue.Append (To_Unbounded_String (Path));
         Model.Moved_To_Queue.Append (Null_Unbounded_String);
      end if;
   end Note_Path_Removed;

   procedure Take_Path_Moves
     (Model : in out Window_Model;
      From  : out Files.Types.String_Vectors.Vector;
      To    : out Files.Types.String_Vectors.Vector) is
   begin
      From := Model.Moved_From_Queue;
      To := Model.Moved_To_Queue;
      Model.Moved_From_Queue.Clear;
      Model.Moved_To_Queue.Clear;
   end Take_Path_Moves;

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is separate;

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is separate;

   function Sort_Field_Of
     (Model : Window_Model)
      return Files.Types.Sort_Field is separate;

   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean is separate;

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

   procedure Toggle_Sort_Menu
     (Model : in out Window_Model) is separate;

   procedure Move_Sort_Menu_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is separate;

   function Sort_Menu_Highlight
     (Model : Window_Model)
      return Natural is separate;

   function Sort_Menu_Highlight_Field
     (Model : Window_Model)
      return Files.Types.Sort_Field is separate;

   procedure Close_Sort_Menu
     (Model : in out Window_Model) is separate;

   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

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
      return String is separate;

   procedure Clear_Filter
     (Model : in out Window_Model) is separate;

   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope is separate;

   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is separate;

   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is separate;

   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is separate;

   procedure Clear_Search_Results
     (Model : in out Window_Model) is separate;

   procedure Reset_Type_Ahead
     (Model : in out Window_Model) is separate;

   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String is separate;

   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean)
   is separate;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is separate;

   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive) is separate;

   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive)
   is separate;

   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive)
   is separate;

   procedure Select_All_Visible
     (Model : in out Window_Model) is separate;

   procedure Clear_Selection
     (Model : in out Window_Model) is separate;

   procedure Invert_Selection
     (Model : in out Window_Model)
   is separate;

   procedure Deselect_All
     (Model : in out Window_Model) is separate;

   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is separate;

   procedure Select_First_Visible
     (Model : in out Window_Model)
   is separate;

   procedure Select_Last_Visible
     (Model : in out Window_Model)
   is separate;

   procedure Move_Selection_By_Page
     (Model     : in out Window_Model;
      Page_Rows : Positive;
      Down      : Boolean)
   is separate;

   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive) is separate;

   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive is separate;

   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean is separate;

   function Selected_Index
     (Model : Window_Model)
      return Natural is separate;

   function Selected_Count
     (Model : Window_Model)
      return Natural is separate;

   function Selected_Name
     (Model : Window_Model)
      return String
   is separate;

   function Selected_Item
     (Model : Window_Model)
      return Files.File_System.Directory_Item
   is separate;

   function Selected_Items
     (Model : Window_Model)
      return Files.File_System.Item_Vectors.Vector
   is separate;

   procedure Restore_Selection
     (Model        : in out Window_Model;
      Items        : Files.File_System.Item_Vectors.Vector;
      Primary_Path : String)
   is separate;

   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean is separate;

   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean is separate;

   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target is separate;

   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean is separate;

   function Is_Selected_Directory
     (Model : Window_Model;
      Path  : String)
      return Boolean is separate;

   procedure Set_Selection_Page_Rows (Model : in out Window_Model; Rows : Positive) is
   begin
      Model.Selection_Page_Rows_Value := Rows;
   end Set_Selection_Page_Rows;

   function Selection_Page_Rows (Model : Window_Model) return Positive is
     (Model.Selection_Page_Rows_Value);

   --  Cap on the back-navigation history so a session that keeps navigating does
   --  not grow it without bound. Forward history is already bounded (cleared on
   --  every forward navigation); this bounds the back list the same way a
   --  browser does, dropping the oldest (least likely to be revisited) entry.
   Max_Back_History : constant := 200;

   procedure Push_Back_History (Model : in out Window_Model) is
   begin
      Model.Back_History.Append (Model.Current_Path_Value);
      while Natural (Model.Back_History.Length) > Max_Back_History loop
         Model.Back_History.Delete_First;
      end loop;
      Model.Forward_History.Clear;
   end Push_Back_History;

   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector) is
   begin
      Clear_Folder_Size (Model);
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      --  Leaving the virtual recent view does not preserve it in history (its
      --  path is synthetic); an ordinary directory change pushes back history as
      --  usual.
      if not Model.Recent_View_Active and then Current_Path (Model) /= Directory_Path then
         Push_Back_History (Model);
      end if;

      Model.Recent_View_Active := False;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
      Set_Current_Path (Model, To_Unbounded_String (Directory_Path));
      Model.Items := Items;
      --  The model's order is the displayed order: keyboard and range
      --  selection walk it, so it must already be sorted by the model's field.
      Files.File_System.Sort_Items
        (Model.Items, Model.Sort_Field_Value, Model.Sort_Ascending);
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
      Clear_Folder_Size (Model);
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      --  Only the initial entry into the view records the departure point; a
      --  refresh or clear re-enters while already active and just swaps items.
      if not Model.Recent_View_Active then
         Push_Back_History (Model);
      end if;

      Model.Recent_View_Active := True;
      Set_Current_Path (Model, Null_Unbounded_String);
      --  Recent keeps its recency order, which is also the order drawn.
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

   procedure Go_Back
     (Model : in out Window_Model) is
      Previous : UString;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if not Can_Go_Back (Model) then
         return;
      end if;

      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      --  Leave the current view as Navigate_To does: a search result list or
      --  folder sizes from it must not carry over to the history entry.
      Clear_Folder_Size (Model);
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;

      Previous := Model.Back_History.Last_Element;
      Model.Back_History.Delete_Last;
      --  The synthetic recent view is never preserved in forward history.
      if not Model.Recent_View_Active then
         Model.Forward_History.Append (Model.Current_Path_Value);
      end if;
      Model.Recent_View_Active := False;
      Set_Current_Path (Model, Previous);
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
      Model.Revision_Value := Model.Revision_Value + 1;
      if not Can_Go_Forward (Model) then
         return;
      end if;

      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      --  Leave the current view as Navigate_To does: a search result list or
      --  folder sizes from it must not carry over to the history entry.
      Clear_Folder_Size (Model);
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;

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
      Set_Current_Path (Model, Next);
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
      Model.Revision_Value := Model.Revision_Value + 1;
      Navigate_To (Model, Home_Path (Model), Empty_Items);
   end Go_Home;

   procedure Focus_Path_Input
     (Model : in out Window_Model) is separate;

   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Path_Input_Text
     (Model : Window_Model)
      return String is separate;

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector) is separate;

   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean is separate;

   function Path_Input_Error_Key
     (Model : Window_Model)
      return String is separate;

   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model) is separate;

   procedure Open_Command_Palette
     (Model : in out Window_Model) is separate;

   procedure Close_Command_Palette
     (Model : in out Window_Model) is separate;

   procedure Toggle_Command_Palette
     (Model : in out Window_Model) is separate;

   function Command_Palette_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   function Palette_Query (Model : Window_Model) return String is separate;

   procedure Palette_Set_Query (Model : in out Window_Model; Text : String) is separate;

   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is separate;

   procedure Palette_Select_First (Model : in out Window_Model) is separate;

   procedure Palette_Select_Last (Model : in out Window_Model) is separate;

   procedure Palette_Page (Model : in out Window_Model; Down : Boolean) is separate;

   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is separate;

   function Palette_Selected_Id (Model : Window_Model) return Natural is separate;

   function Palette_Result_Count (Model : Window_Model) return Natural is separate;

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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector) is separate;

   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode is separate;

   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode) is separate;

   procedure Focus_Rename_Input
     (Model : in out Window_Model) is separate;

   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is separate;

   function Rename_Behavior return Rename_Policy is separate;

   procedure Toggle_Rename
     (Model : in out Window_Model) is separate;

   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is separate;

   function Rename_Field_Count
     (Model : Window_Model)
      return Natural is separate;

   function Rename_Text
     (Model : Window_Model)
      return String is separate;

   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean
   is separate;

   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean
   is separate;

   function Rename_Delete_Forward
     (Model : in out Window_Model)
      return Boolean
   is separate;

   function Rename_Delete_Word_Backward
     (Model : in out Window_Model)
      return Boolean
   is separate;

   function Rename_Delete_Word_Forward
     (Model : in out Window_Model)
      return Boolean
   is separate;

   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is separate;

   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is separate;

   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean
   is separate;

   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean
   is separate;

   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural) is separate;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
   is separate;

   procedure Rename_State_For_Item
     (Model      : Window_Model;
      Item_Index : Natural;
      Active     : out Boolean;
      Value      : out UString;
      Cursor     : out Natural) is separate;

   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector
   is separate;

   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is separate;

   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean)
   is separate;

   function Ownership_Input_Text
     (Model : Window_Model)
      return String is separate;

   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String) is separate;

   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean is separate;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector)
   is separate;

   procedure Close_Root_Selector
     (Model : in out Window_Model) is separate;

   function Root_Selector_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   function Root_Count
     (Model : Window_Model)
      return Natural is separate;

   function Root_Selected_Index
     (Model : Window_Model)
      return Natural is separate;

   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is separate;

   procedure Move_Root_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is separate;

   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String is separate;

   function Root_Label
     (Model : Window_Model;
      Index : Positive)
      return String is separate;

   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind is separate;

   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean is separate;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Root_Entries := Roots;
      Model.Root_Selector_Open := not Roots.Is_Empty;
      if Model.Root_Selector_Open then
         Claim_Overlay_Input (Model);
      end if;
      Model.Root_Selected := (if Model.Root_Selector_Open then 1 else 0);
      Model.Settings_Pane_Open := False;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Open_Root_Selector;

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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
      if Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up then
         if Cursor > 0 then
            Set_Text_Cursor_Position (Model, Previous_Text_Boundary (Focused_Text_Value (Model), Cursor));
         end if;
      elsif Cursor < Focused_Text_Length (Model) then
         Set_Text_Cursor_Position (Model, Next_Text_Boundary (Focused_Text_Value (Model), Cursor));
      end if;
   end Move_Text_Cursor;

   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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

   procedure Clamp_Tree_Panel_Scroll
     (Model : in out Window_Model);

   procedure Reconcile_Tree_Pick_Target
     (Model          : in out Window_Model;
      Fallback_Index : Positive);

   procedure Clamp_Tree_Panel_Scroll
     (Model : in out Window_Model)
   is separate;

   procedure Reconcile_Tree_Pick_Target
     (Model          : in out Window_Model;
      Fallback_Index : Positive)
   is separate;

   procedure Toggle_Tree_Panel
     (Model : in out Window_Model) is separate;

   procedure Open_Tree_Panel
     (Model : in out Window_Model) is separate;

   procedure Close_Tree_Panel
     (Model : in out Window_Model) is separate;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String) is separate;

   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String) is separate;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is separate;

   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode is separate;

   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean is separate;

   function Tree_Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Tree_Pick_Target
     (Model : Window_Model)
      return String is separate;

   procedure Give_Tree_Keyboard
     (Model : in out Window_Model)
   is separate;

   procedure Take_Tree_Keyboard
     (Model : in out Window_Model) is separate;

   function Tree_Has_Keyboard
     (Model : Window_Model)
      return Boolean is separate;

   function Tree_Cursor
     (Model : Window_Model)
      return String is separate;

   procedure Set_Tree_Cursor
     (Model : in out Window_Model;
      Path  : String) is separate;

   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   function Tree_Panel_Scroll_Rows
     (Model : Window_Model)
      return Natural
   is separate;

   procedure Set_Tree_Panel_Scroll_Rows
     (Model : in out Window_Model;
      Rows  : Natural)
   is separate;

   procedure Scroll_Tree_Panel
     (Model : in out Window_Model;
      Rows  : Integer)
   is separate;

   procedure Ensure_Tree_Row_Visible
     (Model       : in out Window_Model;
      Visible_Row : Positive;
      Page_Rows   : Natural)
   is separate;

   function Tree_Is_Seeded
     (Model : Window_Model)
      return Boolean is separate;

   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is separate;

   function Tree_Node_Count
     (Model : Window_Model)
      return Natural is separate;

   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String is separate;

   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is separate;

   function Tree_Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is separate;

   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is separate;

   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is separate;

   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive) is separate;

   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector is separate;

   procedure End_Tree_Pick (Model : in out Window_Model) is
   begin
      if Model.Tree_Pick_Opened_Panel then
         Close_Tree_Panel (Model);
      else
         Clear_Tree_Pick (Model);
      end if;
      Model.Tree_Pick_Opened_Panel := False;
   end End_Tree_Pick;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is separate;

   procedure Ensure_Selected_Item_Extra
     (Model : in out Window_Model)
   is separate;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is separate;

   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is separate;

   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is separate;

   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is separate;

   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is separate;

   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is separate;

   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String) is separate;

   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer) is separate;

   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is separate;

   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is separate;

   function Settings_Focused_Value (Model : Window_Model) return String is separate;

   function Settings_Focused_Kind (Model : Window_Model) return Guikit.Settings_Panel.Field_Kind is separate;

   function Settings_Focused_Key (Model : Window_Model) return String is separate;

   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is separate;

   function Settings_Section_Count (Model : Window_Model) return Natural is separate;

   function Settings_Active_Section (Model : Window_Model) return Natural is separate;

   procedure Settings_Begin_Capture (Model : in out Window_Model) is separate;

   function Settings_Is_Capturing (Model : Window_Model) return Boolean is separate;

   function Settings_Capturing_Key (Model : Window_Model) return String is separate;

   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String) is separate;

   procedure Settings_Cancel_Capture (Model : in out Window_Model) is separate;

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
   is separate;

   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer)
   is separate;

   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is separate;

   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is separate;

   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is separate;

   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer)
   is separate;

   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural is separate;

   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector) is separate;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   procedure Open_Label_Picker
     (Model : in out Window_Model) is separate;

   procedure Move_Label_Picker_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is separate;

   function Label_Picker_Highlight
     (Model : Window_Model)
      return Positive is separate;

   function Label_Picker_Highlight_Color
     (Model : Window_Model)
      return Files.Types.Color_Label is separate;

   procedure Close_Label_Picker
     (Model : in out Window_Model) is separate;

   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   procedure Open_Quick_Look
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content) is separate;

   procedure Close_Quick_Look
     (Model : in out Window_Model) is separate;

   procedure Toggle_Quick_Look
     (Model : in out Window_Model) is separate;

   function Quick_Look_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   function Quick_Look_Path
     (Model : Window_Model)
      return String is separate;

   function Quick_Look_Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content is separate;

   procedure Begin_Create_File
      (Model : in out Window_Model;
       Name  : String) is separate;

   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is separate;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is separate;

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is separate;

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is separate;

   procedure Cancel_Create_File
     (Model : in out Window_Model) is separate;

   procedure Clear_Edit_State
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
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
      Clear_Folder_Size (Model);
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
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
         Model.Sort_Field_Value,
         Model.Sort_Ascending);
      Model.Directory_Signature := Signature_From_Items (Current_Path (Model), Items);
      Model.Main_View_Scroll := 0;
      Model.Info_Pane_Scroll := 0;
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
   end Replace_Items;

   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String) is separate;

   function Last_Error_Key
     (Model : Window_Model)
      return String is separate;

   procedure Set_System_Clipboard_Request
     (Model : in out Window_Model;
      Text  : String) is separate;

   function System_Clipboard_Request_Pending
     (Model : Window_Model)
      return Boolean is separate;

   function System_Clipboard_Request_Text
     (Model : Window_Model)
      return String is separate;

   procedure Clear_System_Clipboard_Request
     (Model : in out Window_Model) is separate;

   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode) is separate;

   procedure Clear_Clipboard
     (Model : in out Window_Model) is separate;

   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is separate;

   function Clipboard_Has_Items
     (Model : Window_Model)
      return Boolean is separate;

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Undo_Entry_Vectors.Vector);

   procedure Retire_Payloads
     (Pending : in out Files.Types.String_Vectors.Vector;
      Entries : Undo_Entry_Vectors.Vector) is separate;

   procedure Begin_Undo_Record
     (Model : in out Window_Model;
      Kind  : Undo_Action_Kind;
      From  : Files.Types.String_Vectors.Vector;
      To    : Files.Types.String_Vectors.Vector) is separate;

   function Commit_Undo_Record
     (Model  : in out Window_Model;
      Action : Undo_Entry) return Boolean is separate;

   procedure Take_Retired_History
     (Model         : in out Window_Model;
      Discarded     : out Files.Types.String_Vectors.Vector;
      Released      : out Files.Types.String_Vectors.Vector;
      Journal_Dirty : out Boolean) is separate;

   procedure Release_History
     (Model : in out Window_Model)
   is separate;

   procedure Clear_Undo
     (Model : in out Window_Model) is separate;

   function Undo_Available
     (Model : Window_Model)
      return Boolean is separate;

   function Redo_Available
     (Model : Window_Model)
      return Boolean is separate;

   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is separate;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is separate;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is separate;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is separate;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is separate;

   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is separate;

   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean is separate;

   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector is separate;

   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector is separate;

   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy is separate;

   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is separate;

   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is separate;

   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural is separate;

   function Paste_Conflict_Name
     (Model : Window_Model)
      return String is separate;

   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is separate;

   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model) is separate;

   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is separate;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is separate;

   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is separate;

   procedure Clear_Paste_Conflict
     (Model : in out Window_Model) is separate;

   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is separate;

   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean is separate;

   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural is separate;

   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural is separate;

   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String is separate;

   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is separate;

   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is separate;

   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean is separate;

   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural is separate;

   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural is separate;

   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is separate;

   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Created_Identities
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Created_Tree_Revisions
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Verified_Created_Count
     (Model : Window_Model) return Natural is separate;

   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Replaced_Identities
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Replaced_Targets
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is separate;

   function Paste_Execution_Verified_Replaced_Count
     (Model : Window_Model) return Natural is separate;

   function Paste_Execution_Replaced_Extends_Verified
     (Model : Window_Model) return Boolean is separate;

   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString;
      Identity : String;
      Original_Path : String;
      Verified : Boolean) is separate;

   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String is separate;

   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model) is separate;

   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String;
      Identity    : String;
      Tree_Revision : String;
      Verified    : Boolean) is separate;

   function Paste_Execution_Write_Extends_Verified
     (Model : Window_Model) return Boolean is separate;

   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is separate;

   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is separate;

   function Paste_Execution_Copy_Context (Model : Window_Model) return Files.Copy_Context.Session is
     (Model.Paste_Exec.Copy_Context);

   procedure Set_Folder_Size_Targets (Model : in out Window_Model; Paths : Files.Folder_Size.Path_Vectors.Vector) is
   begin
      Files.Folder_Size.Set_Targets (Model.Folder_Scan, Paths);
   end Set_Folder_Size_Targets;

   procedure Cancel_Folder_Scan (Model : in out Window_Model) is
      Path : UString;
      Result : Files.File_System.Directory_Size_Result;
      Available : Boolean;
   begin
      Files.Folder_Size.Cancel (Model.Folder_Scan);
      loop
         Files.Folder_Size.Take (Model.Folder_Scan, Path, Result, Available);
         exit when not Available;
      end loop;
   end Cancel_Folder_Scan;

   procedure Poll_Folder_Sizes (Model : in out Window_Model) is
      Path : UString;
      Result : Files.File_System.Directory_Size_Result;
      Available : Boolean;
   begin
      Files.Folder_Size.Step (Model.Folder_Scan);
      loop
         Files.Folder_Size.Take (Model.Folder_Scan, Path, Result, Available);
         exit when not Available;
         if Is_Selected_Directory (Model, To_String (Path)) then
            Set_Folder_Size (Model, To_String (Path), Result);
         end if;
      end loop;
   end Poll_Folder_Sizes;

   function Folder_Scan_Is_Active (Model : Window_Model) return Boolean is
     (Files.Folder_Size.Is_Active (Model.Folder_Scan));
   function Folder_Scan_Target (Model : Window_Model) return String is
     (Files.Folder_Size.Target_For_Test (Model.Folder_Scan));

   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result) is separate;

   procedure Clear_Folder_Size
     (Model : in out Window_Model) is separate;

   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model) is separate;

   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean is separate;

   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result is separate;

   procedure Set_Volume_Space
     (Model   : in out Window_Model;
      Path    : String;
      Space   : Volume_Space;
      Sampled : Ada.Calendar.Time) is
   begin
      if Model.Volume_Space_Value /= Space or else To_String (Model.Volume_Path) /= Path then
         Model.Revision_Value := Model.Revision_Value + 1;
      end if;
      Model.Volume_Space_Value := Space;
      Model.Volume_Path := To_Unbounded_String (Path);
      Model.Volume_Sampled := Sampled;
   end Set_Volume_Space;

   function Volume_Space_Is_Current
     (Model : Window_Model;
      Now   : Ada.Calendar.Time)
      return Boolean is
   begin
      return Length (Model.Volume_Path) > 0
        and then To_String (Model.Volume_Path) = Current_Path (Model)
        and then Now - Model.Volume_Sampled <= Volume_Space_Refresh_Interval;
   end Volume_Space_Is_Current;

   function Volume_Space_Of
     (Model : Window_Model)
      return Volume_Space is
     (if To_String (Model.Volume_Path) = Current_Path (Model) then Model.Volume_Space_Value else (others => <>));

   procedure Set_Account_Name
     (Model : in out Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id;
      Name  : String)
   is
      --  Ids on one host are few, but bound the table so a long session over
      --  many foreign volumes cannot grow it without limit.
      Max_Account_Names : constant := 4096;
      Names : Account_Name_Maps.Map renames Model.Account_Names (Kind);
      Found : constant Account_Name_Maps.Cursor := Names.Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         if To_String (Account_Name_Maps.Element (Found)) /= Name then
            Names.Replace_Element (Found, To_Unbounded_String (Name));
            Model.Revision_Value := Model.Revision_Value + 1;
         end if;
         return;
      end if;
      if Natural (Names.Length) >= Max_Account_Names then
         Names.Clear;
      end if;
      Names.Insert (Id, To_Unbounded_String (Name));
      Model.Revision_Value := Model.Revision_Value + 1;
   end Set_Account_Name;

   function Account_Name_Known
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return Boolean is
     (Model.Account_Names (Kind).Contains (Id));

   function Account_Name
     (Model : Window_Model;
      Kind  : Account_Kind;
      Id    : Files.Types.Account_Id)
      return String
   is
      Found : constant Account_Name_Maps.Cursor := Model.Account_Names (Kind).Find (Id);
   begin
      if Account_Name_Maps.Has_Element (Found) then
         return To_String (Account_Name_Maps.Element (Found));
      end if;
      return "";
   end Account_Name;

   procedure Note_Account_Names_Sampled
     (Model : in out Window_Model) is
   begin
      Model.Account_Names_Sampled := Model.Revision_Value;
   end Note_Account_Names_Sampled;

   function Account_Names_Current
     (Model : Window_Model)
      return Boolean is
     (Model.Account_Names_Sampled = Model.Revision_Value);

   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0) is separate;

   procedure Close_Context_Menu
     (Model : in out Window_Model) is separate;

   procedure Set_Context_Menu_Highlight
     (Model : in out Window_Model;
      Row   : Natural) is separate;

   function Context_Menu_Highlight
     (Model : Window_Model)
      return Natural is separate;

   function Context_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is separate;

   function Context_Menu_X
     (Model : Window_Model)
      return Natural is separate;

   function Context_Menu_Y
     (Model : Window_Model)
      return Natural is separate;

   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target is separate;

   function Context_Menu_Item_Index
     (Model : Window_Model)
      return Natural is separate;

   procedure Selected_Visible_Bounds
     (Model : Window_Model;
      First : out Natural;
      Last  : out Natural)
   is
      Rows : constant Visible_Row_Vectors.Vector := Visible_Rows (Model);
   begin
      First := 0;
      Last := 0;
      for Index in Rows.First_Index .. Rows.Last_Index loop
         if Rows (Index).Selected then
            if First = 0 then
               First := Index;
            end if;
            Last := Index;
         end if;
      end loop;
   end Selected_Visible_Bounds;

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

end Files.Model;
