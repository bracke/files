with Ada.Strings.Unbounded;

with Guikit.Layout;
with Files.Rendering.Hit;
with Files.UI;
with Guikit.Utf8;

package body Files.Events is

   --  Translate a vertical scroll-wheel offset into an internal input action.
   --
   --  @param Y_Offset Positive GLFW-style wheel offsets scroll up; negative values scroll down.
   --  @return Internal scroll input action or no action when the offset is zero.
   function Translate_Scroll
     (Y_Offset : Integer)
      return Input_Action;

   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;

   function No_Action return Input_Action is (Kind => No_Input_Action);

   function Command_Action
     (Command : Files.Commands.Command_Id)
      return Input_Action is
   begin
      return
        (Kind    => Command_Input_Action,
         Command => Command);
   end Command_Action;

   function Conflict_Action
     (Button : Conflict_Button_Kind)
      return Input_Action is
   begin
      return
        (Kind            => Conflict_Click_Input_Action,
         Conflict_Button => Button);
   end Conflict_Action;

   function Paste_Cancel_Action return Input_Action is (Kind => Paste_Cancel_Input_Action);

   --  Build a label-picker swatch-choice action (No_Label clears the label).
   function Label_Choice_Action
     (Label : Files.Types.Color_Label)
      return Input_Action is
   begin
      return
        (Kind  => Label_Picker_Choice_Input_Action,
         Label => Label);
   end Label_Choice_Action;

   function Tree_Pick_Confirm_Action return Input_Action is (Kind => Tree_Pick_Confirm_Input_Action);

   function Scroll_Action
     (Target : Scroll_Target;
      Lines  : Integer)
      return Input_Action is
   begin
      return
        (Kind         => Scroll_Input_Action,
         Scroll_Lines => Lines,
         Scroll_Area  => Target,
         others       => <>);
   end Scroll_Action;

   function Scroll_Drag_Begin_Action
     (Target   : Scroll_Target;
      Anchor   : Integer)
      return Input_Action is
   begin
      return
        (Kind               => Scrollbar_Drag_Begin_Input_Action,
         Scroll_Area        => Target,
         Scroll_Drag_Anchor => Anchor,
         others             => <>);
   end Scroll_Drag_Begin_Action;

   --  The exact scroll adjustment for one paged step (a wheel notch or a
   --  scrollbar track click) of a region whose offset is bounded by Maximum.
   --  Raw can exceed Maximum after a resize; the adjustment folds that stale
   --  excess in, so a step can neither preserve nor be consumed by an
   --  invisible part of an old, smaller viewport.
   --
   --  @param Raw Region's stored scroll offset, possibly stale.
   --  @param Maximum Largest offset the region can take now.
   --  @param Step Offset units one step moves.
   --  @param Up True to step towards the top, False towards the bottom.
   --  @return Signed adjustment to apply to Raw; zero when nothing moves.
   function Paged_Adjustment
     (Raw     : Natural;
      Maximum : Natural;
      Step    : Natural;
      Up      : Boolean)
      return Integer
   is
      Current   : constant Natural := Natural'Min (Raw, Maximum);
      Requested : constant Natural :=
        (if Up
         then (if Step >= Current then 0 else Current - Step)
         elsif Step >= Maximum - Current then Maximum
         else Current + Step);
   begin
      return Integer (Requested) - Integer (Raw);
   end Paged_Adjustment;

   --  Build a details-header column-resize drag-begin action: the target
   --  column, the separator's x edge, and the column's width at drag start.
   --  The desktop shell owns the continuous drag, mirroring the scrollbar drag.
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
        (Kind         => Column_Resize_Begin_Input_Action,
         Column       => Column,
         Origin_X     => Origin_X,
         Column_Width => Origin_Width,
         others       => <>);
   end Column_Resize_Begin_Action;

   --  Build a details-header column-reorder drag-begin action. The dragged
   --  column and the press x go in Column and Origin_X, and the column's sort
   --  command in Sort_Command so the shell can fall back
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
        (Kind         => Column_Reorder_Begin_Input_Action,
         Sort_Command => Sort_Command,
         Column       => Column,
         Origin_X     => Origin_X,
         others       => <>);
   end Column_Reorder_Begin_Action;

   --  Build a marquee (rubber-band) drag-begin action from the press point and
   --  whether it adds to the selection (Ctrl or Shift held at press). The desktop shell owns
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
        (Kind     => Marquee_Begin_Input_Action,
         Origin_X => Origin_X,
         Origin_Y => Origin_Y,
         Additive => Additive,
         others   => <>);
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
      Line_Height : Positive)
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
      Line_Height : Positive)
      return Input_Action
 is separate;

end Files.Events;
