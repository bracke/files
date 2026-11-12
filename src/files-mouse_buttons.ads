with Ada.Containers.Vectors;
with Ada.Real_Time;
with Glfw.Input.Mouse;
with Guikit.Input;

--  Mouse button changes in arrival order, as a window's callback sees them.
--
--  Kept as counters, the presses lost their order and their place: every
--  right click ran before every left one, every left press was hit-tested
--  where the last one went down, and the modifiers were read when the queue
--  drained rather than when the button moved. Each change is queued here with
--  where it happened and the modifiers held then, and the window drains the
--  queue in order, as it drains its keyboard events.
package Files.Mouse_Buttons is

   --  The buttons the window acts on.
   type Button_Kind is (Left_Mouse_Button, Right_Mouse_Button);

   --  One button change.
   type Button_Event is record
      Button    : Button_Kind := Left_Mouse_Button;
      --  True for a press, False for a release.
      Pressed   : Boolean := True;
      --  The cursor, in window coordinates, when the button changed.
      X         : Glfw.Input.Mouse.Coordinate := 0.0;
      Y         : Glfw.Input.Mouse.Coordinate := 0.0;
      --  Modifiers held when the button changed, not when the queue drains.
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      --  A release only: whether the press it ends had become a drag.
      Dragged   : Boolean := False;
   end record;

   --  A queue of button changes, oldest first.
   package Button_Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Button_Event);

   --  How many changes wait at most; later ones are dropped until the window
   --  drains the queue.
   Max_Pending_Events : constant := 32;

   --  A left press landing within this window of the previous accepted press is
   --  treated as a hardware/compositor bounce and dropped. It is far shorter than
   --  any deliberate click or double-click (the double-click threshold is 0.5s),
   --  so it never rejects a real one, but it absorbs the microsecond-apart phantom
   --  presses a failing switch produces.
   Left_Press_Debounce : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (40);

   --  Queue one button change. A left press within Left_Press_Debounce of the
   --  last accepted one is a bounce: it is dropped, and so is the bounce's own
   --  release still waiting in Queue -- left in place it would end a drag that
   --  is still being held.
   --  @param Queue Changes waiting for the window, oldest first.
   --  @param Last_Left_Press When the last accepted left press happened.
   --  @param Event The change.
   --  @param Now When it happened.
   --  @param Bounced True when Event was a left press dropped as a bounce.
   procedure Queue_Event
     (Queue           : in out Button_Event_Vectors.Vector;
      Last_Left_Press : in out Ada.Real_Time.Time;
      Event           : Button_Event;
      Now             : Ada.Real_Time.Time;
      Bounced         : out Boolean);

end Files.Mouse_Buttons;
