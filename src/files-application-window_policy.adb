with Files.Events;
with Files.Commands;
with Files.Timing;
with Guikit.Mirroring;
with Guikit.Utf8;

package body Files.Application.Window_Policy is

   use type Files.Commands.Command_Id;
   use type Files.Input_Actions.Input_Action_Kind;
   use type Files.UI_Types.Focus_Target;
   use type Glfw.Input.Mouse.Coordinate;
   use type Glfw.Size;

   function Accumulate_Scroll_Offset
     (Remainder : in out Long_Float;
      Offset    : Long_Float)
      return Integer
   is
      Whole_Float : Long_Float := 0.0;
      Whole       : Integer := 0;
   begin
      --  Native input is not trusted to contain a finite IEEE value. A NaN
      --  compares false to every bound and, if retained, would poison every
      --  later scroll event for this window.
      if Remainder /= Remainder or else Offset /= Offset then
         Remainder := 0.0;
         return 0;
      end if;

      declare
         Total : constant Long_Float := Remainder + Offset;
      begin
         if Total >= Long_Float (Integer'Last) then
            Remainder := 0.0;
            return Integer'Last;
         elsif Total <= Long_Float (Integer'First) then
            Remainder := 0.0;
            return Integer'First;
         elsif Total >= 1.0 then
            Whole_Float := Long_Float'Floor (Total);
         elsif Total <= -1.0 then
            Whole_Float := Long_Float'Ceiling (Total);
         else
            Remainder := Total;
            return 0;
         end if;

         Whole := Integer (Whole_Float);
         Remainder := Total - Long_Float (Whole);
         return Whole;
      end;
   end Accumulate_Scroll_Offset;

   function Add_Pending_Scroll
     (Current : Integer;
      Change  : Integer)
      return Integer is
   begin
      if Change > 0 and then Current > Integer'Last - Change then
         return Integer'Last;
      elsif Change < 0 and then Current < Integer'First - Change then
         return Integer'First;
      else
         return Current + Change;
      end if;
   end Add_Pending_Scroll;

   function Text_Input_Bytes
     (Char : Wide_Wide_Character)
      return String
   is
      Code : constant Natural := Wide_Wide_Character'Pos (Char);
   begin
      --  Drop control characters (text-input policy); Guikit.Utf8.Encode returns
      --  "" for surrogates and out-of-range values.
      if Code < Character'Pos (' ') then
         return "";
      end if;
      return Guikit.Utf8.Encode (Code);
   end Text_Input_Bytes;

   function Scale_Coordinate
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural is
   begin
      if Value <= 0.0 or else Source = 0 or else Target = 0 then
         return 0;
      end if;

      declare
         Scaled : constant Long_Float :=
           Long_Float (Value) * Long_Float (Target) / Long_Float (Source);
      begin
         if Scaled <= 0.0 then
            return 0;
         elsif Scaled >= Long_Float (Target) then
            return Natural (Target);
         else
            --  The pixel the point lies in: truncate, as the framebuffer's
            --  pixel grid does. A conversion would round, putting the right
            --  half of every pixel in the next one.
            return Natural (Long_Float'Floor (Scaled));
         end if;
      end;
   exception
      when Constraint_Error =>
         return 0;
   end Scale_Coordinate;

   function Scale_X
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural
   is
      Scaled : constant Natural := Scale_Coordinate (Value, Source, Target);
   begin
      if not Guikit.Mirroring.Mirrored_Layout or else Target <= 0 then
         return Scaled;
      end if;
      return Guikit.Mirroring.Mirror_X (Scaled, Natural (Target));
   end Scale_X;

   function Scrollbar_Drag_Offset
     (Thumb_Top    : Natural;
      Track_Length : Natural;
      Thumb_Length : Natural;
      Maximum      : Natural)
      return Natural
   is
      Travel  : constant Natural :=
        (if Track_Length > Thumb_Length then Track_Length - Thumb_Length else 0);
      Clamped : constant Natural := Natural'Min (Thumb_Top, Travel);
   begin
      if Travel = 0 or else Maximum = 0 then
         return 0;
      end if;

      return
        Natural
          (Long_Long_Integer (Clamped)
             * Long_Long_Integer (Maximum)
             / Long_Long_Integer (Travel));
   end Scrollbar_Drag_Offset;

   function Cursor_Is_Inside_Window
     (X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate;
      Width  : Glfw.Size;
      Height : Glfw.Size)
      return Boolean is
   begin
      return Width > 0
        and then Height > 0
        and then X >= 0.0
        and then Y >= 0.0
        and then X < Glfw.Input.Mouse.Coordinate (Width)
        and then Y < Glfw.Input.Mouse.Coordinate (Height);
   exception
      when Constraint_Error =>
         return False;
   end Cursor_Is_Inside_Window;

   function Unmirrored_Node_X (X, Width, Frame_Width : Natural) return Natural is
     (if Guikit.Mirroring.Mirrored_Layout and then X <= Frame_Width and then Width <= Frame_Width - X
      then Frame_Width - X - Width
      else X);

   function Accessibility_Action
     (Click    : Files.Input_Actions.Input_Action;
      Activate : Boolean)
      return Files.Input_Actions.Input_Action
   is
      Action : Files.Input_Actions.Input_Action := Click;
   begin
      if Activate and then Action.Kind = Files.Input_Actions.Item_Click_Input_Action then
         Action.Activate := True;
      elsif Action.Kind = Files.Input_Actions.Column_Reorder_Begin_Input_Action then
         Action :=
           (if Action.Sort_Command /= Files.Commands.No_Command
            then (Kind => Files.Input_Actions.Command_Input_Action, Command => Action.Sort_Command)
            else (Kind => Files.Input_Actions.No_Input_Action));
      end if;
      return Action;
   end Accessibility_Action;

   function Activation_Presses_Space
     (Activate : Boolean;
      Focus    : Files.UI_Types.Focus_Target;
      Field    : Guikit.Settings_Panel.Field_Kind)
      return Boolean is
     (Activate
      and then Focus = Files.UI_Types.Focus_Settings_Input
      and then Field in Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice);

   function Zoom_Save_Due
     (Unsaved   : Boolean;
      Force     : Boolean;
      Now       : Ada.Real_Time.Time;
      Zoomed_At : Ada.Real_Time.Time)
      return Boolean is
     (Unsaved and then (Force or else Files.Timing.Elapsed (Now, Zoomed_At, Zoom_Save_Delay)));

   function Field_Request
     (X, Y, Width, Height : Natural;
      Frame_Width         : Natural;
      Line_Height         : Positive)
      return Files.Input_Actions.Input_Action is
     (Files.Events.Translate_Field_Request
        (Unmirrored_Node_X (X, Width, Frame_Width), Y, Width, Height, Frame_Width, Line_Height));

end Files.Application.Window_Policy;
