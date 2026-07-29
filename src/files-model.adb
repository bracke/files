with Ada.Calendar;
with Ada.Containers.Ordered_Sets;
with Ada.Strings.Fixed;

with Files.Command_Palette;
with Files.Localization;
with Files.Settings_Form;
with Files.Type_Ahead;
with Files.UTF8;

with Files.Model.Support;

package body Files.Model is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Files.File_System.Path_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Search_Scope;

   use Files.Model.Support;

   --  Hoisted from the former Clipboard child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Command_Palette child (now subunits).
   use Files.Model.Support;
   use type Files.Types.Focus_Target;

   --  Hoisted from the former Context_Menu child (now subunits).

   --  Hoisted from the former Error child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Filter child (now subunits).
   use Files.Model.Support;
   use type Files.Types.Search_Scope;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Folder_Sizes child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Label_Picker child (now subunits).

   --  Hoisted from the former Navigation child (now subunits).
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Ownership_Input child (now subunits).
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Panes child (now subunits).
   use Files.Model.Support;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Paste_Conflict child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Paste_Exec child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Path_Input child (now subunits).
   use Files.Model.Support;
   use type Files.File_System.Path_Status;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Quick_Look child (now subunits).
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Rename child (now subunits).
   use Files.Model.Support;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Selection child (now subunits).
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Temporary child (now subunits).
   use Files.Model.Support;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Tree_Panel child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Undo_Redo child (now subunits).

   --  Hoisted from the former View_Sort child (now subunits).
   use Files.Model.Support;

   --  Hoisted from the former Root_Selector child (now subunits).
   use Files.Model.Support;
   use Ada.Strings.Unbounded;
   use type Guikit.Input.Navigation_Direction;

   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector)
   is
      Entries : Files.File_System.Root_Entry_Vectors.Vector;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Root_Entries := Roots;
      Model.Root_Selector_Open := not Roots.Is_Empty;
      Model.Root_Selected := (if Model.Root_Selector_Open then 1 else 0);
      Model.Settings_Pane_Open := False;
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Open_Root_Selector;

   function Revision
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Revision_Value;
   end Revision;

   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.File_System.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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

   --  The navigation operations are subunits of Files.Model.
   function Current_Path (Model : Window_Model) return String
     is separate;

   function Directory_Signature_Of (Model : Window_Model) return Files.File_System.Directory_Signature
     is separate;

   procedure Set_Directory_Signature (Model : in out Window_Model; Signature : Files.File_System.Directory_Signature)
     is separate;

   function Home_Path (Model : Window_Model) return String
     is separate;

   function Item_Count (Model : Window_Model) return Natural
     is separate;

   function Visible_Count (Model : Window_Model) return Natural
     is separate;

   function Hidden_Item_Count (Model : Window_Model) return Natural
     is separate;

   function Visible_Item (Model : Window_Model; Visible_Index : Positive) return Files.File_System.Directory_Item
     is separate;

   function Visible_Rows (Model : Window_Model) return Visible_Row_Vectors.Vector
     is separate;

   function In_Recent_View (Model : Window_Model) return Boolean
     is separate;

   procedure Note_Recent_Open (Model : in out Window_Model; Path : String)
     is separate;

   function Take_Recent_Opens (Model : in out Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Can_Go_Back (Model : Window_Model) return Boolean
     is separate;

   function Can_Go_Forward (Model : Window_Model) return Boolean
     is separate;

   --  The view sort operations are subunits of Files.Model.
   function View_Mode_Of (Model : Window_Model) return Files.Types.View_Mode
     is separate;

   procedure Set_View_Mode (Model : in out Window_Model; Mode : Files.Types.View_Mode)
     is separate;

   function Sort_Field_Of (Model : Window_Model) return Sort_Field
     is separate;

   function Sort_Is_Ascending (Model : Window_Model) return Boolean
     is separate;

   procedure Select_Sort_Field (Model : in out Window_Model; Field : Sort_Field)
     is separate;

   procedure Apply_Sort (Model : in out Window_Model; Field : Sort_Field; Ascending : Boolean)
     is separate;

   procedure Toggle_Sort_Menu (Model : in out Window_Model)
     is separate;

   procedure Close_Sort_Menu (Model : in out Window_Model)
     is separate;

   function Sort_Menu_Is_Open (Model : Window_Model) return Boolean
     is separate;

   --  The filter operations are subunits of Files.Model.
   procedure Set_Filter (Model : in out Window_Model; Text : String)
     is separate;

   function Filter_Text (Model : Window_Model) return String
     is separate;

   procedure Clear_Filter (Model : in out Window_Model)
     is separate;

   function Search_Scope_Of (Model : Window_Model) return Files.Types.Search_Scope
     is separate;

   procedure Set_Search_Scope (Model : in out Window_Model; Scope : Files.Types.Search_Scope)
     is separate;

   function Search_Results_Are_Active (Model : Window_Model) return Boolean
     is separate;

   procedure Note_Search_Results (Model : in out Window_Model; Scope : Files.Types.Search_Scope)
     is separate;

   procedure Clear_Search_Results (Model : in out Window_Model)
     is separate;

   procedure Type_Ahead_Input (Model : in out Window_Model; Text : String; Matched : out Boolean)
     is separate;

   procedure Reset_Type_Ahead (Model : in out Window_Model)
     is separate;

   function Type_Ahead_Buffer (Model : Window_Model) return String
     is separate;

   procedure Focus_Filter_Input (Model : in out Window_Model)
     is separate;

   --  The selection operations are subunits of Files.Model.
   procedure Select_Visible (Model : in out Window_Model; Visible_Index : Positive)
     is separate;

   procedure Toggle_Visible_Selection (Model : in out Window_Model; Visible_Index : Positive)
     is separate;

   procedure Select_Visible_Range (Model : in out Window_Model; Anchor_Index : Positive; Target_Index : Positive)
     is separate;

   procedure Select_All_Visible (Model : in out Window_Model)
     is separate;

   procedure Clear_Selection (Model : in out Window_Model)
     is separate;

   procedure Invert_Selection (Model : in out Window_Model)
     is separate;

   procedure Deselect_All (Model : in out Window_Model)
     is separate;

   procedure Move_Selection (Model : in out Window_Model; Direction : Guikit.Input.Navigation_Direction)
     is separate;

   procedure Select_First_Visible (Model : in out Window_Model)
     is separate;

   procedure Select_Last_Visible (Model : in out Window_Model)
     is separate;

   procedure Move_Selection_By_Page (Model : in out Window_Model; Page_Rows : Positive; Down : Boolean)
     is separate;

   procedure Set_Selection_Grid_Columns (Model : in out Window_Model; Columns : Positive)
     is separate;

   function Selection_Grid_Columns (Model : Window_Model) return Positive
     is separate;

   function Is_Selected (Model : Window_Model; Visible_Index : Positive) return Boolean
     is separate;

   function Selected_Index (Model : Window_Model) return Natural
     is separate;

   function Selected_Count (Model : Window_Model) return Natural
     is separate;

   function Selected_Name (Model : Window_Model) return String
     is separate;

   function Selected_Item (Model : Window_Model) return Files.File_System.Directory_Item
     is separate;

   function Selected_Items (Model : Window_Model) return Files.File_System.Item_Vectors.Vector
     is separate;

   function Selected_Item_Is_Temporary (Model : Window_Model) return Boolean
     is separate;

   function Selection_Includes_Temporary (Model : Window_Model) return Boolean
     is separate;

   function Focus (Model : Window_Model) return Files.Types.Focus_Target
     is separate;

   function Select_By_Name (Model : in out Window_Model; Name : String) return Boolean
     is separate;

   function Is_Selected_Directory (Model : Window_Model; Path : String) return Boolean
     is separate;

   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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

   procedure Go_Back
     (Model : in out Window_Model) is
      Previous : UString;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
      Navigate_To (Model, Home_Path (Model), Empty_Items);
   end Go_Home;

   --  The path input operations are subunits of Files.Model.
   procedure Focus_Path_Input (Model : in out Window_Model)
     is separate;

   procedure Set_Path_Input_Text (Model : in out Window_Model; Text : String)
     is separate;

   function Path_Input_Text (Model : Window_Model) return String
     is separate;

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector)
     is separate;

   function Path_Input_Is_Valid (Model : Window_Model) return Boolean
     is separate;

   function Path_Input_Error_Key (Model : Window_Model) return String
     is separate;

   --  The command palette operations are subunits of Files.Model.
   procedure Focus_Command_Palette_Input (Model : in out Window_Model)
     is separate;

   procedure Open_Command_Palette (Model : in out Window_Model)
     is separate;

   procedure Close_Command_Palette (Model : in out Window_Model)
     is separate;

   procedure Toggle_Command_Palette (Model : in out Window_Model)
     is separate;

   function Command_Palette_Is_Open (Model : Window_Model) return Boolean
     is separate;

   function Palette_Query (Model : Window_Model) return String
     is separate;

   procedure Palette_Set_Query (Model : in out Window_Model; Text : String)
     is separate;

   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer)
     is separate;

   procedure Palette_Select_First (Model : in out Window_Model)
     is separate;

   procedure Palette_Select_Last (Model : in out Window_Model)
     is separate;

   procedure Palette_Page (Model : in out Window_Model; Down : Boolean)
     is separate;

   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean
     is separate;

   function Palette_Selected_Id (Model : Window_Model) return Natural
     is separate;

   function Palette_Result_Count (Model : Window_Model) return Natural
     is separate;

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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
     is separate;

   function Command_Palette_Mode_Of (Model : Window_Model) return Palette_Mode
     is separate;

   procedure Set_Command_Palette_Mode (Model : in out Window_Model; Mode : Palette_Mode)
     is separate;

   --  The rename operations are subunits of Files.Model.
   procedure Focus_Rename_Input (Model : in out Window_Model)
     is separate;

   function Rename_Is_Enabled (Model : Window_Model) return Boolean
     is separate;

   function Rename_Behavior return Rename_Policy
     is separate;

   procedure Toggle_Rename (Model : in out Window_Model)
     is separate;

   function Rename_Is_Active (Model : Window_Model) return Boolean
     is separate;

   function Rename_Field_Count (Model : Window_Model) return Natural
     is separate;

   function Rename_Text (Model : Window_Model) return String
     is separate;

   procedure Set_Rename_Text (Model : in out Window_Model; Text : String)
     is separate;

   function Rename_Insert_At_Carets (Model : in out Window_Model; Text : String) return Boolean
     is separate;

   function Rename_Delete_Backward (Model : in out Window_Model) return Boolean
     is separate;

   function Rename_Delete_Forward (Model : in out Window_Model) return Boolean
     is separate;

   function Rename_Delete_Word_Backward (Model : in out Window_Model) return Boolean
     is separate;

   function Rename_Delete_Word_Forward (Model : in out Window_Model) return Boolean
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

   function Rename_Set_All_Carets_Home (Model : in out Window_Model) return Boolean
     is separate;

   function Rename_Set_All_Carets_End (Model : in out Window_Model) return Boolean
     is separate;

   procedure Set_Rename_Caret (Model : in out Window_Model; Visible_Index : Natural; Position : Natural)
     is separate;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
     is separate;

   function Rename_Targets (Model : Window_Model) return Rename_Target_Vectors.Vector
     is separate;

   procedure Resume_Rename (Model : in out Window_Model; Text : String)
     is separate;

   --  The ownership input operations are subunits of Files.Model.
   procedure Focus_Ownership_Input (Model : in out Window_Model; Editing_Group : Boolean)
     is separate;

   function Ownership_Input_Text (Model : Window_Model) return String
     is separate;

   procedure Set_Ownership_Input_Text (Model : in out Window_Model; Text : String)
     is separate;

   function Ownership_Editing_Group (Model : Window_Model) return Boolean
     is separate;

   --  The root selector operations are subunits of Files.Model.

   procedure Close_Root_Selector (Model : in out Window_Model)
     is separate;

   function Root_Selector_Is_Open (Model : Window_Model) return Boolean
     is separate;

   function Root_Count (Model : Window_Model) return Natural
     is separate;

   function Root_Selected_Index (Model : Window_Model) return Natural
     is separate;

   procedure Set_Root_Selected_Index (Model : in out Window_Model; Index : Natural)
     is separate;

   procedure Move_Root_Selection (Model : in out Window_Model; Direction : Guikit.Input.Navigation_Direction)
     is separate;

   function Root_Path (Model : Window_Model; Index : Positive) return String
     is separate;

   function Root_Label (Model : Window_Model; Index : Positive) return String
     is separate;

   function Root_Kind (Model : Window_Model; Index : Positive) return Files.File_System.Root_Kind
     is separate;

   function Root_Is_Removable (Model : Window_Model; Index : Positive) return Boolean
     is separate;

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

   --  The tree panel operations are subunits of Files.Model.
   procedure Toggle_Tree_Panel (Model : in out Window_Model)
     is separate;

   procedure Open_Tree_Panel (Model : in out Window_Model)
     is separate;

   procedure Close_Tree_Panel (Model : in out Window_Model)
     is separate;

   function Tree_Panel_Is_Open (Model : Window_Model) return Boolean
     is separate;

   function Tree_Is_Seeded (Model : Window_Model) return Boolean
     is separate;

   procedure Seed_Tree (Model : in out Window_Model; Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
     is separate;

   function Tree_Node_Count (Model : Window_Model) return Natural
     is separate;

   function Tree_Node_Path (Model : Window_Model; Index : Positive) return String
     is separate;

   function Tree_Node_Is_Loaded (Model : Window_Model; Index : Positive) return Boolean
     is separate;

   function Tree_Node_Is_Expanded (Model : Window_Model; Index : Positive) return Boolean
     is separate;

   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
     is separate;

   procedure Tree_Set_Expanded (Model : in out Window_Model; Index : Positive; Expanded : Boolean)
     is separate;

   procedure Tree_Toggle_Expanded (Model : in out Window_Model; Index : Positive)
     is separate;

   function Tree_Visible_Rows (Model : Window_Model) return Files.Folder_Tree.Visible_Row_Vectors.Vector
     is separate;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String)
     is separate;

   procedure Set_Tree_Pick_Target (Model : in out Window_Model; Target : String)
     is separate;

   procedure Clear_Tree_Pick (Model : in out Window_Model)
     is separate;

   function Tree_Pick_Mode_Of (Model : Window_Model) return Tree_Pick_Mode
     is separate;

   function Tree_Pick_Is_Active (Model : Window_Model) return Boolean
     is separate;

   function Tree_Pick_Sources (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Tree_Pick_Target (Model : Window_Model) return String
     is separate;

   --  The panes operations are subunits of Files.Model.
   procedure Toggle_Info_Pane (Model : in out Window_Model)
     is separate;

   function Info_Pane_Is_Open (Model : Window_Model) return Boolean
     is separate;

   procedure Ensure_Selected_Item_Extra (Model : in out Window_Model)
     is separate;

   procedure Toggle_Settings_Pane (Model : in out Window_Model)
     is separate;

   function Settings_Pane_Is_Open (Model : Window_Model) return Boolean
     is separate;

   procedure Begin_Settings_Edit (Model : in out Window_Model; Draft : Files.Settings.Settings_Draft)
     is separate;

   function Settings_Draft_Of (Model : Window_Model) return Files.Settings.Settings_Draft
     is separate;

   procedure Set_Settings_Draft (Model : in out Window_Model; Draft : Files.Settings.Settings_Draft)
     is separate;

   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer)
     is separate;

   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean)
     is separate;

   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String)
     is separate;

   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer)
     is separate;

   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean
     is separate;

   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change
     is separate;

   function Settings_Focused_Value (Model : Window_Model) return String
     is separate;

   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural)
     is separate;

   function Settings_Section_Count (Model : Window_Model) return Natural
     is separate;

   function Settings_Active_Section (Model : Window_Model) return Natural
     is separate;

   procedure Settings_Begin_Capture (Model : in out Window_Model)
     is separate;

   function Settings_Is_Capturing (Model : Window_Model) return Boolean
     is separate;

   function Settings_Capturing_Key (Model : Window_Model) return String
     is separate;

   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String)
     is separate;

   procedure Settings_Cancel_Capture (Model : in out Window_Model)
     is separate;

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

   procedure Scroll_Info_Pane (Model : in out Window_Model; Lines : Integer)
     is separate;

   function Info_Pane_Scroll_Lines (Model : Window_Model) return Natural
     is separate;

   procedure Scroll_Main_View (Model : in out Window_Model; Lines : Integer)
     is separate;

   function Main_View_Scroll_Lines (Model : Window_Model) return Natural
     is separate;

   procedure Set_Main_View_Scroll_Lines (Model : in out Window_Model; Lines : Natural)
     is separate;

   procedure Set_Info_Pane_Scroll_Lines (Model : in out Window_Model; Lines : Natural)
     is separate;

   --  The label picker operations are subunits of Files.Model.
   procedure Set_Open_With_Targets (Model : in out Window_Model; Targets : Files.Types.String_Vectors.Vector)
     is separate;

   function Open_With_Targets (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   procedure Open_Label_Picker (Model : in out Window_Model)
     is separate;

   procedure Close_Label_Picker (Model : in out Window_Model)
     is separate;

   function Label_Picker_Is_Open (Model : Window_Model) return Boolean
     is separate;

   --  The quick look operations are subunits of Files.Model.
   procedure Open_Quick_Look (Model : in out Window_Model; Content : Files.Quick_Look.Quick_Look_Content)
     is separate;

   procedure Close_Quick_Look (Model : in out Window_Model)
     is separate;

   procedure Toggle_Quick_Look (Model : in out Window_Model)
     is separate;

   function Quick_Look_Is_Open (Model : Window_Model) return Boolean
     is separate;

   function Quick_Look_Path (Model : Window_Model) return String
     is separate;

   function Quick_Look_Content_Of (Model : Window_Model) return Files.Quick_Look.Quick_Look_Content
     is separate;

   --  The temporary operations are subunits of Files.Model.
   procedure Begin_Create_File (Model : in out Window_Model; Name : String)
     is separate;

   procedure Begin_Create_Folder (Model : in out Window_Model; Name : String)
     is separate;

   function Temporary_Item_Is_Active (Model : Window_Model) return Boolean
     is separate;

   function Temporary_Item_Is_Directory (Model : Window_Model) return Boolean
     is separate;

   function Temporary_Item_Name (Model : Window_Model) return String
     is separate;

   procedure Cancel_Create_File (Model : in out Window_Model)
     is separate;

   procedure Clear_Edit_State
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
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
      Model.Revision_Value := Model.Revision_Value + 1;
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

   --  The error operations are subunits of Files.Model.
   procedure Set_Error (Model : in out Window_Model; Error_Key : String)
     is separate;

   function Last_Error_Key (Model : Window_Model) return String
     is separate;

   --  The clipboard operations are subunits of Files.Model.
   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode)
     is separate;

   procedure Clear_Clipboard (Model : in out Window_Model)
     is separate;

   function Clipboard_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Clipboard_Mode_Of (Model : Window_Model) return Clipboard_Mode
     is separate;

   function Clipboard_Has_Items (Model : Window_Model) return Boolean
     is separate;

   procedure Set_System_Clipboard_Request (Model : in out Window_Model; Text : String)
     is separate;

   function System_Clipboard_Request_Pending (Model : Window_Model) return Boolean
     is separate;

   function System_Clipboard_Request_Text (Model : Window_Model) return String
     is separate;

   procedure Clear_System_Clipboard_Request (Model : in out Window_Model)
     is separate;

   --  The undo redo operations are subunits of Files.Model.
   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector)
     is separate;

   procedure Clear_Undo (Model : in out Window_Model)
     is separate;

   function Undo_Available (Model : Window_Model) return Boolean
     is separate;

   function Redo_Available (Model : Window_Model) return Boolean
     is separate;

   procedure Take_Undo (Model : in out Window_Model; Action : out Undo_Entry; Found : out Boolean)
     is separate;

   procedure Take_Redo (Model : in out Window_Model; Action : out Undo_Entry; Found : out Boolean)
     is separate;

   procedure Push_Redo (Model : in out Window_Model; Action : Undo_Entry)
     is separate;

   procedure Push_Undo (Model : in out Window_Model; Action : Undo_Entry)
     is separate;

   function Undo_Kind_Of (Model : Window_Model) return Undo_Action_Kind
     is separate;

   function Undo_From_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Undo_To_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   --  The paste conflict operations are subunits of Files.Model.
   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True)
     is separate;

   function Paste_Conflict_Is_Active (Model : Window_Model) return Boolean
     is separate;

   function Paste_Conflict_Items (Model : Window_Model) return Files.Paste.Work_Item_Vectors.Vector
     is separate;

   function Paste_Conflict_Existing (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Paste_Conflict_Overrides (Model : Window_Model) return Files.Paste.Item_Decision_Vectors.Vector
     is separate;

   function Paste_Conflict_Policy (Model : Window_Model) return Files.Paste.Conflict_Policy
     is separate;

   function Paste_Conflict_Mode (Model : Window_Model) return Files.File_System.Drop_Import_Mode
     is separate;

   function Paste_Conflict_Clears_Clipboard (Model : Window_Model) return Boolean
     is separate;

   function Paste_Conflict_Index (Model : Window_Model) return Natural
     is separate;

   function Paste_Conflict_Name (Model : Window_Model) return String
     is separate;

   function Paste_Conflict_Apply_All (Model : Window_Model) return Boolean
     is separate;

   procedure Toggle_Paste_Conflict_Apply_All (Model : in out Window_Model)
     is separate;

   procedure Set_Paste_Conflict_Policy (Model : in out Window_Model; Policy : Files.Paste.Conflict_Policy)
     is separate;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision)
     is separate;

   procedure Set_Paste_Conflict_Index (Model : in out Window_Model; Index : Positive)
     is separate;

   procedure Clear_Paste_Conflict (Model : in out Window_Model)
     is separate;

   --  The paste exec operations are subunits of Files.Model.
   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
     is separate;

   function Paste_Execution_Is_Active (Model : Window_Model) return Boolean
     is separate;

   function Paste_Execution_Done (Model : Window_Model) return Natural
     is separate;

   function Paste_Execution_Total (Model : Window_Model) return Natural
     is separate;

   function Paste_Execution_Current_Name (Model : Window_Model) return String
     is separate;

   function Paste_Execution_Mode (Model : Window_Model) return Files.File_System.Drop_Import_Mode
     is separate;

   function Paste_Execution_Clears_Clipboard (Model : Window_Model) return Boolean
     is separate;

   function Paste_Execution_Cancelled (Model : Window_Model) return Boolean
     is separate;

   function Paste_Execution_Cursor (Model : Window_Model) return Natural
     is separate;

   function Paste_Execution_Action_Count (Model : Window_Model) return Natural
     is separate;

   function Paste_Execution_Action (Model : Window_Model; Index : Positive) return Files.Paste.Resolved_Action
     is separate;

   function Paste_Execution_Undo_From (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Paste_Execution_Undo_To (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   function Paste_Execution_Replaced_Trash (Model : Window_Model) return Files.Types.String_Vectors.Vector
     is separate;

   procedure Record_Paste_Execution_Replaced_Trash (Model : in out Window_Model; Trash_Path : Files.Types.UString)
     is separate;

   function Paste_Execution_First_Dest (Model : Window_Model) return String
     is separate;

   procedure Skip_Paste_Execution_Action (Model : in out Window_Model)
     is separate;

   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String)
     is separate;

   procedure Cancel_Paste_Execution (Model : in out Window_Model)
     is separate;

   procedure Clear_Paste_Execution (Model : in out Window_Model)
     is separate;

   --  The folder sizes operations are subunits of Files.Model.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result)
     is separate;

   procedure Clear_Folder_Size (Model : in out Window_Model)
     is separate;

   procedure Prune_Folder_Sizes_To_Selection (Model : in out Window_Model)
     is separate;

   function Folder_Size_Cached_For (Model : Window_Model; Path : String) return Boolean
     is separate;

   function Folder_Size_Value (Model : Window_Model; Path : String) return Files.File_System.Directory_Size_Result
     is separate;

   --  The context menu operations are subunits of Files.Model.
   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0)
     is separate;

   procedure Close_Context_Menu (Model : in out Window_Model)
     is separate;

   function Context_Menu_Is_Open (Model : Window_Model) return Boolean
     is separate;

   function Context_Menu_X (Model : Window_Model) return Natural
     is separate;

   function Context_Menu_Y (Model : Window_Model) return Natural
     is separate;

   function Context_Menu_Target_Of (Model : Window_Model) return Context_Menu_Target
     is separate;

   function Context_Menu_Item_Index (Model : Window_Model) return Natural
     is separate;

end Files.Model;
