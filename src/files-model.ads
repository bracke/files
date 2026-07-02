with Ada.Containers.Vectors;

with Files.File_System;
with Files.Folder_Tree;
with Files.Paste;
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

   --  Return the number of loaded hidden items.
   --
   --  Hidden items are loaded directory items whose simple name begins with a
   --  dot. This lets the bottom bar report how many dot-files are present.
   --
   --  @param Model Model to inspect.
   --  @return Count of loaded items whose simple name begins with '.'.
   function Hidden_Item_Count
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

   --  Open the info-pane ownership editor for the single selected item.
   --
   --  The editor buffer is prefilled with the selected item's current numeric
   --  owner or group id. Does nothing unless exactly one non-trash item is
   --  selected whose ownership was read on a platform that supports chown.
   --
   --  @param Model Model to update.
   --  @param Editing_Group True to edit the group id, False to edit the owner.
   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean);

   --  Return the current text of the ownership editor buffer.
   --
   --  @param Model Model to inspect.
   --  @return The editor buffer contents (empty when not editing).
   function Ownership_Input_Text
     (Model : Window_Model)
      return String;

   --  Replace the ownership editor buffer with Text.
   --
   --  @param Model Model to update.
   --  @param Text New buffer contents.
   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return whether the ownership editor is currently editing the group id.
   --
   --  @param Model Model to inspect.
   --  @return True when editing the group, False when editing the owner.
   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean;

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

   --  Toggle the folder-tree sidebar visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Tree_Panel
     (Model : in out Window_Model);

   --  Open the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Open_Tree_Panel
     (Model : in out Window_Model);

   --  Close the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Close_Tree_Panel
     (Model : in out Window_Model);

   --  Return whether the folder-tree sidebar is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the tree sidebar is open.
   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return whether the folder tree has been seeded with root nodes.
   --
   --  @param Model Model to inspect.
   --  @return True once the tree holds its root nodes.
   function Tree_Is_Seeded
     (Model : Window_Model)
      return Boolean;

   --  Seed the folder tree with root nodes.
   --
   --  @param Model Model to update.
   --  @param Roots Root locations shown at the top of the tree.
   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Return the number of nodes currently held by the folder tree.
   --
   --  @param Model Model to inspect.
   --  @return Total tree node count.
   function Tree_Node_Count
     (Model : Window_Model)
      return Natural;

   --  Return a tree node's absolute directory path.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return Node path, or an empty string when Index is out of range.
   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return whether a tree node's children have been loaded.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return True when the node's children are attached.
   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Return whether a tree node is currently expanded.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return True when the node shows its children.
   function Tree_Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Attach a tree node's child subdirectories and mark it loaded.
   --
   --  @param Model Model to update.
   --  @param Index One-based parent node index.
   --  @param Children Child subdirectories in display order.
   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Set a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   --  @param Expanded New expanded state.
   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean);

   --  Flip a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive);

   --  Return the flattened, currently visible folder-tree rows.
   --
   --  @param Model Model to inspect.
   --  @return Visible tree rows in top-to-bottom display order.
   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector;

   --  Destination-picker mode driving the folder tree while the user chooses a
   --  Copy to.../Move to... target directory.
   type Tree_Pick_Mode is (Pick_None, Pick_Copy, Pick_Move);

   --  Begin the destination-picker sub-mode: record the copy/move intent, the
   --  captured source paths, and the initial highlighted target directory.
   --
   --  @param Model Model to update.
   --  @param Mode Copy or move intent (Pick_None clears the picker).
   --  @param Sources Full source paths to copy or move.
   --  @param Initial_Target Directory highlighted as the initial destination.
   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String);

   --  Set the highlighted destination directory for the active picker.
   --
   --  @param Model Model to update.
   --  @param Target Directory to highlight as the destination.
   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String);

   --  Clear the destination-picker sub-mode and its captured sources.
   --
   --  @param Model Model to update.
   procedure Clear_Tree_Pick
     (Model : in out Window_Model);

   --  Return the active destination-picker mode.
   --
   --  @param Model Model to inspect.
   --  @return Pick_None when no destination picker is active.
   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode;

   --  Return whether a destination picker is active.
   --
   --  @param Model Model to inspect.
   --  @return True when a Copy to.../Move to... picker is running.
   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the captured destination-picker source paths.
   --
   --  @param Model Model to inspect.
   --  @return Source paths to copy or move when the picker confirms.
   function Tree_Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return the highlighted destination directory.
   --
   --  @param Model Model to inspect.
   --  @return Currently highlighted destination path, or an empty string.
   function Tree_Pick_Target
     (Model : Window_Model)
      return String;

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

   --  Scroll the settings pane by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Settings_Pane
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current settings-pane scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative settings-pane scroll offset.
   function Settings_Pane_Scroll_Lines
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

   --  Set the main-view scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New main-view scroll offset in logical text lines.
   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

   --  Set the info-pane scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New info-pane scroll offset in logical text lines.
   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

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

   type Palette_Mode is (Palette_Commands, Palette_Open_With);

   --  Return the active command-palette mode.
   --
   --  @param Model Model to inspect.
   --  @return Palette_Commands for the registered-command picker, or
   --  Palette_Open_With for the "Open With" application picker.
   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode;

   --  Set the active command-palette mode.
   --
   --  @param Model Model to update.
   --  @param Mode New palette mode.
   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode);

   --  Replace the stored "Open With" target paths.
   --
   --  @param Model Model to update.
   --  @param Targets Full paths the chosen application should open.
   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector);

   --  Return the stored "Open With" target paths.
   --
   --  @param Model Model to inspect.
   --  @return Full paths captured for the "Open With" picker.
   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return whether rename can start for the current selection.
   --
   --  @param Model Model to inspect.
   --  @return True when at least one non-temporary item is selected.
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

   --  Toggle synchronized multi-item rename mode.
   --
   --  When starting, one inline rename field is created per selected loaded
   --  item, each with its caret placed before the file extension.
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

   --  Return the number of active inline rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Count of rename fields (zero when rename is inactive).
   function Rename_Field_Count
     (Model : Window_Model)
      return Natural;

   --  Return the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to inspect.
   --  @return First field's rename text, or an empty string.
   function Rename_Text
     (Model : Window_Model)
      return String;

   --  Set the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to update.
   --  @param Text New rename text for the first field.
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Insert Text at every rename field's caret, advancing each caret.
   --
   --  @param Model Model to update.
   --  @param Text UTF-8 text to insert.
   --  @return True when any field changed.
   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean;

   --  Delete the character before every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the character at every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Forward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the word before every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Word_Backward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the word at every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Word_Forward
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret one text boundary in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @return True when any caret moved.
   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction)
      return Boolean;

   --  Move every rename field's caret one word boundary in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @return True when any caret moved.
   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Files.Types.Navigation_Direction)
      return Boolean;

   --  Move every rename field's caret to the start of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret to the end of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean;

   --  Set the caret of the rename field shown at Visible_Index only.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible row index of the clicked field.
   --  @param Position Byte offset of the new caret (clamped to a boundary).
   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural);

   --  Return the rename state for the item shown at Visible_Index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible row index.
   --  @param Active Set True when that row has an active rename field.
   --  @param Value Field text (empty when inactive).
   --  @param Cursor Field caret byte offset (zero when inactive).
   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural);

   type Rename_Target is record
      Item_Index    : Natural := 0;
      Old_Full_Path : UString;
      Old_Name      : UString;
      New_Name      : UString;
   end record;

   package Rename_Target_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Target);

   --  Return the commit targets for the active real-item rename fields.
   --
   --  @param Model Model to inspect.
   --  @return One target per real rename field (temporary fields excluded).
   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector;

   --  Resume single-item rename mode for the currently selected item.
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

   --  Begin temporary create-folder state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary folder name.
   procedure Begin_Create_Folder
     (Model : in out Window_Model;
      Name  : String);

   --  Return whether a temporary create-file item is active.
   --
   --  @param Model Model to inspect.
   --  @return True when temporary item exists.
   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return whether the active temporary item creates a directory.
   --
   --  @param Model Model to inspect.
   --  @return True when the temporary item is a directory.
   function Temporary_Item_Is_Directory
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

   type Context_Menu_Target is
     (Context_Menu_None,
      Context_Menu_Item,
      Context_Menu_Empty,
      Context_Menu_Header);

   --  Open the right-click context menu at the given window position.
   --
   --  @param Model Model to update.
   --  @param X Window-space X coordinate of the cursor.
   --  @param Y Window-space Y coordinate of the cursor.
   --  @param Target Whether the menu is anchored on an item, the empty grid, or
   --    the details-view column header.
   --  @param Item_Index Visible item index when the menu is anchored on a row.
   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0);

   --  Close the right-click context menu.
   --
   --  @param Model Model to update.
   procedure Close_Context_Menu
     (Model : in out Window_Model);

   --  Return whether the context menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the context menu is open.
   function Context_Menu_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the anchor X coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor X coordinate in pixels.
   function Context_Menu_X
     (Model : Window_Model)
      return Natural;

   --  Return the anchor Y coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor Y coordinate in pixels.
   function Context_Menu_Y
     (Model : Window_Model)
      return Natural;

   --  Return whether the menu was opened on an item or the empty area.
   --
   --  @param Model Model to inspect.
   --  @return Whether the menu targets an item or the empty area.
   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target;

   --  Return the item index the menu was anchored to (0 when empty area).
   --
   --  @param Model Model to inspect.
   --  @return The anchored item index, or 0 when opened on the empty area.
   function Context_Menu_Item_Index
     (Model : Window_Model)
      return Natural;

   type Clipboard_Mode is (Clipboard_None, Clipboard_Copy, Clipboard_Cut);

   --  Record a clipboard snapshot of source paths and a copy/cut mode.
   --
   --  @param Model Model to update.
   --  @param Paths Filesystem paths to remember.
   --  @param Mode  Copy or cut intent for the next paste.
   procedure Set_Clipboard
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode);

   --  Clear any pending clipboard snapshot.
   --
   --  @param Model Model to update.
   procedure Clear_Clipboard
     (Model : in out Window_Model);

   --  Return the remembered clipboard source paths.
   --
   --  @param Model Model to inspect.
   --  @return Filesystem paths captured on the last copy or cut.
   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return whether the clipboard intent is copy or cut.
   --
   --  @param Model Model to inspect.
   --  @return Clipboard_None when no clipboard snapshot exists.
   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode;

   --  Return whether the clipboard has at least one remembered path.
   --
   --  @param Model Model to inspect.
   --  @return True when paste can act.
   function Clipboard_Has_Items
     (Model : Window_Model)
      return Boolean;

   --  Multi-level undo/redo history. Each entry stores enough to BOTH reverse
   --  (undo) and re-apply (redo) one action. Paths are parallel From/To
   --  vectors; Forward carries the redo payload and Create_Kind names the kind
   --  of creation to re-run for Undo_Delete_Created entries.
   type Undo_Action_Kind is
     (Undo_None,
      Undo_Rename,
      Undo_Move,
      Undo_Restore_Trash,
      Undo_Delete_Created,
      Undo_Set_Permissions,
      Undo_Set_Ownership);

   --  How an Undo_Delete_Created entry re-creates its paths on redo.
   type Undo_Create_Kind is
     (Create_None,
      Create_Copy,
      Create_Symbolic_Link,
      Create_Hard_Link);

   --  A single reversible/re-applicable action.
   --
   --  Undo runs the reverse direction, redo the forward direction:
   --    * Rename/Move: reverse moves From back to To, redo re-does the original
   --      To -> From transition.
   --    * Restore_Trash: reverse restores the trashed From paths; it is
   --      undo-only (Redoable is False), so redo never re-runs it.
   --    * Delete_Created: reverse deletes From; redo re-creates each From path
   --      from the parallel source path in Forward using Create_Kind.
   --    * Set_Permissions/Set_Ownership: To holds the old value (reverse) and
   --      Forward holds the new value (redo), both parallel to From.
   type Undo_Entry is record
      Kind        : Undo_Action_Kind := Undo_None;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
   end record;

   --  Stack of undo/redo entries; the last element is the top of the stack.
   package Undo_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Undo_Entry);

   --  Push a newly performed undoable action onto the undo stack and clear the
   --  redo stack (a new operation invalidates any pending redo). Empty actions
   --  (Undo_None or no From paths) are ignored.
   --
   --  @param Model       Model to update.
   --  @param Kind        Kind of action that can be undone.
   --  @param From        Current locations to undo from (parallel to To).
   --  @param To          Restore targets / old values (reverse payload).
   --  @param Forward     Redo payload: source paths or new values; may be empty.
   --  @param Create_Kind Creation kind re-run for Undo_Delete_Created redo.
   --  @param Redoable    False marks the entry undo-only (skipped by redo).
   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True);

   --  Forget the entire undo and redo history.
   --
   --  @param Model Model to update.
   procedure Clear_Undo
     (Model : in out Window_Model);

   --  Return whether an undoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the undo stack is non-empty.
   function Undo_Available
     (Model : Window_Model)
      return Boolean;

   --  Return whether a redoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the redo stack is non-empty.
   function Redo_Available
     (Model : Window_Model)
      return Boolean;

   --  Pop the top entry off the undo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Pop the top entry off the redo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Push an action onto the redo stack (after a successful undo).
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Push an action back onto the undo stack (after a successful redo),
   --  leaving the redo stack untouched.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Return the kind of the top undo entry.
   --
   --  @param Model Model to inspect.
   --  @return Undo_None when the undo stack is empty.
   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind;

   --  Return the top undo entry's "from" (current) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of current locations, parallel to Undo_To_Paths.
   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return the top undo entry's "to" (restore-target) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of restore targets, parallel to Undo_From_Paths.
   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Enter the pending paste-conflict sub-mode. The work-list, the set of
   --  existing destination paths, and the copy/move mode are recorded, the
   --  policy starts at Policy_Ask with no per-item overrides, and the dialog is
   --  positioned at the first unresolved conflict (Index).
   --
   --  @param Model Model to update.
   --  @param Items Full paste work-list.
   --  @param Existing Destination paths that already exist.
   --  @param Mode Copy or move mode for the whole batch.
   --  @param Index One-based index of the first unresolved conflict.
   --  @param Clear_Clipboard Whether finalizing a move should clear the
   --    clipboard (True for clipboard paste, False for drag-and-drop).
   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True);

   --  Whether the pending paste-conflict dialog is active.
   --
   --  @param Model Model to inspect.
   --  @return True while a paste is paused awaiting conflict decisions.
   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The recorded paste work-list.
   --
   --  @param Model Model to inspect.
   --  @return The full work-list captured when the sub-mode began.
   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector;

   --  The recorded set of existing destination paths.
   --
   --  @param Model Model to inspect.
   --  @return Destination paths that existed when the sub-mode began.
   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The accumulated per-item decisions, parallel to the work-list.
   --
   --  @param Model Model to inspect.
   --  @return Per-item overrides recorded so far.
   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector;

   --  The accumulated batch-wide policy.
   --
   --  @param Model Model to inspect.
   --  @return The current conflict policy.
   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy;

   --  The copy/move mode of the pending paste.
   --
   --  @param Model Model to inspect.
   --  @return Copy or move mode.
   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode;

   --  Whether finalizing this paste's move should clear the clipboard.
   --
   --  @param Model Model to inspect.
   --  @return True for a clipboard-originated paste, False for drag-and-drop.
   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean;

   --  The one-based index of the conflict currently shown, or 0 when inactive.
   --
   --  @param Model Model to inspect.
   --  @return Index into the work-list of the conflict under decision.
   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural;

   --  The leaf name of the conflict currently shown.
   --
   --  @param Model Model to inspect.
   --  @return The colliding destination name, or "" when inactive.
   function Paste_Conflict_Name
     (Model : Window_Model)
      return String;

   --  Whether the dialog's "apply to all remaining" toggle is on.
   --
   --  @param Model Model to inspect.
   --  @return True when the next decision should apply to every remaining conflict.
   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean;

   --  Flip the dialog's "apply to all remaining" toggle.
   --
   --  @param Model Model to update.
   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model);

   --  Record the batch-wide policy (used when a decision is applied to all).
   --
   --  @param Model Model to update.
   --  @param Policy New conflict policy.
   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy);

   --  Record a per-item decision for one work-list index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index.
   --  @param Decision Chosen per-item decision.
   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision);

   --  Move the dialog to a different conflict index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index of the next conflict.
   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive);

   --  Clear the pending paste-conflict sub-mode, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Paste_Conflict
     (Model : in out Window_Model);

   --  Arm a resumable paste execution from a fully resolved action list. The
   --  execution starts at the first action with no items completed; Total counts
   --  only the actions that actually write (non-skip), so progress reflects the
   --  real copies/moves. The batched driver advances it a few actions at a time.
   --
   --  @param Model Model to update.
   --  @param Actions Fully resolved paste actions (post conflict resolution).
   --  @param Mode Copy or move mode for the whole batch.
   --  @param Clear_Clipboard Whether finalizing a move should clear the
   --    clipboard (True for clipboard paste, False for drag-and-drop).
   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True);

   --  Whether a resumable paste execution is currently in flight.
   --
   --  @param Model Model to inspect.
   --  @return True between Begin_Paste_Execution and Clear_Paste_Execution.
   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The number of write actions completed so far.
   --
   --  @param Model Model to inspect.
   --  @return Count of items already copied or moved.
   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural;

   --  The total number of write actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of items to copy or move (skips excluded).
   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural;

   --  The leaf name of the item most recently written, for the progress display.
   --
   --  @param Model Model to inspect.
   --  @return The current item's simple name, or "" before the first write.
   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String;

   --  The copy/move mode of the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Copy or move mode.
   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode;

   --  Whether finalizing this execution's move should clear the clipboard.
   --
   --  @param Model Model to inspect.
   --  @return True for a clipboard-originated paste, False for drag-and-drop.
   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean;

   --  Whether the armed execution has been asked to cancel.
   --
   --  @param Model Model to inspect.
   --  @return True once Cancel_Paste_Execution has been requested.
   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean;

   --  The cursor position: the number of actions already consumed.
   --
   --  @param Model Model to inspect.
   --  @return Zero-based count of processed actions (writes and skips).
   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural;

   --  The number of resolved actions in the armed execution.
   --
   --  @param Model Model to inspect.
   --  @return Count of actions (writes and skips).
   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural;

   --  The resolved action at a one-based index.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based action index (1 .. Paste_Execution_Action_Count).
   --  @return The resolved action to execute.
   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action;

   --  The accumulated undo "from" paths (destinations) for completed writes.
   --
   --  @param Model Model to inspect.
   --  @return Destination paths written so far.
   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The accumulated undo "to" paths (sources) for completed writes.
   --
   --  @param Model Model to inspect.
   --  @return Source paths written so far.
   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The first destination path written, reported as the operation result path.
   --
   --  @param Model Model to inspect.
   --  @return The first written destination, or "" when nothing was written.
   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String;

   --  Advance the cursor past a skipped action without recording a write.
   --
   --  @param Model Model to update.
   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model);

   --  Record a completed write: advance the cursor, bump Done, remember the
   --  current name and first destination, and accumulate the undo pair.
   --
   --  @param Model Model to update.
   --  @param Dest_Path Destination path just written.
   --  @param Source_Path Source path just copied or moved.
   --  @param Name Leaf name shown as the current progress item.
   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String);

   --  Request cancellation of the armed execution; the next advance finalizes
   --  over the items completed so far (already-written files are kept).
   --
   --  @param Model Model to update.
   procedure Cancel_Paste_Execution
     (Model : in out Window_Model);

   --  Clear the resumable paste execution, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Paste_Execution
     (Model : in out Window_Model);

   --  Cache a recursive folder-size measurement for a directory path.
   --
   --  The cache holds one measurement at a time, keyed by Path, so a repeated
   --  selection of the same directory reuses it instead of walking again.
   --
   --  @param Model Model to update.
   --  @param Path Directory the measurement describes.
   --  @param Value Recursive size totals for Path.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result);

   --  Forget any cached folder-size measurement.
   --
   --  @param Model Model to update.
   procedure Clear_Folder_Size
     (Model : in out Window_Model);

   --  Return whether a folder-size measurement is cached for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to test against the cache key.
   --  @return True when a measurement for exactly Path is cached.
   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean;

   --  Return the cached folder-size measurement.
   --
   --  @param Model Model to inspect.
   --  @return Cached totals; Available is False when nothing is cached.
   function Folder_Size_Value
     (Model : Window_Model)
      return Files.File_System.Directory_Size_Result;

   --  Return the path the cached folder-size measurement describes.
   --
   --  @param Model Model to inspect.
   --  @return Cached measurement path, or an empty string when nothing is cached.
   function Folder_Size_Path
     (Model : Window_Model)
      return String;

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

   --  One inline rename editor. Item_Index is a loaded-item index (1 .. last)
   --  for a real item, or 0 for the temporary create item. Value is the edited
   --  name and Cursor is the byte offset of that field's caret.
   type Rename_Field is record
      Item_Index : Natural := 0;
      Value      : UString;
      Cursor     : Natural := 0;
   end record;

   package Rename_Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Rename_Field);

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
      Ownership_Input_Value   : UString;
      Ownership_Input_Cursor  : Natural := 0;
      Ownership_Editing_Group_Value : Boolean := False;
      Info_Pane_Scroll     : Natural := 0;
      Settings_Pane_Scroll : Natural := 0;
      Main_View_Scroll     : Natural := 0;
      Root_Selector_Open   : Boolean := False;
      Root_Entries         : Files.File_System.Root_Entry_Vectors.Vector;
      Root_Selected        : Natural := 0;
      Tree_Panel_Open      : Boolean := False;
      Folder_Tree_Value    : Files.Folder_Tree.Tree;
      Tree_Pick_Mode_Value    : Tree_Pick_Mode := Pick_None;
      Tree_Pick_Sources_Value : Files.Types.String_Vectors.Vector;
      Tree_Pick_Target_Value  : UString;
      Command_Palette_Open     : Boolean := False;
      Command_Palette_Query    : UString;
      Command_Palette_Cursor   : Natural := 0;
      Command_Palette_Selected : Natural := 0;
      Command_Palette_Offset   : Natural := 0;
      Command_Palette_Mode     : Palette_Mode := Palette_Commands;
      Open_With_Targets_Value  : Files.Types.String_Vectors.Vector;
      Rename_Active            : Boolean := False;
      Rename_Fields            : Rename_Field_Vectors.Vector;
      Temporary_Active     : Boolean := False;
      Temporary_Is_Directory : Boolean := False;
      Temporary_Name_Value : UString;
      Filter_Cursor        : Natural := 0;
      Last_Error           : UString;
      Clipboard_Paths_Value : Files.Types.String_Vectors.Vector;
      Clipboard_Mode_Value  : Clipboard_Mode := Clipboard_None;
      Undo_Stack            : Undo_Entry_Vectors.Vector;
      Redo_Stack            : Undo_Entry_Vectors.Vector;
      Folder_Size_Known_Value : Boolean := False;
      Folder_Size_Path_Value  : UString;
      Folder_Size_Value       : Files.File_System.Directory_Size_Result;
      Context_Menu_Open_Value       : Boolean := False;
      Context_Menu_X_Value          : Natural := 0;
      Context_Menu_Y_Value          : Natural := 0;
      Context_Menu_Target_Value     : Context_Menu_Target := Context_Menu_None;
      Context_Menu_Item_Index_Value : Natural := 0;
      Paste_Conflict_Active_Value    : Boolean := False;
      Paste_Conflict_Items_Value     : Files.Paste.Work_Item_Vectors.Vector;
      Paste_Conflict_Existing_Value  : Files.Types.String_Vectors.Vector;
      Paste_Conflict_Overrides_Value : Files.Paste.Item_Decision_Vectors.Vector;
      Paste_Conflict_Policy_Value    : Files.Paste.Conflict_Policy := Files.Paste.Policy_Ask;
      Paste_Conflict_Mode_Value      : Files.File_System.Drop_Import_Mode :=
        Files.File_System.Drop_Copy;
      Paste_Conflict_Index_Value     : Natural := 0;
      Paste_Conflict_Apply_All_Value : Boolean := False;
      Paste_Conflict_Clears_Clip_Val : Boolean := True;
      Paste_Exec_Active_Value        : Boolean := False;
      Paste_Exec_Actions_Value       : Files.Paste.Resolved_Action_Vectors.Vector;
      Paste_Exec_Cursor_Value        : Natural := 0;
      Paste_Exec_Done_Value          : Natural := 0;
      Paste_Exec_Total_Value         : Natural := 0;
      Paste_Exec_Mode_Value          : Files.File_System.Drop_Import_Mode :=
        Files.File_System.Drop_Copy;
      Paste_Exec_Cancelled_Value     : Boolean := False;
      Paste_Exec_Clears_Clip_Value   : Boolean := True;
      Paste_Exec_Current_Value       : UString;
      Paste_Exec_First_Dest_Value    : UString;
      Paste_Exec_Undo_From_Value     : Files.Types.String_Vectors.Vector;
      Paste_Exec_Undo_To_Value       : Files.Types.String_Vectors.Vector;
   end record;
end Files.Model;
