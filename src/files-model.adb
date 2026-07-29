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

   package Navigation is
      function Current_Path
        (Model : Window_Model)
         return String;

      function Directory_Signature_Of
        (Model : Window_Model)
         return Files.File_System.Directory_Signature;

      procedure Set_Directory_Signature
        (Model     : in out Window_Model;
         Signature : Files.File_System.Directory_Signature);

      function Home_Path
        (Model : Window_Model)
         return String;

      function Item_Count
        (Model : Window_Model)
         return Natural;

      function Visible_Count
        (Model : Window_Model)
         return Natural;

      function Hidden_Item_Count
        (Model : Window_Model)
         return Natural;

      function Visible_Item
        (Model         : Window_Model;
         Visible_Index : Positive)
         return Files.File_System.Directory_Item;

      function Visible_Rows
        (Model : Window_Model)
         return Visible_Row_Vectors.Vector;

      function In_Recent_View
        (Model : Window_Model)
         return Boolean;

      procedure Note_Recent_Open
        (Model : in out Window_Model;
         Path  : String);

      function Take_Recent_Opens
        (Model : in out Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Can_Go_Back
        (Model : Window_Model)
         return Boolean;

      function Can_Go_Forward
        (Model : Window_Model)
         return Boolean;
   end Navigation;
   package body Navigation is separate;

   --  The navigation operations now live in the
   --  Files.Model.Navigation child; these renamings keep them on the public API.
   function Current_Path (Model : Window_Model) return String
     renames Navigation.Current_Path;

   function Directory_Signature_Of (Model : Window_Model) return Files.File_System.Directory_Signature
     renames Navigation.Directory_Signature_Of;

   procedure Set_Directory_Signature (Model : in out Window_Model; Signature : Files.File_System.Directory_Signature)
     renames Navigation.Set_Directory_Signature;

   function Home_Path (Model : Window_Model) return String
     renames Navigation.Home_Path;

   function Item_Count (Model : Window_Model) return Natural
     renames Navigation.Item_Count;

   function Visible_Count (Model : Window_Model) return Natural
     renames Navigation.Visible_Count;

   function Hidden_Item_Count (Model : Window_Model) return Natural
     renames Navigation.Hidden_Item_Count;

   function Visible_Item (Model : Window_Model; Visible_Index : Positive) return Files.File_System.Directory_Item
     renames Navigation.Visible_Item;

   function Visible_Rows (Model : Window_Model) return Visible_Row_Vectors.Vector
     renames Navigation.Visible_Rows;

   function In_Recent_View (Model : Window_Model) return Boolean
     renames Navigation.In_Recent_View;

   procedure Note_Recent_Open (Model : in out Window_Model; Path : String)
     renames Navigation.Note_Recent_Open;

   function Take_Recent_Opens (Model : in out Window_Model) return Files.Types.String_Vectors.Vector
     renames Navigation.Take_Recent_Opens;

   function Can_Go_Back (Model : Window_Model) return Boolean
     renames Navigation.Can_Go_Back;

   function Can_Go_Forward (Model : Window_Model) return Boolean
     renames Navigation.Can_Go_Forward;

   package View_Sort is
      function View_Mode_Of
        (Model : Window_Model)
         return Files.Types.View_Mode;

      procedure Set_View_Mode
        (Model : in out Window_Model;
         Mode  : Files.Types.View_Mode);

      function Sort_Field_Of
        (Model : Window_Model)
         return Sort_Field;

      function Sort_Is_Ascending
        (Model : Window_Model)
         return Boolean;

      procedure Select_Sort_Field
        (Model : in out Window_Model;
         Field : Sort_Field);

      procedure Apply_Sort
        (Model     : in out Window_Model;
         Field     : Sort_Field;
         Ascending : Boolean);

      procedure Toggle_Sort_Menu
        (Model : in out Window_Model);

      procedure Close_Sort_Menu
        (Model : in out Window_Model);

      function Sort_Menu_Is_Open
        (Model : Window_Model)
         return Boolean;

      procedure Move_Sort_Menu_Highlight
        (Model : in out Window_Model;
         Delta_Value : Integer);

      function Sort_Menu_Highlight
        (Model : Window_Model)
         return Natural;

      function Sort_Menu_Highlight_Field
        (Model : Window_Model)
         return Sort_Field;
   end View_Sort;
   package body View_Sort is separate;

   --  The view sort operations now live in the
   --  Files.Model.View_Sort child; these renamings keep them on the public API.
   function View_Mode_Of (Model : Window_Model) return Files.Types.View_Mode
     renames View_Sort.View_Mode_Of;

   procedure Set_View_Mode (Model : in out Window_Model; Mode : Files.Types.View_Mode)
     renames View_Sort.Set_View_Mode;

   function Sort_Field_Of (Model : Window_Model) return Sort_Field
     renames View_Sort.Sort_Field_Of;

   function Sort_Is_Ascending (Model : Window_Model) return Boolean
     renames View_Sort.Sort_Is_Ascending;

   procedure Select_Sort_Field (Model : in out Window_Model; Field : Sort_Field)
     renames View_Sort.Select_Sort_Field;

   procedure Apply_Sort (Model : in out Window_Model; Field : Sort_Field; Ascending : Boolean)
     renames View_Sort.Apply_Sort;

   procedure Toggle_Sort_Menu (Model : in out Window_Model)
     renames View_Sort.Toggle_Sort_Menu;

   procedure Close_Sort_Menu (Model : in out Window_Model)
     renames View_Sort.Close_Sort_Menu;

   function Sort_Menu_Is_Open (Model : Window_Model) return Boolean
     renames View_Sort.Sort_Menu_Is_Open;

   procedure Move_Sort_Menu_Highlight (Model : in out Window_Model; Delta_Value : Integer)
     renames View_Sort.Move_Sort_Menu_Highlight;

   function Sort_Menu_Highlight (Model : Window_Model) return Natural
     renames View_Sort.Sort_Menu_Highlight;

   function Sort_Menu_Highlight_Field (Model : Window_Model) return Sort_Field
     renames View_Sort.Sort_Menu_Highlight_Field;

   package Filter is
      procedure Set_Filter
        (Model : in out Window_Model;
         Text  : String);

      function Filter_Text
        (Model : Window_Model)
         return String;

      procedure Clear_Filter
        (Model : in out Window_Model);

      function Search_Scope_Of
        (Model : Window_Model)
         return Files.Types.Search_Scope;

      procedure Set_Search_Scope
        (Model : in out Window_Model;
         Scope : Files.Types.Search_Scope);

      function Search_Results_Are_Active
        (Model : Window_Model)
         return Boolean;

      procedure Note_Search_Results
        (Model : in out Window_Model;
         Scope : Files.Types.Search_Scope);

      procedure Clear_Search_Results
        (Model : in out Window_Model);

      procedure Type_Ahead_Input
        (Model   : in out Window_Model;
         Text    : String;
         Matched : out Boolean);

      procedure Reset_Type_Ahead
        (Model : in out Window_Model);

      function Type_Ahead_Buffer
        (Model : Window_Model)
         return String;

      procedure Focus_Filter_Input
        (Model : in out Window_Model);
   end Filter;
   package body Filter is separate;

   --  The filter operations now live in the
   --  Files.Model.Filter child; these renamings keep them on the public API.
   procedure Set_Filter (Model : in out Window_Model; Text : String)
     renames Filter.Set_Filter;

   function Filter_Text (Model : Window_Model) return String
     renames Filter.Filter_Text;

   procedure Clear_Filter (Model : in out Window_Model)
     renames Filter.Clear_Filter;

   function Search_Scope_Of (Model : Window_Model) return Files.Types.Search_Scope
     renames Filter.Search_Scope_Of;

   procedure Set_Search_Scope (Model : in out Window_Model; Scope : Files.Types.Search_Scope)
     renames Filter.Set_Search_Scope;

   function Search_Results_Are_Active (Model : Window_Model) return Boolean
     renames Filter.Search_Results_Are_Active;

   procedure Note_Search_Results (Model : in out Window_Model; Scope : Files.Types.Search_Scope)
     renames Filter.Note_Search_Results;

   procedure Clear_Search_Results (Model : in out Window_Model)
     renames Filter.Clear_Search_Results;

   procedure Type_Ahead_Input (Model : in out Window_Model; Text : String; Matched : out Boolean)
     renames Filter.Type_Ahead_Input;

   procedure Reset_Type_Ahead (Model : in out Window_Model)
     renames Filter.Reset_Type_Ahead;

   function Type_Ahead_Buffer (Model : Window_Model) return String
     renames Filter.Type_Ahead_Buffer;

   procedure Focus_Filter_Input (Model : in out Window_Model)
     renames Filter.Focus_Filter_Input;

   package Selection is
      procedure Select_Visible
        (Model         : in out Window_Model;
         Visible_Index : Positive);

      procedure Toggle_Visible_Selection
        (Model         : in out Window_Model;
         Visible_Index : Positive);

      procedure Select_Visible_Range
        (Model        : in out Window_Model;
         Anchor_Index : Positive;
         Target_Index : Positive);

      procedure Select_All_Visible
        (Model : in out Window_Model);

      procedure Clear_Selection
        (Model : in out Window_Model);

      procedure Invert_Selection
        (Model : in out Window_Model);

      procedure Deselect_All
        (Model : in out Window_Model);

      procedure Move_Selection
        (Model     : in out Window_Model;
         Direction : Guikit.Input.Navigation_Direction);

      procedure Select_First_Visible
        (Model : in out Window_Model);

      procedure Select_Last_Visible
        (Model : in out Window_Model);

      procedure Move_Selection_By_Page
        (Model     : in out Window_Model;
         Page_Rows : Positive;
         Down      : Boolean);

      procedure Set_Selection_Grid_Columns
        (Model   : in out Window_Model;
         Columns : Positive);

      function Selection_Grid_Columns
        (Model : Window_Model)
         return Positive;

      function Is_Selected
        (Model         : Window_Model;
         Visible_Index : Positive)
         return Boolean;

      function Selected_Index
        (Model : Window_Model)
         return Natural;

      function Selected_Count
        (Model : Window_Model)
         return Natural;

      function Selected_Name
        (Model : Window_Model)
         return String;

      function Selected_Item
        (Model : Window_Model)
         return Files.File_System.Directory_Item;

      function Selected_Items
        (Model : Window_Model)
         return Files.File_System.Item_Vectors.Vector;

      function Selected_Item_Is_Temporary
        (Model : Window_Model)
         return Boolean;

      function Selection_Includes_Temporary
        (Model : Window_Model)
         return Boolean;

      function Focus
        (Model : Window_Model)
         return Files.Types.Focus_Target;

      function Select_By_Name
        (Model : in out Window_Model;
         Name  : String)
         return Boolean;

      function Is_Selected_Directory
        (Model : Window_Model;
         Path  : String)
         return Boolean;
   end Selection;
   package body Selection is separate;

   --  The selection operations now live in the
   --  Files.Model.Selection child; these renamings keep them on the public API.
   procedure Select_Visible (Model : in out Window_Model; Visible_Index : Positive)
     renames Selection.Select_Visible;

   procedure Toggle_Visible_Selection (Model : in out Window_Model; Visible_Index : Positive)
     renames Selection.Toggle_Visible_Selection;

   procedure Select_Visible_Range (Model : in out Window_Model; Anchor_Index : Positive; Target_Index : Positive)
     renames Selection.Select_Visible_Range;

   procedure Select_All_Visible (Model : in out Window_Model)
     renames Selection.Select_All_Visible;

   procedure Clear_Selection (Model : in out Window_Model)
     renames Selection.Clear_Selection;

   procedure Invert_Selection (Model : in out Window_Model)
     renames Selection.Invert_Selection;

   procedure Deselect_All (Model : in out Window_Model)
     renames Selection.Deselect_All;

   procedure Move_Selection (Model : in out Window_Model; Direction : Guikit.Input.Navigation_Direction)
     renames Selection.Move_Selection;

   procedure Select_First_Visible (Model : in out Window_Model)
     renames Selection.Select_First_Visible;

   procedure Select_Last_Visible (Model : in out Window_Model)
     renames Selection.Select_Last_Visible;

   procedure Move_Selection_By_Page (Model : in out Window_Model; Page_Rows : Positive; Down : Boolean)
     renames Selection.Move_Selection_By_Page;

   procedure Set_Selection_Grid_Columns (Model : in out Window_Model; Columns : Positive)
     renames Selection.Set_Selection_Grid_Columns;

   function Selection_Grid_Columns (Model : Window_Model) return Positive
     renames Selection.Selection_Grid_Columns;

   function Is_Selected (Model : Window_Model; Visible_Index : Positive) return Boolean
     renames Selection.Is_Selected;

   function Selected_Index (Model : Window_Model) return Natural
     renames Selection.Selected_Index;

   function Selected_Count (Model : Window_Model) return Natural
     renames Selection.Selected_Count;

   function Selected_Name (Model : Window_Model) return String
     renames Selection.Selected_Name;

   function Selected_Item (Model : Window_Model) return Files.File_System.Directory_Item
     renames Selection.Selected_Item;

   function Selected_Items (Model : Window_Model) return Files.File_System.Item_Vectors.Vector
     renames Selection.Selected_Items;

   function Selected_Item_Is_Temporary (Model : Window_Model) return Boolean
     renames Selection.Selected_Item_Is_Temporary;

   function Selection_Includes_Temporary (Model : Window_Model) return Boolean
     renames Selection.Selection_Includes_Temporary;

   function Focus (Model : Window_Model) return Files.Types.Focus_Target
     renames Selection.Focus;

   function Select_By_Name (Model : in out Window_Model; Name : String) return Boolean
     renames Selection.Select_By_Name;

   function Is_Selected_Directory (Model : Window_Model; Path : String) return Boolean
     renames Selection.Is_Selected_Directory;

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
      Model.Revision_Value := Model.Revision_Value + 1;
      --  Leaving the virtual recent view does not preserve it in history (its
      --  path is synthetic); an ordinary directory change pushes back history as
      --  usual.
      if not Model.Recent_View_Active and then Current_Path (Model) /= Directory_Path then
         Push_Back_History (Model);
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
         Push_Back_History (Model);
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

   package Path_Input is
      procedure Focus_Path_Input
        (Model : in out Window_Model);

      procedure Set_Path_Input_Text
        (Model : in out Window_Model;
         Text  : String);

      function Path_Input_Text
        (Model : Window_Model)
         return String;

      procedure Commit_Path_Input
        (Model  : in out Window_Model;
         Result : Files.File_System.Path_Result;
         Items  : Files.File_System.Item_Vectors.Vector);

      function Path_Input_Is_Valid
        (Model : Window_Model)
         return Boolean;

      function Path_Input_Error_Key
        (Model : Window_Model)
         return String;
   end Path_Input;
   package body Path_Input is separate;

   --  The path input operations now live in the
   --  Files.Model.Path_Input child; these renamings keep them on the public API.
   procedure Focus_Path_Input (Model : in out Window_Model)
     renames Path_Input.Focus_Path_Input;

   procedure Set_Path_Input_Text (Model : in out Window_Model; Text : String)
     renames Path_Input.Set_Path_Input_Text;

   function Path_Input_Text (Model : Window_Model) return String
     renames Path_Input.Path_Input_Text;

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector)
     renames Path_Input.Commit_Path_Input;

   function Path_Input_Is_Valid (Model : Window_Model) return Boolean
     renames Path_Input.Path_Input_Is_Valid;

   function Path_Input_Error_Key (Model : Window_Model) return String
     renames Path_Input.Path_Input_Error_Key;

   package Command_Palette is
      procedure Focus_Command_Palette_Input
        (Model : in out Window_Model);

      procedure Open_Command_Palette
        (Model : in out Window_Model);

      procedure Close_Command_Palette
        (Model : in out Window_Model);

      procedure Toggle_Command_Palette
        (Model : in out Window_Model);

      function Command_Palette_Is_Open
        (Model : Window_Model)
         return Boolean;

      function Palette_Query (Model : Window_Model) return String;

      procedure Palette_Set_Query (Model : in out Window_Model; Text : String);

      procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer);

      procedure Palette_Select_First (Model : in out Window_Model);

      procedure Palette_Select_Last (Model : in out Window_Model);

      procedure Palette_Page (Model : in out Window_Model; Down : Boolean);

      function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

      function Palette_Selected_Id (Model : Window_Model) return Natural;

      function Palette_Result_Count (Model : Window_Model) return Natural;

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
         Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

      function Command_Palette_Mode_Of
        (Model : Window_Model)
         return Palette_Mode;

      procedure Set_Command_Palette_Mode
        (Model : in out Window_Model;
         Mode  : Palette_Mode);
   end Command_Palette;
   package body Command_Palette is separate;

   --  The command palette operations now live in the
   --  Files.Model.Command_Palette child; these renamings keep them on the public API.
   procedure Focus_Command_Palette_Input (Model : in out Window_Model)
     renames Command_Palette.Focus_Command_Palette_Input;

   procedure Open_Command_Palette (Model : in out Window_Model)
     renames Command_Palette.Open_Command_Palette;

   procedure Close_Command_Palette (Model : in out Window_Model)
     renames Command_Palette.Close_Command_Palette;

   procedure Toggle_Command_Palette (Model : in out Window_Model)
     renames Command_Palette.Toggle_Command_Palette;

   function Command_Palette_Is_Open (Model : Window_Model) return Boolean
     renames Command_Palette.Command_Palette_Is_Open;

   function Palette_Query (Model : Window_Model) return String
     renames Command_Palette.Palette_Query;

   procedure Palette_Set_Query (Model : in out Window_Model; Text : String)
     renames Command_Palette.Palette_Set_Query;

   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer)
     renames Command_Palette.Palette_Move_Selection;

   procedure Palette_Select_First (Model : in out Window_Model)
     renames Command_Palette.Palette_Select_First;

   procedure Palette_Select_Last (Model : in out Window_Model)
     renames Command_Palette.Palette_Select_Last;

   procedure Palette_Page (Model : in out Window_Model; Down : Boolean)
     renames Command_Palette.Palette_Page;

   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean
     renames Command_Palette.Palette_Click;

   function Palette_Selected_Id (Model : Window_Model) return Natural
     renames Command_Palette.Palette_Selected_Id;

   function Palette_Result_Count (Model : Window_Model) return Natural
     renames Command_Palette.Palette_Result_Count;

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
     renames Command_Palette.Palette_Build_Frame;

   function Command_Palette_Mode_Of (Model : Window_Model) return Palette_Mode
     renames Command_Palette.Command_Palette_Mode_Of;

   procedure Set_Command_Palette_Mode (Model : in out Window_Model; Mode : Palette_Mode)
     renames Command_Palette.Set_Command_Palette_Mode;

   package Rename is
      procedure Focus_Rename_Input
        (Model : in out Window_Model);

      function Rename_Is_Enabled
        (Model : Window_Model)
         return Boolean;

      function Rename_Behavior return Rename_Policy;

      procedure Toggle_Rename
        (Model : in out Window_Model);

      function Rename_Is_Active
        (Model : Window_Model)
         return Boolean;

      function Rename_Field_Count
        (Model : Window_Model)
         return Natural;

      function Rename_Text
        (Model : Window_Model)
         return String;

      procedure Set_Rename_Text
        (Model : in out Window_Model;
         Text  : String);

      function Rename_Insert_At_Carets
        (Model : in out Window_Model;
         Text  : String)
         return Boolean;

      function Rename_Delete_Backward
        (Model : in out Window_Model)
         return Boolean;

      function Rename_Delete_Forward
        (Model : in out Window_Model)
         return Boolean;

      function Rename_Delete_Word_Backward
        (Model : in out Window_Model)
         return Boolean;

      function Rename_Delete_Word_Forward
        (Model : in out Window_Model)
         return Boolean;

      function Rename_Move_All_Carets
        (Model     : in out Window_Model;
         Direction : Guikit.Input.Navigation_Direction)
         return Boolean;

      function Rename_Move_All_Carets_Word
        (Model     : in out Window_Model;
         Direction : Guikit.Input.Navigation_Direction)
         return Boolean;

      function Rename_Set_All_Carets_Home
        (Model : in out Window_Model)
         return Boolean;

      function Rename_Set_All_Carets_End
        (Model : in out Window_Model)
         return Boolean;

      procedure Set_Rename_Caret
        (Model         : in out Window_Model;
         Visible_Index : Natural;
         Position      : Natural);

      procedure Rename_State_For_Visible
        (Model         : Window_Model;
         Visible_Index : Positive;
         Active        : out Boolean;
         Value         : out UString;
         Cursor        : out Natural);

      function Rename_Targets
        (Model : Window_Model)
         return Rename_Target_Vectors.Vector;

      procedure Resume_Rename
        (Model : in out Window_Model;
         Text  : String);
   end Rename;
   package body Rename is separate;

   --  The rename operations now live in the
   --  Files.Model.Rename child; these renamings keep them on the public API.
   procedure Focus_Rename_Input (Model : in out Window_Model)
     renames Rename.Focus_Rename_Input;

   function Rename_Is_Enabled (Model : Window_Model) return Boolean
     renames Rename.Rename_Is_Enabled;

   function Rename_Behavior return Rename_Policy
     renames Rename.Rename_Behavior;

   procedure Toggle_Rename (Model : in out Window_Model)
     renames Rename.Toggle_Rename;

   function Rename_Is_Active (Model : Window_Model) return Boolean
     renames Rename.Rename_Is_Active;

   function Rename_Field_Count (Model : Window_Model) return Natural
     renames Rename.Rename_Field_Count;

   function Rename_Text (Model : Window_Model) return String
     renames Rename.Rename_Text;

   procedure Set_Rename_Text (Model : in out Window_Model; Text : String)
     renames Rename.Set_Rename_Text;

   function Rename_Insert_At_Carets (Model : in out Window_Model; Text : String) return Boolean
     renames Rename.Rename_Insert_At_Carets;

   function Rename_Delete_Backward (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Delete_Backward;

   function Rename_Delete_Forward (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Delete_Forward;

   function Rename_Delete_Word_Backward (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Delete_Word_Backward;

   function Rename_Delete_Word_Forward (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Delete_Word_Forward;

   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
     renames Rename.Rename_Move_All_Carets;

   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
     renames Rename.Rename_Move_All_Carets_Word;

   function Rename_Set_All_Carets_Home (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Set_All_Carets_Home;

   function Rename_Set_All_Carets_End (Model : in out Window_Model) return Boolean
     renames Rename.Rename_Set_All_Carets_End;

   procedure Set_Rename_Caret (Model : in out Window_Model; Visible_Index : Natural; Position : Natural)
     renames Rename.Set_Rename_Caret;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
     renames Rename.Rename_State_For_Visible;

   function Rename_Targets (Model : Window_Model) return Rename_Target_Vectors.Vector
     renames Rename.Rename_Targets;

   procedure Resume_Rename (Model : in out Window_Model; Text : String)
     renames Rename.Resume_Rename;

   package Ownership_Input is
      procedure Focus_Ownership_Input
        (Model         : in out Window_Model;
         Editing_Group : Boolean);

      function Ownership_Input_Text
        (Model : Window_Model)
         return String;

      procedure Set_Ownership_Input_Text
        (Model : in out Window_Model;
         Text  : String);

      function Ownership_Editing_Group
        (Model : Window_Model)
         return Boolean;
   end Ownership_Input;
   package body Ownership_Input is separate;

   --  The ownership input operations now live in the
   --  Files.Model.Ownership_Input child; these renamings keep them on the public API.
   procedure Focus_Ownership_Input (Model : in out Window_Model; Editing_Group : Boolean)
     renames Ownership_Input.Focus_Ownership_Input;

   function Ownership_Input_Text (Model : Window_Model) return String
     renames Ownership_Input.Ownership_Input_Text;

   procedure Set_Ownership_Input_Text (Model : in out Window_Model; Text : String)
     renames Ownership_Input.Set_Ownership_Input_Text;

   function Ownership_Editing_Group (Model : Window_Model) return Boolean
     renames Ownership_Input.Ownership_Editing_Group;

   package Root_Selector is
      procedure Open_Root_Selector
        (Model : in out Window_Model;
         Roots : Files.Types.String_Vectors.Vector);

      procedure Open_Root_Selector
        (Model : in out Window_Model;
         Roots : Files.File_System.Root_Entry_Vectors.Vector);

      procedure Close_Root_Selector
        (Model : in out Window_Model);

      function Root_Selector_Is_Open
        (Model : Window_Model)
         return Boolean;

      function Root_Count
        (Model : Window_Model)
         return Natural;

      function Root_Selected_Index
        (Model : Window_Model)
         return Natural;

      procedure Set_Root_Selected_Index
        (Model : in out Window_Model;
         Index : Natural);

      procedure Move_Root_Selection
        (Model     : in out Window_Model;
         Direction : Guikit.Input.Navigation_Direction);

      function Root_Path
        (Model : Window_Model;
         Index : Positive)
         return String;

      function Root_Label
        (Model : Window_Model;
         Index : Positive)
         return String;

      function Root_Kind
        (Model : Window_Model;
         Index : Positive)
         return Files.File_System.Root_Kind;

      function Root_Is_Removable
        (Model : Window_Model;
         Index : Positive)
         return Boolean;
   end Root_Selector;
   package body Root_Selector is separate;

   --  The root selector operations now live in the
   --  Files.Model.Root_Selector child; these renamings keep them on the public API.
   procedure Open_Root_Selector (Model : in out Window_Model; Roots : Files.Types.String_Vectors.Vector)
     renames Root_Selector.Open_Root_Selector;

   procedure Open_Root_Selector (Model : in out Window_Model; Roots : Files.File_System.Root_Entry_Vectors.Vector)
     renames Root_Selector.Open_Root_Selector;

   procedure Close_Root_Selector (Model : in out Window_Model)
     renames Root_Selector.Close_Root_Selector;

   function Root_Selector_Is_Open (Model : Window_Model) return Boolean
     renames Root_Selector.Root_Selector_Is_Open;

   function Root_Count (Model : Window_Model) return Natural
     renames Root_Selector.Root_Count;

   function Root_Selected_Index (Model : Window_Model) return Natural
     renames Root_Selector.Root_Selected_Index;

   procedure Set_Root_Selected_Index (Model : in out Window_Model; Index : Natural)
     renames Root_Selector.Set_Root_Selected_Index;

   procedure Move_Root_Selection (Model : in out Window_Model; Direction : Guikit.Input.Navigation_Direction)
     renames Root_Selector.Move_Root_Selection;

   function Root_Path (Model : Window_Model; Index : Positive) return String
     renames Root_Selector.Root_Path;

   function Root_Label (Model : Window_Model; Index : Positive) return String
     renames Root_Selector.Root_Label;

   function Root_Kind (Model : Window_Model; Index : Positive) return Files.File_System.Root_Kind
     renames Root_Selector.Root_Kind;

   function Root_Is_Removable (Model : Window_Model; Index : Positive) return Boolean
     renames Root_Selector.Root_Is_Removable;

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

   package Tree_Panel is
      procedure Toggle_Tree_Panel
        (Model : in out Window_Model);

      procedure Open_Tree_Panel
        (Model : in out Window_Model);

      procedure Close_Tree_Panel
        (Model : in out Window_Model);

      function Tree_Panel_Is_Open
        (Model : Window_Model)
         return Boolean;

      function Tree_Is_Seeded
        (Model : Window_Model)
         return Boolean;

      procedure Seed_Tree
        (Model : in out Window_Model;
         Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

      function Tree_Node_Count
        (Model : Window_Model)
         return Natural;

      function Tree_Node_Path
        (Model : Window_Model;
         Index : Positive)
         return String;

      function Tree_Node_Is_Loaded
        (Model : Window_Model;
         Index : Positive)
         return Boolean;

      function Tree_Node_Is_Expanded
        (Model : Window_Model;
         Index : Positive)
         return Boolean;

      procedure Tree_Set_Children
        (Model    : in out Window_Model;
         Index    : Positive;
         Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

      procedure Tree_Set_Expanded
        (Model    : in out Window_Model;
         Index    : Positive;
         Expanded : Boolean);

      procedure Tree_Toggle_Expanded
        (Model : in out Window_Model;
         Index : Positive);

      function Tree_Visible_Rows
        (Model : Window_Model)
         return Files.Folder_Tree.Visible_Row_Vectors.Vector;

      procedure Begin_Tree_Pick
        (Model          : in out Window_Model;
         Mode           : Tree_Pick_Mode;
         Sources        : Files.Types.String_Vectors.Vector;
         Initial_Target : String);

      procedure Set_Tree_Pick_Target
        (Model  : in out Window_Model;
         Target : String);

      procedure Clear_Tree_Pick
        (Model : in out Window_Model);

      function Tree_Pick_Mode_Of
        (Model : Window_Model)
         return Tree_Pick_Mode;

      function Tree_Pick_Is_Active
        (Model : Window_Model)
         return Boolean;

      function Tree_Pick_Sources
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Tree_Pick_Target
        (Model : Window_Model)
         return String;
   end Tree_Panel;
   package body Tree_Panel is separate;

   --  The tree panel operations now live in the
   --  Files.Model.Tree_Panel child; these renamings keep them on the public API.
   procedure Toggle_Tree_Panel (Model : in out Window_Model)
     renames Tree_Panel.Toggle_Tree_Panel;

   procedure Open_Tree_Panel (Model : in out Window_Model)
     renames Tree_Panel.Open_Tree_Panel;

   procedure Close_Tree_Panel (Model : in out Window_Model)
     renames Tree_Panel.Close_Tree_Panel;

   function Tree_Panel_Is_Open (Model : Window_Model) return Boolean
     renames Tree_Panel.Tree_Panel_Is_Open;

   function Tree_Is_Seeded (Model : Window_Model) return Boolean
     renames Tree_Panel.Tree_Is_Seeded;

   procedure Seed_Tree (Model : in out Window_Model; Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
     renames Tree_Panel.Seed_Tree;

   function Tree_Node_Count (Model : Window_Model) return Natural
     renames Tree_Panel.Tree_Node_Count;

   function Tree_Node_Path (Model : Window_Model; Index : Positive) return String
     renames Tree_Panel.Tree_Node_Path;

   function Tree_Node_Is_Loaded (Model : Window_Model; Index : Positive) return Boolean
     renames Tree_Panel.Tree_Node_Is_Loaded;

   function Tree_Node_Is_Expanded (Model : Window_Model; Index : Positive) return Boolean
     renames Tree_Panel.Tree_Node_Is_Expanded;

   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
     renames Tree_Panel.Tree_Set_Children;

   procedure Tree_Set_Expanded (Model : in out Window_Model; Index : Positive; Expanded : Boolean)
     renames Tree_Panel.Tree_Set_Expanded;

   procedure Tree_Toggle_Expanded (Model : in out Window_Model; Index : Positive)
     renames Tree_Panel.Tree_Toggle_Expanded;

   function Tree_Visible_Rows (Model : Window_Model) return Files.Folder_Tree.Visible_Row_Vectors.Vector
     renames Tree_Panel.Tree_Visible_Rows;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String)
     renames Tree_Panel.Begin_Tree_Pick;

   procedure Set_Tree_Pick_Target (Model : in out Window_Model; Target : String)
     renames Tree_Panel.Set_Tree_Pick_Target;

   procedure Clear_Tree_Pick (Model : in out Window_Model)
     renames Tree_Panel.Clear_Tree_Pick;

   function Tree_Pick_Mode_Of (Model : Window_Model) return Tree_Pick_Mode
     renames Tree_Panel.Tree_Pick_Mode_Of;

   function Tree_Pick_Is_Active (Model : Window_Model) return Boolean
     renames Tree_Panel.Tree_Pick_Is_Active;

   function Tree_Pick_Sources (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Tree_Panel.Tree_Pick_Sources;

   function Tree_Pick_Target (Model : Window_Model) return String
     renames Tree_Panel.Tree_Pick_Target;

   package Panes is
      procedure Toggle_Info_Pane
        (Model : in out Window_Model);

      function Info_Pane_Is_Open
        (Model : Window_Model)
         return Boolean;

      procedure Ensure_Selected_Item_Extra
        (Model : in out Window_Model);

      procedure Toggle_Settings_Pane
        (Model : in out Window_Model);

      function Settings_Pane_Is_Open
        (Model : Window_Model)
         return Boolean;

      procedure Begin_Settings_Edit
        (Model : in out Window_Model;
         Draft : Files.Settings.Settings_Draft);

      function Settings_Draft_Of
        (Model : Window_Model)
         return Files.Settings.Settings_Draft;

      procedure Set_Settings_Draft
        (Model : in out Window_Model;
         Draft : Files.Settings.Settings_Draft);

      procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer);

      procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean);

      procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String);

      procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer);

      function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean;

      function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change;

      function Settings_Focused_Value (Model : Window_Model) return String;

      procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural);

      function Settings_Section_Count (Model : Window_Model) return Natural;

      function Settings_Active_Section (Model : Window_Model) return Natural;

      procedure Settings_Begin_Capture (Model : in out Window_Model);

      function Settings_Is_Capturing (Model : Window_Model) return Boolean;

      function Settings_Capturing_Key (Model : Window_Model) return String;

      procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String);

      procedure Settings_Cancel_Capture (Model : in out Window_Model);

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
         Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

      procedure Scroll_Info_Pane
        (Model : in out Window_Model;
         Lines : Integer);

      function Info_Pane_Scroll_Lines
        (Model : Window_Model)
         return Natural;

      procedure Scroll_Main_View
        (Model : in out Window_Model;
         Lines : Integer);

      function Main_View_Scroll_Lines
        (Model : Window_Model)
         return Natural;

      procedure Set_Main_View_Scroll_Lines
        (Model : in out Window_Model;
         Lines : Natural);

      procedure Set_Info_Pane_Scroll_Lines
        (Model : in out Window_Model;
         Lines : Natural);
   end Panes;
   package body Panes is separate;

   --  The panes operations now live in the
   --  Files.Model.Panes child; these renamings keep them on the public API.
   procedure Toggle_Info_Pane (Model : in out Window_Model)
     renames Panes.Toggle_Info_Pane;

   function Info_Pane_Is_Open (Model : Window_Model) return Boolean
     renames Panes.Info_Pane_Is_Open;

   procedure Ensure_Selected_Item_Extra (Model : in out Window_Model)
     renames Panes.Ensure_Selected_Item_Extra;

   procedure Toggle_Settings_Pane (Model : in out Window_Model)
     renames Panes.Toggle_Settings_Pane;

   function Settings_Pane_Is_Open (Model : Window_Model) return Boolean
     renames Panes.Settings_Pane_Is_Open;

   procedure Begin_Settings_Edit (Model : in out Window_Model; Draft : Files.Settings.Settings_Draft)
     renames Panes.Begin_Settings_Edit;

   function Settings_Draft_Of (Model : Window_Model) return Files.Settings.Settings_Draft
     renames Panes.Settings_Draft_Of;

   procedure Set_Settings_Draft (Model : in out Window_Model; Draft : Files.Settings.Settings_Draft)
     renames Panes.Set_Settings_Draft;

   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer)
     renames Panes.Settings_Move_Focus;

   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean)
     renames Panes.Settings_Cycle_Choice;

   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String)
     renames Panes.Settings_Set_Focused_Value;

   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer)
     renames Panes.Settings_Scroll;

   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean
     renames Panes.Settings_Click;

   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change
     renames Panes.Settings_Take_Change;

   function Settings_Focused_Value (Model : Window_Model) return String
     renames Panes.Settings_Focused_Value;

   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural)
     renames Panes.Settings_Set_Active_Section;

   function Settings_Section_Count (Model : Window_Model) return Natural
     renames Panes.Settings_Section_Count;

   function Settings_Active_Section (Model : Window_Model) return Natural
     renames Panes.Settings_Active_Section;

   procedure Settings_Begin_Capture (Model : in out Window_Model)
     renames Panes.Settings_Begin_Capture;

   function Settings_Is_Capturing (Model : Window_Model) return Boolean
     renames Panes.Settings_Is_Capturing;

   function Settings_Capturing_Key (Model : Window_Model) return String
     renames Panes.Settings_Capturing_Key;

   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String)
     renames Panes.Settings_Set_Captured_Shortcut;

   procedure Settings_Cancel_Capture (Model : in out Window_Model)
     renames Panes.Settings_Cancel_Capture;

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
     renames Panes.Settings_Build_Frame;

   procedure Scroll_Info_Pane (Model : in out Window_Model; Lines : Integer)
     renames Panes.Scroll_Info_Pane;

   function Info_Pane_Scroll_Lines (Model : Window_Model) return Natural
     renames Panes.Info_Pane_Scroll_Lines;

   procedure Scroll_Main_View (Model : in out Window_Model; Lines : Integer)
     renames Panes.Scroll_Main_View;

   function Main_View_Scroll_Lines (Model : Window_Model) return Natural
     renames Panes.Main_View_Scroll_Lines;

   procedure Set_Main_View_Scroll_Lines (Model : in out Window_Model; Lines : Natural)
     renames Panes.Set_Main_View_Scroll_Lines;

   procedure Set_Info_Pane_Scroll_Lines (Model : in out Window_Model; Lines : Natural)
     renames Panes.Set_Info_Pane_Scroll_Lines;

   package Label_Picker is
      procedure Set_Open_With_Targets
        (Model   : in out Window_Model;
         Targets : Files.Types.String_Vectors.Vector);

      function Open_With_Targets
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      procedure Open_Label_Picker
        (Model : in out Window_Model);

      procedure Close_Label_Picker
        (Model : in out Window_Model);

      function Label_Picker_Is_Open
        (Model : Window_Model)
         return Boolean;

      procedure Move_Label_Picker_Highlight
        (Model : in out Window_Model;
         Delta_Value : Integer);

      function Label_Picker_Highlight
        (Model : Window_Model)
         return Positive;

      function Label_Picker_Highlight_Color
        (Model : Window_Model)
         return Files.Types.Color_Label;
   end Label_Picker;
   package body Label_Picker is separate;

   --  The label picker operations now live in the
   --  Files.Model.Label_Picker child; these renamings keep them on the public API.
   procedure Set_Open_With_Targets (Model : in out Window_Model; Targets : Files.Types.String_Vectors.Vector)
     renames Label_Picker.Set_Open_With_Targets;

   function Open_With_Targets (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Label_Picker.Open_With_Targets;

   procedure Open_Label_Picker (Model : in out Window_Model)
     renames Label_Picker.Open_Label_Picker;

   procedure Close_Label_Picker (Model : in out Window_Model)
     renames Label_Picker.Close_Label_Picker;

   function Label_Picker_Is_Open (Model : Window_Model) return Boolean
     renames Label_Picker.Label_Picker_Is_Open;

   procedure Move_Label_Picker_Highlight (Model : in out Window_Model; Delta_Value : Integer)
     renames Label_Picker.Move_Label_Picker_Highlight;

   function Label_Picker_Highlight (Model : Window_Model) return Positive
     renames Label_Picker.Label_Picker_Highlight;

   function Label_Picker_Highlight_Color (Model : Window_Model) return Files.Types.Color_Label
     renames Label_Picker.Label_Picker_Highlight_Color;

   package Quick_Look is
      procedure Open_Quick_Look
        (Model   : in out Window_Model;
         Content : Files.Quick_Look.Quick_Look_Content);

      procedure Close_Quick_Look
        (Model : in out Window_Model);

      procedure Toggle_Quick_Look
        (Model : in out Window_Model);

      function Quick_Look_Is_Open
        (Model : Window_Model)
         return Boolean;

      function Quick_Look_Path
        (Model : Window_Model)
         return String;

      function Quick_Look_Content_Of
        (Model : Window_Model)
         return Files.Quick_Look.Quick_Look_Content;
   end Quick_Look;
   package body Quick_Look is separate;

   --  The quick look operations now live in the
   --  Files.Model.Quick_Look child; these renamings keep them on the public API.
   procedure Open_Quick_Look (Model : in out Window_Model; Content : Files.Quick_Look.Quick_Look_Content)
     renames Quick_Look.Open_Quick_Look;

   procedure Close_Quick_Look (Model : in out Window_Model)
     renames Quick_Look.Close_Quick_Look;

   procedure Toggle_Quick_Look (Model : in out Window_Model)
     renames Quick_Look.Toggle_Quick_Look;

   function Quick_Look_Is_Open (Model : Window_Model) return Boolean
     renames Quick_Look.Quick_Look_Is_Open;

   function Quick_Look_Path (Model : Window_Model) return String
     renames Quick_Look.Quick_Look_Path;

   function Quick_Look_Content_Of (Model : Window_Model) return Files.Quick_Look.Quick_Look_Content
     renames Quick_Look.Quick_Look_Content_Of;

   package Temporary is
      procedure Begin_Create_File
        (Model : in out Window_Model;
         Name  : String);

      procedure Begin_Create_Folder
        (Model : in out Window_Model;
         Name  : String);

      function Temporary_Item_Is_Active
        (Model : Window_Model)
         return Boolean;

      function Temporary_Item_Is_Directory
        (Model : Window_Model)
         return Boolean;

      function Temporary_Item_Name
        (Model : Window_Model)
         return String;

      procedure Cancel_Create_File
        (Model : in out Window_Model);
   end Temporary;
   package body Temporary is separate;

   --  The temporary operations now live in the
   --  Files.Model.Temporary child; these renamings keep them on the public API.
   procedure Begin_Create_File (Model : in out Window_Model; Name : String)
     renames Temporary.Begin_Create_File;

   procedure Begin_Create_Folder (Model : in out Window_Model; Name : String)
     renames Temporary.Begin_Create_Folder;

   function Temporary_Item_Is_Active (Model : Window_Model) return Boolean
     renames Temporary.Temporary_Item_Is_Active;

   function Temporary_Item_Is_Directory (Model : Window_Model) return Boolean
     renames Temporary.Temporary_Item_Is_Directory;

   function Temporary_Item_Name (Model : Window_Model) return String
     renames Temporary.Temporary_Item_Name;

   procedure Cancel_Create_File (Model : in out Window_Model)
     renames Temporary.Cancel_Create_File;

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

   package Error is
      procedure Set_Error
        (Model     : in out Window_Model;
         Error_Key : String);

      function Last_Error_Key
        (Model : Window_Model)
         return String;
   end Error;
   package body Error is separate;

   --  The error operations now live in the
   --  Files.Model.Error child; these renamings keep them on the public API.
   procedure Set_Error (Model : in out Window_Model; Error_Key : String)
     renames Error.Set_Error;

   function Last_Error_Key (Model : Window_Model) return String
     renames Error.Last_Error_Key;

   package Clipboard is
      procedure Set_Clipboard
        (Model : in out Window_Model;
         Paths : Files.Types.String_Vectors.Vector;
         Mode  : Clipboard_Mode);

      procedure Clear_Clipboard
        (Model : in out Window_Model);

      function Clipboard_Paths
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Clipboard_Mode_Of
        (Model : Window_Model)
         return Clipboard_Mode;

      function Clipboard_Has_Items
        (Model : Window_Model)
         return Boolean;

      procedure Set_System_Clipboard_Request
        (Model : in out Window_Model;
         Text  : String);

      function System_Clipboard_Request_Pending
        (Model : Window_Model)
         return Boolean;

      function System_Clipboard_Request_Text
        (Model : Window_Model)
         return String;

      procedure Clear_System_Clipboard_Request
        (Model : in out Window_Model);
   end Clipboard;
   package body Clipboard is separate;

   --  The clipboard operations now live in the
   --  Files.Model.Clipboard child; these renamings keep them on the public API.
   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode)
     renames Clipboard.Set_Clipboard;

   procedure Clear_Clipboard (Model : in out Window_Model)
     renames Clipboard.Clear_Clipboard;

   function Clipboard_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Clipboard.Clipboard_Paths;

   function Clipboard_Mode_Of (Model : Window_Model) return Clipboard_Mode
     renames Clipboard.Clipboard_Mode_Of;

   function Clipboard_Has_Items (Model : Window_Model) return Boolean
     renames Clipboard.Clipboard_Has_Items;

   procedure Set_System_Clipboard_Request (Model : in out Window_Model; Text : String)
     renames Clipboard.Set_System_Clipboard_Request;

   function System_Clipboard_Request_Pending (Model : Window_Model) return Boolean
     renames Clipboard.System_Clipboard_Request_Pending;

   function System_Clipboard_Request_Text (Model : Window_Model) return String
     renames Clipboard.System_Clipboard_Request_Text;

   procedure Clear_System_Clipboard_Request (Model : in out Window_Model)
     renames Clipboard.Clear_System_Clipboard_Request;

   package Undo_Redo is
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
           Files.Types.String_Vectors.Empty_Vector);

      procedure Clear_Undo
        (Model : in out Window_Model);

      function Undo_Available
        (Model : Window_Model)
         return Boolean;

      function Redo_Available
        (Model : Window_Model)
         return Boolean;

      procedure Take_Undo
        (Model  : in out Window_Model;
         Action : out Undo_Entry;
         Found  : out Boolean);

      procedure Take_Redo
        (Model  : in out Window_Model;
         Action : out Undo_Entry;
         Found  : out Boolean);

      procedure Push_Redo
        (Model  : in out Window_Model;
         Action : Undo_Entry);

      procedure Push_Undo
        (Model  : in out Window_Model;
         Action : Undo_Entry);

      function Undo_Kind_Of
        (Model : Window_Model)
         return Undo_Action_Kind;

      function Undo_From_Paths
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Undo_To_Paths
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;
   end Undo_Redo;
   package body Undo_Redo is separate;

   --  The undo redo operations now live in the
   --  Files.Model.Undo_Redo child; these renamings keep them on the public API.
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
     renames Undo_Redo.Record_Undo;

   procedure Clear_Undo (Model : in out Window_Model)
     renames Undo_Redo.Clear_Undo;

   function Undo_Available (Model : Window_Model) return Boolean
     renames Undo_Redo.Undo_Available;

   function Redo_Available (Model : Window_Model) return Boolean
     renames Undo_Redo.Redo_Available;

   procedure Take_Undo (Model : in out Window_Model; Action : out Undo_Entry; Found : out Boolean)
     renames Undo_Redo.Take_Undo;

   procedure Take_Redo (Model : in out Window_Model; Action : out Undo_Entry; Found : out Boolean)
     renames Undo_Redo.Take_Redo;

   procedure Push_Redo (Model : in out Window_Model; Action : Undo_Entry)
     renames Undo_Redo.Push_Redo;

   procedure Push_Undo (Model : in out Window_Model; Action : Undo_Entry)
     renames Undo_Redo.Push_Undo;

   function Undo_Kind_Of (Model : Window_Model) return Undo_Action_Kind
     renames Undo_Redo.Undo_Kind_Of;

   function Undo_From_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Undo_Redo.Undo_From_Paths;

   function Undo_To_Paths (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Undo_Redo.Undo_To_Paths;

   package Paste_Conflict is
      procedure Begin_Paste_Conflict
        (Model           : in out Window_Model;
         Items           : Files.Paste.Work_Item_Vectors.Vector;
         Existing        : Files.Types.String_Vectors.Vector;
         Mode            : Files.File_System.Drop_Import_Mode;
         Index           : Positive;
         Clear_Clipboard : Boolean := True);

      function Paste_Conflict_Is_Active
        (Model : Window_Model)
         return Boolean;

      function Paste_Conflict_Items
        (Model : Window_Model)
         return Files.Paste.Work_Item_Vectors.Vector;

      function Paste_Conflict_Existing
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Paste_Conflict_Overrides
        (Model : Window_Model)
         return Files.Paste.Item_Decision_Vectors.Vector;

      function Paste_Conflict_Policy
        (Model : Window_Model)
         return Files.Paste.Conflict_Policy;

      function Paste_Conflict_Mode
        (Model : Window_Model)
         return Files.File_System.Drop_Import_Mode;

      function Paste_Conflict_Clears_Clipboard
        (Model : Window_Model)
         return Boolean;

      function Paste_Conflict_Index
        (Model : Window_Model)
         return Natural;

      function Paste_Conflict_Name
        (Model : Window_Model)
         return String;

      function Paste_Conflict_Apply_All
        (Model : Window_Model)
         return Boolean;

      procedure Toggle_Paste_Conflict_Apply_All
        (Model : in out Window_Model);

      procedure Set_Paste_Conflict_Policy
        (Model  : in out Window_Model;
         Policy : Files.Paste.Conflict_Policy);

      procedure Set_Paste_Conflict_Override
        (Model    : in out Window_Model;
         Index    : Positive;
         Decision : Files.Paste.Item_Decision);

      procedure Set_Paste_Conflict_Index
        (Model : in out Window_Model;
         Index : Positive);

      procedure Clear_Paste_Conflict
        (Model : in out Window_Model);
   end Paste_Conflict;
   package body Paste_Conflict is separate;

   --  The paste conflict operations now live in the
   --  Files.Model.Paste_Conflict child; these renamings keep them on the public API.
   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True)
     renames Paste_Conflict.Begin_Paste_Conflict;

   function Paste_Conflict_Is_Active (Model : Window_Model) return Boolean
     renames Paste_Conflict.Paste_Conflict_Is_Active;

   function Paste_Conflict_Items (Model : Window_Model) return Files.Paste.Work_Item_Vectors.Vector
     renames Paste_Conflict.Paste_Conflict_Items;

   function Paste_Conflict_Existing (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Paste_Conflict.Paste_Conflict_Existing;

   function Paste_Conflict_Overrides (Model : Window_Model) return Files.Paste.Item_Decision_Vectors.Vector
     renames Paste_Conflict.Paste_Conflict_Overrides;

   function Paste_Conflict_Policy (Model : Window_Model) return Files.Paste.Conflict_Policy
     renames Paste_Conflict.Paste_Conflict_Policy;

   function Paste_Conflict_Mode (Model : Window_Model) return Files.File_System.Drop_Import_Mode
     renames Paste_Conflict.Paste_Conflict_Mode;

   function Paste_Conflict_Clears_Clipboard (Model : Window_Model) return Boolean
     renames Paste_Conflict.Paste_Conflict_Clears_Clipboard;

   function Paste_Conflict_Index (Model : Window_Model) return Natural
     renames Paste_Conflict.Paste_Conflict_Index;

   function Paste_Conflict_Name (Model : Window_Model) return String
     renames Paste_Conflict.Paste_Conflict_Name;

   function Paste_Conflict_Apply_All (Model : Window_Model) return Boolean
     renames Paste_Conflict.Paste_Conflict_Apply_All;

   procedure Toggle_Paste_Conflict_Apply_All (Model : in out Window_Model)
     renames Paste_Conflict.Toggle_Paste_Conflict_Apply_All;

   procedure Set_Paste_Conflict_Policy (Model : in out Window_Model; Policy : Files.Paste.Conflict_Policy)
     renames Paste_Conflict.Set_Paste_Conflict_Policy;

   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision)
     renames Paste_Conflict.Set_Paste_Conflict_Override;

   procedure Set_Paste_Conflict_Index (Model : in out Window_Model; Index : Positive)
     renames Paste_Conflict.Set_Paste_Conflict_Index;

   procedure Clear_Paste_Conflict (Model : in out Window_Model)
     renames Paste_Conflict.Clear_Paste_Conflict;

   package Paste_Exec is
      procedure Begin_Paste_Execution
        (Model           : in out Window_Model;
         Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
         Mode            : Files.File_System.Drop_Import_Mode;
         Clear_Clipboard : Boolean := True);

      function Paste_Execution_Is_Active
        (Model : Window_Model)
         return Boolean;

      function Paste_Execution_Done
        (Model : Window_Model)
         return Natural;

      function Paste_Execution_Total
        (Model : Window_Model)
         return Natural;

      function Paste_Execution_Current_Name
        (Model : Window_Model)
         return String;

      function Paste_Execution_Mode
        (Model : Window_Model)
         return Files.File_System.Drop_Import_Mode;

      function Paste_Execution_Clears_Clipboard
        (Model : Window_Model)
         return Boolean;

      function Paste_Execution_Cancelled
        (Model : Window_Model)
         return Boolean;

      function Paste_Execution_Cursor
        (Model : Window_Model)
         return Natural;

      function Paste_Execution_Action_Count
        (Model : Window_Model)
         return Natural;

      function Paste_Execution_Action
        (Model : Window_Model;
         Index : Positive)
         return Files.Paste.Resolved_Action;

      function Paste_Execution_Undo_From
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Paste_Execution_Undo_To
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      function Paste_Execution_Replaced_Trash
        (Model : Window_Model)
         return Files.Types.String_Vectors.Vector;

      procedure Record_Paste_Execution_Replaced_Trash
        (Model      : in out Window_Model;
         Trash_Path : Files.Types.UString);

      function Paste_Execution_First_Dest
        (Model : Window_Model)
         return String;

      procedure Skip_Paste_Execution_Action
        (Model : in out Window_Model);

      procedure Record_Paste_Execution_Write
        (Model       : in out Window_Model;
         Dest_Path   : Files.Types.UString;
         Source_Path : Files.Types.UString;
         Name        : String);

      procedure Cancel_Paste_Execution
        (Model : in out Window_Model);

      procedure Clear_Paste_Execution
        (Model : in out Window_Model);
   end Paste_Exec;
   package body Paste_Exec is separate;

   --  The paste exec operations now live in the
   --  Files.Model.Paste_Exec child; these renamings keep them on the public API.
   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
     renames Paste_Exec.Begin_Paste_Execution;

   function Paste_Execution_Is_Active (Model : Window_Model) return Boolean
     renames Paste_Exec.Paste_Execution_Is_Active;

   function Paste_Execution_Done (Model : Window_Model) return Natural
     renames Paste_Exec.Paste_Execution_Done;

   function Paste_Execution_Total (Model : Window_Model) return Natural
     renames Paste_Exec.Paste_Execution_Total;

   function Paste_Execution_Current_Name (Model : Window_Model) return String
     renames Paste_Exec.Paste_Execution_Current_Name;

   function Paste_Execution_Mode (Model : Window_Model) return Files.File_System.Drop_Import_Mode
     renames Paste_Exec.Paste_Execution_Mode;

   function Paste_Execution_Clears_Clipboard (Model : Window_Model) return Boolean
     renames Paste_Exec.Paste_Execution_Clears_Clipboard;

   function Paste_Execution_Cancelled (Model : Window_Model) return Boolean
     renames Paste_Exec.Paste_Execution_Cancelled;

   function Paste_Execution_Cursor (Model : Window_Model) return Natural
     renames Paste_Exec.Paste_Execution_Cursor;

   function Paste_Execution_Action_Count (Model : Window_Model) return Natural
     renames Paste_Exec.Paste_Execution_Action_Count;

   function Paste_Execution_Action (Model : Window_Model; Index : Positive) return Files.Paste.Resolved_Action
     renames Paste_Exec.Paste_Execution_Action;

   function Paste_Execution_Undo_From (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Paste_Exec.Paste_Execution_Undo_From;

   function Paste_Execution_Undo_To (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Paste_Exec.Paste_Execution_Undo_To;

   function Paste_Execution_Replaced_Trash (Model : Window_Model) return Files.Types.String_Vectors.Vector
     renames Paste_Exec.Paste_Execution_Replaced_Trash;

   procedure Record_Paste_Execution_Replaced_Trash (Model : in out Window_Model; Trash_Path : Files.Types.UString)
     renames Paste_Exec.Record_Paste_Execution_Replaced_Trash;

   function Paste_Execution_First_Dest (Model : Window_Model) return String
     renames Paste_Exec.Paste_Execution_First_Dest;

   procedure Skip_Paste_Execution_Action (Model : in out Window_Model)
     renames Paste_Exec.Skip_Paste_Execution_Action;

   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String)
     renames Paste_Exec.Record_Paste_Execution_Write;

   procedure Cancel_Paste_Execution (Model : in out Window_Model)
     renames Paste_Exec.Cancel_Paste_Execution;

   procedure Clear_Paste_Execution (Model : in out Window_Model)
     renames Paste_Exec.Clear_Paste_Execution;

   package Folder_Sizes is
      procedure Set_Folder_Size
        (Model : in out Window_Model;
         Path  : String;
         Value : Files.File_System.Directory_Size_Result);

      procedure Clear_Folder_Size
        (Model : in out Window_Model);

      procedure Prune_Folder_Sizes_To_Selection
        (Model : in out Window_Model);

      function Folder_Size_Cached_For
        (Model : Window_Model;
         Path  : String)
         return Boolean;

      function Folder_Size_Value
        (Model : Window_Model;
         Path  : String)
         return Files.File_System.Directory_Size_Result;
   end Folder_Sizes;
   package body Folder_Sizes is separate;

   --  The folder sizes operations now live in the
   --  Files.Model.Folder_Sizes child; these renamings keep them on the public API.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result)
     renames Folder_Sizes.Set_Folder_Size;

   procedure Clear_Folder_Size (Model : in out Window_Model)
     renames Folder_Sizes.Clear_Folder_Size;

   procedure Prune_Folder_Sizes_To_Selection (Model : in out Window_Model)
     renames Folder_Sizes.Prune_Folder_Sizes_To_Selection;

   function Folder_Size_Cached_For (Model : Window_Model; Path : String) return Boolean
     renames Folder_Sizes.Folder_Size_Cached_For;

   function Folder_Size_Value (Model : Window_Model; Path : String) return Files.File_System.Directory_Size_Result
     renames Folder_Sizes.Folder_Size_Value;

   package Context_Menu is
      procedure Open_Context_Menu
        (Model      : in out Window_Model;
         X          : Natural;
         Y          : Natural;
         Target     : Context_Menu_Target;
         Item_Index : Natural := 0);

      procedure Close_Context_Menu
        (Model : in out Window_Model);

      function Context_Menu_Is_Open
        (Model : Window_Model)
         return Boolean;

      function Context_Menu_X
        (Model : Window_Model)
         return Natural;

      function Context_Menu_Y
        (Model : Window_Model)
         return Natural;

      function Context_Menu_Target_Of
        (Model : Window_Model)
         return Context_Menu_Target;

      function Context_Menu_Item_Index
        (Model : Window_Model)
         return Natural;

      procedure Set_Context_Menu_Highlight
        (Model : in out Window_Model;
         Row   : Natural);

      function Context_Menu_Highlight
        (Model : Window_Model)
         return Natural;
   end Context_Menu;
   package body Context_Menu is separate;

   --  The context menu operations now live in the
   --  Files.Model.Context_Menu child; these renamings keep them on the public API.
   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0)
     renames Context_Menu.Open_Context_Menu;

   procedure Close_Context_Menu (Model : in out Window_Model)
     renames Context_Menu.Close_Context_Menu;

   function Context_Menu_Is_Open (Model : Window_Model) return Boolean
     renames Context_Menu.Context_Menu_Is_Open;

   function Context_Menu_X (Model : Window_Model) return Natural
     renames Context_Menu.Context_Menu_X;

   function Context_Menu_Y (Model : Window_Model) return Natural
     renames Context_Menu.Context_Menu_Y;

   function Context_Menu_Target_Of (Model : Window_Model) return Context_Menu_Target
     renames Context_Menu.Context_Menu_Target_Of;

   function Context_Menu_Item_Index (Model : Window_Model) return Natural
     renames Context_Menu.Context_Menu_Item_Index;

   procedure Set_Context_Menu_Highlight (Model : in out Window_Model; Row : Natural)
     renames Context_Menu.Set_Context_Menu_Highlight;

   function Context_Menu_Highlight (Model : Window_Model) return Natural
     renames Context_Menu.Context_Menu_Highlight;

end Files.Model;
