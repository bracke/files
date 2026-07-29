with Ada.Strings.Unbounded;

with Guikit.Layout;
with Files.UTF8;
with Files.UI;

package body Files.Events is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;

   function No_Action
     (Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => No_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end No_Action;

   function Command_Action
     (Command  : Files.Commands.Command_Id;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Command_Input_Action,
         Command         => Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Command_Action;

   function Conflict_Action
     (Button   : Natural;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Conflict_Click_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => Button,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Conflict_Action;

   function Paste_Cancel_Action
     (Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Paste_Cancel_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Paste_Cancel_Action;

   --  Build a label-picker swatch-choice action carrying the chosen label's
   --  Files.Types.Color_Label'Pos in Item_Index (0 clears the label).
   function Label_Choice_Action
     (Label_Pos : Natural;
      Activate  : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Label_Picker_Choice_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => Label_Pos,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Label_Choice_Action;

   function Tree_Pick_Confirm_Action
     (Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Tree_Pick_Confirm_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Tree_Pick_Confirm_Action;

   function Selection_Action
     (Direction : Guikit.Input.Navigation_Direction)
      return Input_Action is
   begin
      return
        (Kind            => Selection_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Direction,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Selection_Action;

   function Scroll_Action
     (Target : Scroll_Target;
      Lines  : Integer;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind            => Scroll_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => (if Lines < 0 then Guikit.Input.Move_Up else Guikit.Input.Move_Down),
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => Lines,
         Scroll_Area     => Target,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Scroll_Action;

   function Scroll_Drag_Begin_Action
     (Target   : Scroll_Target;
      Anchor   : Integer;
      Activate : Boolean := False)
      return Input_Action is
   begin
      return
        (Kind             => Scrollbar_Drag_Begin_Input_Action,
         Command          => Files.Commands.No_Command,
         Direction        => Guikit.Input.Move_Down,
         Item_Index       => 0,
         Root_Index       => 0,
         Result_Index     => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines     => 0,
         Scroll_Area      => Target,
         Focus_Target     => Files.Types.Focus_None,
         Cursor_Position  => 0,
         Settings_Field   => 0,
         Settings_Option  => 0,
         Activate         => Activate,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => Anchor);
   end Scroll_Drag_Begin_Action;

   --  Build a details-header column-resize drag-begin action. The target column,
   --  the separator's origin x edge, and the column's effective width at drag
   --  start are packed into the shared Item_Index, Cursor_Position, and
   --  Scroll_Drag_Anchor fields (see the Input_Action record comment). The
   --  desktop shell owns the continuous drag, mirroring the scrollbar drag.
   --
   --  @param Column Optional detail column the drag resizes.
   --  @param Origin_X Separator's x edge at drag start.
   --  @param Origin_Width Column's effective width at drag start.
   --  @return Column-resize drag-begin input action.
   function Column_Resize_Begin_Action
     (Column       : Files.Types.Optional_Detail_Column;
      Origin_X     : Natural;
      Origin_Width : Natural)
      return Input_Action is
   begin
      return
        (Kind            => Column_Resize_Begin_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => Files.Types.Detail_Column'Pos (Column),
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => Origin_X,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => Origin_Width);
   end Column_Resize_Begin_Action;

   --  Build a details-header column-reorder drag-begin action. The dragged
   --  column and the press x are packed into Item_Index and Cursor_Position, and
   --  the column's sort command is carried in Command so the shell can fall back
   --  to a sort when the press ends without crossing the drag threshold. The
   --  desktop shell owns the continuous drag, mirroring the resize drag.
   --
   --  @param Column Optional detail column being dragged.
   --  @param Origin_X Pointer x when the press began.
   --  @param Sort_Command Sort command for a plain click on the column.
   --  @return Column-reorder drag-begin input action.
   function Column_Reorder_Begin_Action
     (Column       : Files.Types.Optional_Detail_Column;
      Origin_X     : Natural;
      Sort_Command : Files.Commands.Command_Id)
      return Input_Action is
   begin
      return
        (Kind            => Column_Reorder_Begin_Input_Action,
         Command         => Sort_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => Files.Types.Detail_Column'Pos (Column),
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => Origin_X,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => False,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Column_Reorder_Begin_Action;

   --  Build a marquee (rubber-band) drag-begin action. The press-point origin is
   --  packed into Cursor_Position (x) and Settings_Field (y), and Additive (Ctrl
   --  or Shift held at press) rides in Toggle_Selection. The desktop shell owns
   --  the continuous drag, mirroring the scrollbar and column drags.
   --
   --  @param Origin_X Press-point x coordinate in framebuffer pixels.
   --  @param Origin_Y Press-point y coordinate in framebuffer pixels.
   --  @param Additive True when the marquee unions with the prior selection.
   --  @return Marquee drag-begin input action.
   function Marquee_Begin_Action
     (Origin_X : Natural;
      Origin_Y : Natural;
      Additive : Boolean)
      return Input_Action is
   begin
      return
        (Kind            => Marquee_Begin_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => 0,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => Origin_X,
         Settings_Field  => Origin_Y,
         Settings_Option => 0,
         Activate        => False,
         Toggle_Selection => Additive,
         Range_Selection  => False,
         Scroll_Drag_Anchor => 0);
   end Marquee_Begin_Action;

   function Saturating_Negated_Triple (Value : Integer) return Integer is
   begin
      if Value = 0 then
         return 0;
      elsif Value > 0 then
         if Value > Integer'Last / 3 then
            return Integer'First;
         else
            return -(Value * 3);
         end if;
      elsif Value < Integer'First / 3 then
         return Integer'Last;
      else
         return (-Value) * 3;
      end if;
   end Saturating_Negated_Triple;

   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Input_Action
 is separate;

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
      return Input_Action
 is separate;

   function Translate_Scroll
     (Y_Offset : Integer)
      return Input_Action is
      Lines : constant Integer := Saturating_Negated_Triple (Y_Offset);
   begin
      if Y_Offset = 0 then
         return No_Action;
      end if;

      return Scroll_Action (Scroll_Auto, Lines);
   end Translate_Scroll;

   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive := 20)
      return Input_Action
 is separate;

end Files.Events;
