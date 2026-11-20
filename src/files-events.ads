with Files.Input_Actions;
with Files.Rendering;
with Guikit.Input;

--  GLFW-style input translation into internal command and selection events.
package Files.Events is

   --  Translate a key and modifier state into an internal input action.
   --
   --  @param Key Key code.
   --  @param Modifiers Active modifier set.
   --  @return Internal input action.
   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Files.Input_Actions.Input_Action;

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
      return Files.Input_Actions.Input_Action;

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
   --  @return A Files.Input_Actions.Right_Click_Input_Action, or Files.Input_Actions.No_Input_Action.
   function Translate_Right_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Files.Input_Actions.Input_Action;

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
   --  @return The field's focus command, or Files.Input_Actions.No_Input_Action for any other node.
   function Translate_Field_Request
     (Node_X      : Natural;
      Node_Y      : Natural;
      Node_W      : Natural;
      Node_H      : Natural;
      Width       : Natural;
      Line_Height : Positive)
      return Files.Input_Actions.Input_Action;

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
      return Files.Input_Actions.Input_Action;

end Files.Events;
