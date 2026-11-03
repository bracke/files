with Files.Commands;
with Files.Rendering;
with Guikit.Input;
with Files.Types;
with Files.UI;

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

   --  Which paste-conflict-dialog control a Conflict_Click_Input_Action hit.
   type Conflict_Button_Kind is
     (No_Conflict_Button,
      Conflict_Button_Replace,
      Conflict_Button_Skip,
      Conflict_Button_Rename,
      Conflict_Button_Cancel,
      Conflict_Button_Apply_All);

   --  A permission bit as the info pane's grid numbers them: 0 is others'
   --  execute, 8 the owner's read.
   subtype Permission_Bit is Natural range 0 .. 8;

   type Scroll_Target is
     (Scroll_Auto,
      Scroll_Main_View,
      Scroll_Info_Pane,
      Scroll_Tree_Panel,
      Scroll_Settings_Pane,
      Scroll_Command_Palette);

   --  Translated input action. Each kind reads the fields named for it:
   --  Item_Index is an item (a breadcrumb segment, a tree node for a
   --  Tree_Click_Input_Action, with Toggle_Selection for its expander), and the
   --  drags, the label picker, the permission grid and the ownership editor
   --  have their own typed fields below.
   type Input_Action is record
      Kind         : Input_Action_Kind := No_Input_Action;
      Command      : Files.Commands.Command_Id := Files.Commands.No_Command;
      Direction    : Guikit.Input.Navigation_Direction := Guikit.Input.Move_Right;
      Item_Index   : Natural := 0;
      Root_Index   : Natural := 0;
      Result_Index : Natural := 0;
      Click_X      : Integer := 0;  --  palette click coordinates (component hit-test)
      Click_Y      : Integer := 0;
      Scroll_Lines : Integer := 0;
      Scroll_Area  : Scroll_Target := Scroll_Auto;
      Focus_Target : Files.Types.Focus_Target := Files.Types.Focus_None;
      Cursor_Position : Natural := 0;
      Settings_Field  : Natural := 0;
      Settings_Option : Natural := 0;
      --  The paste-conflict dialog button of a Conflict_Click_Input_Action.
      Conflict_Button : Conflict_Button_Kind := No_Conflict_Button;
      Activate     : Boolean := False;
      Toggle_Selection : Boolean := False;
      Range_Selection  : Boolean := False;
      Scroll_Drag_Anchor : Integer := 0;
      --  A column resize or reorder: the column, and for a resize its width
      --  when the drag began.
      Column       : Files.Types.Optional_Detail_Column := Files.Types.Optional_Detail_Column'First;
      Column_Width : Natural := 0;
      --  Where a column or marquee drag began (framebuffer pixels), and
      --  whether a marquee adds to the selection (Ctrl or Shift held).
      Origin_X     : Natural := 0;
      Origin_Y     : Natural := 0;
      Additive     : Boolean := False;
      --  The label picker's chosen swatch (No_Label clears).
      Label        : Files.Types.Color_Label := Files.Types.No_Label;
      --  The permission grid's bit, and whether the ownership editor edits
      --  the group (else the owner).
      Bit          : Permission_Bit := 0;
      Edit_Group   : Boolean := False;
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
      Line_Height : Positive := Files.UI.Base_Line_Height)
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
      Line_Height : Positive := Files.UI.Base_Line_Height)
      return Input_Action;

end Files.Events;
