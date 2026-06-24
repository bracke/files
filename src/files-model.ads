with Ada.Containers.Vectors;

with Files.File_System;
with Files.Settings;
with Files.Types;

--  Directory state, selection, filtering, history, input state, and pane state.
package Files.Model is
   subtype UString is Files.Types.UString;

   type Sort_Field is
     (Sort_Name,
      Sort_Size,
      Sort_Type,
      Sort_Created,
      Sort_Changed);

   type Window_Model is private;

   --  Initialize a window model for a loaded directory.
   --
   --  @param Model Model to initialize.
   --  @param Directory_Path Current directory path.
   --  @param Items Loaded directory items.
   --  @param Home_Path Current user's home directory path.
   --  @param Default_View_Mode Initial view mode.
   procedure Initialize
     (Model             : out Window_Model;
      Directory_Path    : String;
      Items             : Files.File_System.Item_Vectors.Vector;
      Home_Path         : String;
      Default_View_Mode : Files.Types.View_Mode := Files.Types.Small_Icons);

   --  Return the model current path.
   --
   --  @param Model Model to inspect.
   --  @return Current directory path.
   function Current_Path
     (Model : Window_Model)
      return String;

   --  Return the last stored directory polling signature.
   --
   --  @param Model Model to inspect.
   --  @return Stored directory signature for the current path.
   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature;

   --  Replace the stored directory polling signature.
   --
   --  @param Model Model to update.
   --  @param Signature Signature captured after loading or polling a directory.
   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature);

   --  Return the model home path.
   --
   --  @param Model Model to inspect.
   --  @return Home directory path.
   function Home_Path
     (Model : Window_Model)
      return String;

   --  Return the active view mode.
   --
   --  @param Model Model to inspect.
   --  @return Active view mode.
   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode;

   --  Set the active view mode.
   --
   --  @param Model Model to update.
   --  @param Mode New view mode.
   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode);

   --  Return the active item sort field.
   --
   --  @param Model Model to inspect.
   --  @return Active sort field.
   function Sort_Field_Of
     (Model : Window_Model)
      return Sort_Field;

   --  Return whether item sorting is ascending.
   --
   --  @param Model Model to inspect.
   --  @return True when sorting ascends by the active field.
   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean;

   --  Select or toggle the active item sort field.
   --
   --  Selecting the current field toggles sort direction. Selecting a different
   --  field makes that field ascending.
   --
   --  @param Model Model to update.
   --  @param Field Sort field to select.
   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Sort_Field);

   --  Toggle the bottom-bar sort menu visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Sort_Menu
     (Model : in out Window_Model);

   --  Close the bottom-bar sort menu.
   --
   --  @param Model Model to update.
   procedure Close_Sort_Menu
     (Model : in out Window_Model);

   --  Return whether the bottom-bar sort menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the sort menu is open.
   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the number of loaded directory items.
   --
   --  @param Model Model to inspect.
   --  @return Loaded item count.
   function Item_Count
     (Model : Window_Model)
      return Natural;

   --  Return the number of visible items after filtering.
   --
   --  @param Model Model to inspect.
   --  @return Visible item count.
   function Visible_Count
     (Model : Window_Model)
      return Natural;

   --  Return a visible item by one-based visible index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return Directory item at Visible_Index.
   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item;

   --  Set filter text and reconcile selection.
   --
   --  @param Model Model to update.
   --  @param Text New filter text.
   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String);

   --  Return the current filter text.
   --
   --  @param Model Model to inspect.
   --  @return Filter text.
   function Filter_Text
     (Model : Window_Model)
      return String;

   --  Clear the current filter text.
   --
   --  @param Model Model to update.
   procedure Clear_Filter
     (Model : in out Window_Model);

   --  Select a visible item by one-based visible index.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Toggle a visible item in the deterministic multi-selection set.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Select a deterministic inclusive visible range.
   --
   --  @param Model Model to update.
   --  @param Anchor_Index One-based range anchor in the visible projection.
   --  @param Target_Index One-based range target in the visible projection.
   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive);

   --  Select all currently visible loaded directory items.
   --
   --  Temporary create-file items are excluded because they do not exist on
   --  disk until committed.
   --
   --  @param Model Model to update.
   procedure Select_All_Visible
     (Model : in out Window_Model);

   --  Clear the deterministic multi-selection set and primary selection.
   --
   --  @param Model Model to update.
   procedure Clear_Selection
     (Model : in out Window_Model);

   --  Move selection in the visible projection with wraparound.
   --
   --  @param Model Model to update.
   --  @param Direction Direction requested by user input.
   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction);

   --  Set the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to update.
   --  @param Columns Number of visible item columns; values below one are ignored.
   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive);

   --  Return the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to inspect.
   --  @return Number of visible item columns used as the vertical movement stride.
   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive;

   --  Return whether a visible item is selected.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return True when the visible item is selected.
   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean;

   --  Return the selected visible index.
   --
   --  @param Model Model to inspect.
   --  @return One-based visible selected index, or zero when nothing is selected.
   function Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Return the number of selected items.
   --
   --  @param Model Model to inspect.
   --  @return Selected item count.
   function Selected_Count
     (Model : Window_Model)
      return Natural;

   --  Return the selected item name.
   --
   --  @param Model Model to inspect.
   --  @return Selected item name or an empty string.
   function Selected_Name
     (Model : Window_Model)
      return String;

   --  Return the selected item.
   --
   --  @param Model Model to inspect.
   --  @return Selected item, or a default empty item when no selection exists.
   function Selected_Item
     (Model : Window_Model)
      return Files.File_System.Directory_Item;

   --  Return all selected items in deterministic loaded-item order.
   --
   --  @param Model Model to inspect.
   --  @return Selected directory items, excluding transient create-file items.
   function Selected_Items
     (Model : Window_Model)
      return Files.File_System.Item_Vectors.Vector;

   --  Return whether the current selection is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the pending create-file item is selected.
   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean;

   --  Return whether any selected item is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the selection includes the pending create-file item.
   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean;

   --  Navigate to a directory and push the previous path onto back history.
   --
   --  @param Model Model to update.
   --  @param Directory_Path Destination directory path.
   --  @param Items Loaded directory items for the destination.
   procedure Navigate_To
     (Model          : in out Window_Model;
      Directory_Path : String;
      Items          : Files.File_System.Item_Vectors.Vector);

   --  Return whether back navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the back-history stack is not empty.
   function Can_Go_Back
     (Model : Window_Model)
      return Boolean;

   --  Return whether forward navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the forward-history stack is not empty.
   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean;

   --  Navigate backward if history is available.
   --
   --  @param Model Model to update.
   procedure Go_Back
     (Model : in out Window_Model);

   --  Navigate forward if history is available.
   --
   --  @param Model Model to update.
   procedure Go_Forward
     (Model : in out Window_Model);

   --  Navigate to the home directory and update history.
   --
   --  @param Model Model to update.
   procedure Go_Home
     (Model : in out Window_Model);

   --  Focus the path input field.
   --
   --  @param Model Model to update.
   procedure Focus_Path_Input
     (Model : in out Window_Model);

   --  Focus the filter input field.
   --
   --  @param Model Model to update.
   procedure Focus_Filter_Input
     (Model : in out Window_Model);

   --  Focus the command-palette input without changing its existing query.
   --
   --  @param Model Model to update.
   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model);

   --  Focus the active rename input without changing its existing text.
   --
   --  @param Model Model to update.
   procedure Focus_Rename_Input
     (Model : in out Window_Model);

   --  Open the root selector with available root paths.
   --
   --  @param Model Model to update.
   --  @param Roots Root paths to expose.
   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector);

   --  Open the root selector with root metadata entries.
   --
   --  @param Model Model to update.
   --  @param Roots Root entries to expose.
   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector);

   --  Close the root selector.
   --
   --  @param Model Model to update.
   procedure Close_Root_Selector
     (Model : in out Window_Model);

   --  Return whether the root selector is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the root selector is open.
   function Root_Selector_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the number of root paths in the selector.
   --
   --  @param Model Model to inspect.
   --  @return Number of root paths.
   function Root_Count
     (Model : Window_Model)
      return Natural;

   --  Return the selected root-selector row.
   --
   --  @param Model Model to inspect.
   --  @return One-based selected root index, or zero when none is selected.
   function Root_Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Set the selected root-selector row.
   --
   --  @param Model Model to update.
   --  @param Index One-based selected root index, or zero for no row.
   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural);

   --  Move the selected root-selector row with wraparound.
   --
   --  @param Model Model to update.
   --  @param Direction Direction requested by user input.
   procedure Move_Root_Selection
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction);

   --  Return a root path from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root path or an empty string when Index is invalid.
   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return a root label from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root label or an empty string when Index is invalid.
   function Root_Label
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return a root kind from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root kind or Root_Filesystem when Index is invalid.
   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind;

   --  Return whether a root entry reports removable media.
   --
   --  @param Model Window model to inspect.
   --  @param Index One-based root selector index.
   --  @return True when Index names a removable root.
   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Return the current focus target.
   --
   --  @param Model Model to inspect.
   --  @return Focus target.
   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target;

   --  Return the cursor position of the currently focused text input.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based text cursor position, or zero when no text input is focused.
   function Text_Cursor_Position
     (Model : Window_Model)
      return Natural;

   --  Set the cursor position of the currently focused text input.
   --
   --  @param Model Model to update.
   --  @param Position Zero-based cursor position before clamping to text length.
   procedure Set_Text_Cursor_Position
     (Model    : in out Window_Model;
      Position : Natural);

   --  Move the cursor in the currently focused text input.
   --
   --  @param Model Model to update.
   --  @param Direction Left moves before the previous character; right moves after the next character.
   procedure Move_Text_Cursor
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction);

   --  Set path input text.
   --
   --  @param Model Model to update.
   --  @param Text New path input text.
   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return path input text.
   --
   --  @param Model Model to inspect.
   --  @return Current path input text.
   function Path_Input_Text
     (Model : Window_Model)
      return String;

   --  Commit path input using an externally validated path result.
   --
   --  @param Model Model to update.
   --  @param Result Validation result.
   --  @param Items Loaded destination items when Result is valid.
   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector);

   --  Return whether the path input is valid.
   --
   --  @param Model Model to inspect.
   --  @return True when no validation error is active.
   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean;

   --  Return path input validation error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Path_Input_Error_Key
     (Model : Window_Model)
      return String;

   --  Cancel focused text input and transient rename/create state as applicable.
   --
   --  @param Model Model to update.
   procedure Cancel_Focus_Or_Edit
     (Model : in out Window_Model);

   --  Toggle info-pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Info_Pane
     (Model : in out Window_Model);

   --  Return whether the info pane is open.
   --
   --  @param Model Model to inspect.
   --  @return True when info pane is open.
   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Toggle settings pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Settings_Pane
     (Model : in out Window_Model);

   --  Return whether the settings pane is visible.
   --
   --  @param Model Model to inspect.
   --  @return True when the settings pane is open.
   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Begin editing settings values in the settings pane.
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to edit.
   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Return the current settings draft.
   --
   --  @param Model Model to inspect.
   --  @return Editable settings draft.
   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft;

   --  Replace the active settings draft.
   --
   --  @param Model Model to update.
   --  @param Draft Draft values to store.
   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft);

   --  Return the active settings field index.
   --
   --  @param Model Model to inspect.
   --  @return One-based settings field index.
   function Settings_Field_Index
     (Model : Window_Model)
      return Natural;

   --  Select a settings field for editing.
   --
   --  @param Model Model to update.
   --  @param Index One-based settings field index.
   procedure Set_Settings_Field_Index
     (Model : in out Window_Model;
      Index : Natural);

   --  Move the selected settings field.
   --
   --  @param Model Model to update.
   --  @param Direction Navigation direction.
   procedure Move_Settings_Field
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction);

   --  Move the selected entry within the current settings mapping group.
   --
   --  @param Model Model to update.
   --  @param Direction Navigation direction.
   procedure Move_Settings_Entry
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction);

   --  Add a blank entry to the current settings mapping group.
   --
   --  @param Model Model to update.
   procedure Add_Settings_Entry
     (Model : in out Window_Model);

   --  Remove the selected entry from the current settings mapping group.
   --
   --  @param Model Model to update.
   procedure Remove_Settings_Entry
     (Model : in out Window_Model);

   --  Return the text in the selected settings field.
   --
   --  @param Model Model to inspect.
   --  @return Selected settings field text.
   function Settings_Field_Text
     (Model : Window_Model)
      return String;

   --  Set the selected settings field text.
   --
   --  @param Model Model to update.
   --  @param Text New field text.
   procedure Set_Settings_Field_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Scroll the info pane by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current info-pane scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative info-pane scroll offset.
   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural;

   --  Scroll the main item view by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current main item-view scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative main-view scroll offset.
   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural;

   --  Open the command palette.
   --
   --  @param Model Model to update.
   procedure Open_Command_Palette
     (Model : in out Window_Model);

   --  Close the command palette.
   --
   --  @param Model Model to update.
   procedure Close_Command_Palette
     (Model : in out Window_Model);

   --  Toggle the command palette.
   --
   --  @param Model Model to update.
   procedure Toggle_Command_Palette
     (Model : in out Window_Model);

   --  Return whether the command palette is open.
   --
   --  @param Model Model to inspect.
   --  @return True when command palette is open.
   function Command_Palette_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Set command-palette search text.
   --
   --  @param Model Model to update.
   --  @param Text New command-palette query text.
   procedure Set_Command_Palette_Query
     (Model : in out Window_Model;
      Text  : String);

   --  Return command-palette search text.
   --
   --  @param Model Model to inspect.
   --  @return Current command-palette query text.
   function Command_Palette_Query
     (Model : Window_Model)
      return String;

   --  Set command-palette selected result index.
   --
   --  @param Model Model to update.
   --  @param Index One-based selected result index, or zero for none.
   procedure Set_Command_Palette_Selected_Index
     (Model : in out Window_Model;
      Index : Natural);

   --  Return command-palette selected result index.
   --
   --  @param Model Model to inspect.
   --  @return One-based selected result index, or zero for none.
   function Command_Palette_Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Set command-palette result scroll offset.
   --
   --  @param Model Model to update.
   --  @param Offset Zero-based first visible result offset.
   procedure Set_Command_Palette_Result_Offset
     (Model  : in out Window_Model;
      Offset : Natural);

   --  Return command-palette result scroll offset.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based first visible result offset.
   function Command_Palette_Result_Offset
     (Model : Window_Model)
      return Natural;

   --  Return whether rename can start for a real loaded item.
   --
   --  @param Model Model to inspect.
   --  @return True when exactly one non-temporary item is selected.
   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean;

   type Rename_Policy is record
      Single_Item_Only       : Boolean := True;
      Synchronized_Multi     : Boolean := False;
      Atomic_Multi_Rename    : Boolean := False;
      Requires_One_Selection : Boolean := True;
   end record;

   --  Return the rename policy selected by this implementation.
   --
   --  @return Rename behavior policy.
   function Rename_Behavior return Rename_Policy;

   --  Toggle single-item rename mode.
   --
   --  @param Model Model to update.
   procedure Toggle_Rename
     (Model : in out Window_Model);

   --  Return whether rename mode is active.
   --
   --  @param Model Model to inspect.
   --  @return True when rename mode is active.
   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return active rename text.
   --
   --  @param Model Model to inspect.
   --  @return Rename text, or an empty string.
   function Rename_Text
     (Model : Window_Model)
      return String;

   --  Set active rename text.
   --
   --  @param Model Model to update.
   --  @param Text New rename text.
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Resume rename mode for the currently selected item.
   --
   --  @param Model Model to update.
   --  @param Text Rename text to restore.
   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String);

   --  Begin temporary create-file state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary file name.
   procedure Begin_Create_File
     (Model : in out Window_Model;
      Name  : String);

   --  Return whether a temporary create-file item is active.
   --
   --  @param Model Model to inspect.
   --  @return True when temporary item exists.
   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return temporary item name.
   --
   --  @param Model Model to inspect.
   --  @return Temporary item name or an empty string.
   function Temporary_Item_Name
     (Model : Window_Model)
      return String;

   --  Cancel temporary create-file state.
   --
   --  @param Model Model to update.
   procedure Cancel_Create_File
     (Model : in out Window_Model);

   --  Clear rename, temporary item, and edit focus state after a successful commit.
   --
   --  @param Model Model to update.
   procedure Clear_Edit_State
     (Model : in out Window_Model);

   --  Replace loaded items without changing path history.
   --
   --  @param Model Model to update.
   --  @param Items New loaded item list.
   procedure Replace_Items
     (Model : in out Window_Model;
      Items : Files.File_System.Item_Vectors.Vector);

   --  Select an item by name in the full loaded model.
   --
   --  @param Model Model to update.
   --  @param Name Loaded item name to select.
   --  @return True when a matching visible item was selected.
   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean;

   --  Record a recoverable error key.
   --
   --  @param Model Model to update.
   --  @param Error_Key Localized error key.
   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String);

   --  Return the last recoverable error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Last_Error_Key
     (Model : Window_Model)
      return String;

private
   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Natural);

   type Window_Model is record
      Current_Path_Value   : UString;
      Home_Path_Value      : UString;
      Items                : Files.File_System.Item_Vectors.Vector;
      Directory_Signature  : Files.File_System.Directory_Signature;
      Filter_Value         : UString;
      Selected_Item_Index  : Natural := 0;
      Selected_Item_Indexes : Natural_Vectors.Vector;
      Selection_Columns   : Positive := 1;
      View_Value           : Files.Types.View_Mode := Files.Types.Small_Icons;
      Sort_Field_Value     : Sort_Field := Sort_Name;
      Sort_Ascending       : Boolean := True;
      Sort_Menu_Open       : Boolean := False;
      Back_History         : Files.Types.String_Vectors.Vector;
      Forward_History      : Files.Types.String_Vectors.Vector;
      Focus_Value          : Files.Types.Focus_Target := Files.Types.Focus_None;
      Path_Input_Value     : UString;
      Path_Input_Cursor    : Natural := 0;
      Path_Input_Valid     : Boolean := True;
      Path_Input_Error     : UString;
      Info_Pane_Open       : Boolean := False;
      Settings_Pane_Open   : Boolean := False;
      Settings_Draft_Value : Files.Settings.Settings_Draft;
      Settings_Field       : Natural := 1;
      Settings_Field_Cursor : Natural := 0;
      Info_Pane_Scroll     : Natural := 0;
      Main_View_Scroll     : Natural := 0;
      Root_Selector_Open   : Boolean := False;
      Root_Entries         : Files.File_System.Root_Entry_Vectors.Vector;
      Root_Selected        : Natural := 0;
      Command_Palette_Open     : Boolean := False;
      Command_Palette_Query    : UString;
      Command_Palette_Cursor   : Natural := 0;
      Command_Palette_Selected : Natural := 0;
      Command_Palette_Offset   : Natural := 0;
      Rename_Active            : Boolean := False;
      Rename_Item_Index    : Natural := 0;
      Rename_Value         : UString;
      Rename_Cursor        : Natural := 0;
      Temporary_Active     : Boolean := False;
      Temporary_Name_Value : UString;
      Filter_Cursor        : Natural := 0;
      Last_Error           : UString;
   end record;
end Files.Model;
