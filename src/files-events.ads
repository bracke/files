with Files.Input_Actions;
with Files.Rendering;
with Guikit.Input;

--  GLFW-style input translation into internal command and selection events.
package Files.Events is

   --  The input action values (Files.Input_Actions), by their names here.

   subtype Right_Click_Target is Files.Input_Actions.Right_Click_Target;
   --  @return The literal On_Context_Menu of Right_Click_Target, as Files.Input_Actions names it.
   function On_Context_Menu return Right_Click_Target
     renames Files.Input_Actions.On_Context_Menu;
   --  @return The literal On_Details_Header of Right_Click_Target, as Files.Input_Actions names it.
   function On_Details_Header return Right_Click_Target
     renames Files.Input_Actions.On_Details_Header;
   --  @return The literal On_Main_View of Right_Click_Target, as Files.Input_Actions names it.
   function On_Main_View return Right_Click_Target
     renames Files.Input_Actions.On_Main_View;
   --  @return The literal Elsewhere of Right_Click_Target, as Files.Input_Actions names it.
   function Elsewhere return Right_Click_Target
     renames Files.Input_Actions.Elsewhere;

   subtype Input_Action_Kind is Files.Input_Actions.Input_Action_Kind;
   --  @return The literal No_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function No_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.No_Input_Action;
   --  @return The literal Command_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Command_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Command_Input_Action;
   --  @return The literal Selection_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Selection_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Selection_Input_Action;
   --  @return The literal Scroll_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Scroll_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Scroll_Input_Action;
   --  @return The literal Scrollbar_Drag_Begin_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Scrollbar_Drag_Begin_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Scrollbar_Drag_Begin_Input_Action;
   --  @return The literal Column_Resize_Begin_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Column_Resize_Begin_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Column_Resize_Begin_Input_Action;
   --  @return The literal Column_Reorder_Begin_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Column_Reorder_Begin_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Column_Reorder_Begin_Input_Action;
   --  @return The literal Marquee_Begin_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Marquee_Begin_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Marquee_Begin_Input_Action;
   --  @return The literal Text_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Text_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Text_Click_Input_Action;
   --  @return The literal Settings_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Settings_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Settings_Click_Input_Action;
   --  @return The literal Item_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Item_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Item_Click_Input_Action;
   --  @return The literal Item_Drop_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Item_Drop_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Item_Drop_Input_Action;
   --  @return The literal Root_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Root_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Root_Click_Input_Action;
   --  @return The literal Breadcrumb_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Breadcrumb_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Breadcrumb_Click_Input_Action;
   --  @return The literal Path_Favorite_Toggle_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Path_Favorite_Toggle_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Path_Favorite_Toggle_Input_Action;
   --  @return The literal Tree_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Tree_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Tree_Click_Input_Action;
   --  @return The literal Tree_Pick_Confirm_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Tree_Pick_Confirm_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Tree_Pick_Confirm_Input_Action;
   --  @return The literal Command_Result_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Command_Result_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Command_Result_Click_Input_Action;
   --  @return The literal Permission_Toggle_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Permission_Toggle_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Permission_Toggle_Input_Action;
   --  @return The literal Ownership_Edit_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Ownership_Edit_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Ownership_Edit_Input_Action;
   --  @return The literal Conflict_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Conflict_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Conflict_Click_Input_Action;
   --  @return The literal Foreground_Job_Cancel_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Foreground_Job_Cancel_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Foreground_Job_Cancel_Input_Action;
   --  @return The literal Search_Scope_Toggle_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Search_Scope_Toggle_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Search_Scope_Toggle_Input_Action;
   --  @return The literal Label_Picker_Choice_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Label_Picker_Choice_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Label_Picker_Choice_Input_Action;
   --  @return The literal Context_Menu_Command_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Context_Menu_Command_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Context_Menu_Command_Input_Action;
   --  @return The literal Right_Click_Input_Action of Input_Action_Kind, as Files.Input_Actions names it.
   function Right_Click_Input_Action return Input_Action_Kind
     renames Files.Input_Actions.Right_Click_Input_Action;

   subtype Conflict_Button_Kind is Files.Input_Actions.Conflict_Button_Kind;
   --  @return The literal No_Conflict_Button of Conflict_Button_Kind, as Files.Input_Actions names it.
   function No_Conflict_Button return Conflict_Button_Kind
     renames Files.Input_Actions.No_Conflict_Button;
   --  @return The literal Conflict_Button_Replace of Conflict_Button_Kind, as Files.Input_Actions names it.
   function Conflict_Button_Replace return Conflict_Button_Kind
     renames Files.Input_Actions.Conflict_Button_Replace;
   --  @return The literal Conflict_Button_Skip of Conflict_Button_Kind, as Files.Input_Actions names it.
   function Conflict_Button_Skip return Conflict_Button_Kind
     renames Files.Input_Actions.Conflict_Button_Skip;
   --  @return The literal Conflict_Button_Rename of Conflict_Button_Kind, as Files.Input_Actions names it.
   function Conflict_Button_Rename return Conflict_Button_Kind
     renames Files.Input_Actions.Conflict_Button_Rename;
   --  @return The literal Conflict_Button_Cancel of Conflict_Button_Kind, as Files.Input_Actions names it.
   function Conflict_Button_Cancel return Conflict_Button_Kind
     renames Files.Input_Actions.Conflict_Button_Cancel;
   --  @return The literal Conflict_Button_Apply_All of Conflict_Button_Kind, as Files.Input_Actions names it.
   function Conflict_Button_Apply_All return Conflict_Button_Kind
     renames Files.Input_Actions.Conflict_Button_Apply_All;

   subtype Scroll_Target is Files.Input_Actions.Scroll_Target;
   --  @return The literal No_Scroll_Target of Scroll_Target, as Files.Input_Actions names it.
   function No_Scroll_Target return Scroll_Target
     renames Files.Input_Actions.No_Scroll_Target;
   --  @return The literal Scroll_Main_View of Scroll_Target, as Files.Input_Actions names it.
   function Scroll_Main_View return Scroll_Target
     renames Files.Input_Actions.Scroll_Main_View;
   --  @return The literal Scroll_Info_Pane of Scroll_Target, as Files.Input_Actions names it.
   function Scroll_Info_Pane return Scroll_Target
     renames Files.Input_Actions.Scroll_Info_Pane;
   --  @return The literal Scroll_Tree_Panel of Scroll_Target, as Files.Input_Actions names it.
   function Scroll_Tree_Panel return Scroll_Target
     renames Files.Input_Actions.Scroll_Tree_Panel;
   --  @return The literal Scroll_Settings_Pane of Scroll_Target, as Files.Input_Actions names it.
   function Scroll_Settings_Pane return Scroll_Target
     renames Files.Input_Actions.Scroll_Settings_Pane;
   --  @return The literal Scroll_Command_Palette of Scroll_Target, as Files.Input_Actions names it.
   function Scroll_Command_Palette return Scroll_Target
     renames Files.Input_Actions.Scroll_Command_Palette;

   subtype Permission_Bit is Files.Input_Actions.Permission_Bit;

   subtype Input_Action is Files.Input_Actions.Input_Action;

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
      Line_Height : Positive)
      return Input_Action;

   --  Translate a right click into the context-menu action it asks for. A
   --  coordinate on or past the window's right or bottom edge names no pixel
   --  and is no action.
   --
   --  @param Snapshot The snapshot the frame on screen was built from.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return A Right_Click_Input_Action, or No_Input_Action.
   function Translate_Right_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Input_Action;

   --  The focus command a screen reader's request on the path or filter
   --  field asks for. A text field is focused, never clicked: its centre may
   --  lie on a breadcrumb or the scope chip, which a synthesised click would
   --  run instead. Node_* are the request's node bounds, in frame pixels; only
   --  the field boxes the toolbar draws (Layouts.Path_Field_Text_Region and
   --  Filter_Field_Text_Region, Field_X/Field_Width) match.
   --
   --  @param Node_X Left edge of the node.
   --  @param Node_Y Top edge of the node.
   --  @param Node_W Width of the node.
   --  @param Node_H Height of the node.
   --  @param Width Frame width in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return The field's focus command, or No_Input_Action for any other node.
   function Translate_Field_Request
     (Node_X      : Natural;
      Node_Y      : Natural;
      Node_W      : Natural;
      Node_H      : Natural;
      Width       : Natural;
      Line_Height : Positive)
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
      Line_Height : Positive)
      return Input_Action;

end Files.Events;
