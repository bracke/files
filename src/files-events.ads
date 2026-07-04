with Files.Commands;
with Files.Rendering;
with Guikit.Input;
with Files.Types;

--  GLFW-style input translation into internal command and selection events.
package Files.Events is

   type Input_Action_Kind is
     (No_Input_Action,
      Command_Input_Action,
      Selection_Input_Action,
      Scroll_Input_Action,
      Scrollbar_Drag_Begin_Input_Action,
      Column_Resize_Begin_Input_Action,
      Column_Reorder_Begin_Input_Action,
      Marquee_Begin_Input_Action,
      Text_Click_Input_Action,
      Settings_Click_Input_Action,
      Item_Click_Input_Action,
      Root_Click_Input_Action,
      Breadcrumb_Click_Input_Action,
      Path_Favorite_Toggle_Input_Action,
      Tree_Click_Input_Action,
      Tree_Pick_Confirm_Input_Action,
      Command_Result_Click_Input_Action,
      Permission_Toggle_Input_Action,
      Ownership_Edit_Input_Action,
      Conflict_Click_Input_Action,
      Paste_Cancel_Input_Action,
      Search_Scope_Toggle_Input_Action,
      Label_Picker_Choice_Input_Action);

   --  Button codes carried in Input_Action.Settings_Field for a
   --  Conflict_Click_Input_Action, identifying which paste-conflict-dialog
   --  control was clicked.
   Conflict_Button_Replace   : constant := 1;
   Conflict_Button_Skip      : constant := 2;
   Conflict_Button_Rename    : constant := 3;
   Conflict_Button_Cancel    : constant := 4;
   Conflict_Button_Apply_All : constant := 5;

   type Scroll_Target is
     (Scroll_Auto,
      Scroll_Main_View,
      Scroll_Info_Pane,
      Scroll_Settings_Pane,
      Scroll_Command_Palette);

   --  Translated input action. Several fields are reused per Kind. For a
   --  Column_Resize_Begin_Input_Action the payload is packed into the shared
   --  fields: Item_Index holds Files.Types.Detail_Column'Pos of the column the
   --  drag resizes, Cursor_Position holds the separator's origin x edge, and
   --  Scroll_Drag_Anchor holds the column's effective width at drag start. For a
   --  Column_Reorder_Begin_Input_Action Item_Index holds the dragged optional
   --  column's Detail_Column'Pos, Cursor_Position the press x, and Command the
   --  sort command to apply should the press turn out to be a plain click rather
   --  than a drag. For a
   --  Breadcrumb_Click_Input_Action Item_Index holds the one-based breadcrumb
   --  segment index. For a Tree_Click_Input_Action Item_Index holds the tree
   --  node index and Toggle_Selection is True when the expander triangle was
   --  clicked (expand/collapse) rather than the row label (navigate). For a
   --  Marquee_Begin_Input_Action Cursor_Position and Settings_Field hold the
   --  press-point x and y (the rubber-band origin) and Toggle_Selection is True
   --  when the marquee is additive (Ctrl or Shift held at press). For a
   --  Label_Picker_Choice_Input_Action Item_Index holds Files.Types.Color_Label
   --  'Pos of the chosen swatch (0 for No_Label, i.e. clear).
   type Input_Action is record
      Kind         : Input_Action_Kind := No_Input_Action;
      Command      : Files.Commands.Command_Id := Files.Commands.No_Command;
      Direction    : Guikit.Input.Navigation_Direction := Guikit.Input.Move_Right;
      Item_Index   : Natural := 0;
      Root_Index   : Natural := 0;
      Result_Index : Natural := 0;
      Scroll_Lines : Integer := 0;
      Scroll_Area  : Scroll_Target := Scroll_Auto;
      Focus_Target : Files.Types.Focus_Target := Files.Types.Focus_None;
      Cursor_Position : Natural := 0;
      Settings_Field  : Natural := 0;
      Settings_Option : Natural := 0;
      Activate     : Boolean := False;
      Toggle_Selection : Boolean := False;
      Range_Selection  : Boolean := False;
      Scroll_Drag_Anchor : Integer := 0;
   end record;

   --  Translate a key and modifier state into an internal input action.
   --
   --  @param Key Key code.
   --  @param Modifiers Active modifier set.
   --  @return Internal input action.
   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Input_Action;

   --  Translate a window click into an internal input action.
   --
   --  @param Snapshot Immutable view snapshot used for overlay and item hit tests.
   --  @param Frame Frame commands used to resolve overlay hit regions.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Activate True when the click should activate the target.
   --  @param Modifiers Active modifier keys for selection behavior.
   --  @param Line_Height Text line height in pixels.
   --  @return Internal input action.
   function Translate_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      Frame       : Files.Rendering.Frame_Commands;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive := 20)
      return Input_Action;

   --  Translate a vertical scroll-wheel offset into an internal input action.
   --
   --  @param Y_Offset Positive GLFW-style wheel offsets scroll up; negative values scroll down.
   --  @return Internal scroll input action or no action when the offset is zero.
   function Translate_Scroll
     (Y_Offset : Integer)
      return Input_Action;

   --  Translate a vertical scroll-wheel offset at a window coordinate.
   --
   --  @param Snapshot Immutable view snapshot used for overlay and pane hit tests.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Y_Offset Positive GLFW-style wheel offsets scroll up; negative values scroll down.
   --  @param Line_Height Text line height in pixels.
   --  @return Internal scroll input action with a concrete target, or no action outside scrollable regions.
   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive := 20)
      return Input_Action;

end Files.Events;
