with Files.Commands;
with Files.Rendering;
with Files.Types;

--  GLFW-style input translation into internal command and selection events.
package Files.Events is

   type Input_Action_Kind is
     (No_Input_Action,
      Command_Input_Action,
      Selection_Input_Action,
      Scroll_Input_Action,
      Scrollbar_Drag_Begin_Input_Action,
      Text_Click_Input_Action,
      Settings_Click_Input_Action,
      Item_Click_Input_Action,
      Root_Click_Input_Action,
      Command_Result_Click_Input_Action);

   type Scroll_Target is
     (Scroll_Auto,
      Scroll_Main_View,
      Scroll_Info_Pane,
      Scroll_Settings_Pane,
      Scroll_Command_Palette);

   type Input_Action is record
      Kind         : Input_Action_Kind := No_Input_Action;
      Command      : Files.Commands.Command_Id := Files.Commands.No_Command;
      Direction    : Files.Types.Navigation_Direction := Files.Types.Move_Right;
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
     (Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set)
      return Input_Action;

   --  Translate a window click into an internal input action.
   --
   --  @param Snapshot Immutable view snapshot used for overlay and item hit tests.
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
      Modifiers   : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
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
