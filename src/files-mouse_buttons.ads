with Ada.Real_Time;
with Guikit.Input.Mouse_Buttons;

--  Mouse button changes in arrival order, as a window's callback sees them.
--
--  The queue, the press debounce and the double-click interval are guikit's
--  (Guikit.Input.Mouse_Buttons), shared with every guikit application; these
--  are the names the file manager's window and tests use for them.
package Files.Mouse_Buttons is

   package Shared renames Guikit.Input.Mouse_Buttons;

   --  The buttons the window acts on.
   subtype Button_Kind is Shared.Button_Kind;

   --  The left button.
   --
   --  @return The left-button value.
   function Left_Mouse_Button return Button_Kind renames Shared.Left_Mouse_Button;

   --  The right button.
   --
   --  @return The right-button value.
   function Right_Mouse_Button return Button_Kind renames Shared.Right_Mouse_Button;

   --  Whether two buttons are the same (visible wherever this package is used).
   --
   --  @param Left A button.
   --  @param Right Another button.
   --  @return True when they are the same button.
   function "=" (Left, Right : Button_Kind) return Boolean renames Shared."=";

   --  One button change.
   subtype Button_Event is Shared.Button_Event;

   --  A queue of button changes, oldest first.
   package Button_Event_Vectors renames Shared.Button_Event_Vectors;

   --  How many changes wait at most.
   Max_Pending_Events : constant := Shared.Max_Pending_Events;

   --  The left-press bounce window.
   Left_Press_Debounce : Ada.Real_Time.Time_Span renames Shared.Left_Press_Debounce;

   --  Two clicks on the same item at most this far apart activate it.
   Double_Click_Interval : Ada.Real_Time.Time_Span renames Shared.Double_Click_Interval;

   --  Queue one button change (see Guikit.Input.Mouse_Buttons.Queue_Event).
   --
   --  @param Queue Changes waiting for the window, oldest first.
   --  @param Last_Left_Press When the last accepted left press happened.
   --  @param Event The change.
   --  @param Bounced True when Event was a left press dropped as a bounce.
   procedure Queue_Event
     (Queue           : in out Button_Event_Vectors.Vector;
      Last_Left_Press : in out Ada.Real_Time.Time;
      Event           : Button_Event;
      Bounced         : out Boolean)
     renames Shared.Queue_Event;

   --  Take the oldest change ready at Now (see
   --  Guikit.Input.Mouse_Buttons.Next_Ready).
   --
   --  @param Queue Changes waiting for the window, oldest first.
   --  @param Now When the window drains the queue.
   --  @param Event The change taken, when Taken.
   --  @param Taken True when a change was taken off Queue.
   procedure Next_Ready
     (Queue : in out Button_Event_Vectors.Vector;
      Now   : Ada.Real_Time.Time;
      Event : out Button_Event;
      Taken : out Boolean)
     renames Shared.Next_Ready;

   --  When the oldest change may be handled (see
   --  Guikit.Input.Mouse_Buttons.Ready_At).
   --
   --  @param Queue Changes waiting for the window, oldest first.
   --  @return When Next_Ready will take the oldest change.
   function Ready_At (Queue : Button_Event_Vectors.Vector) return Ada.Real_Time.Time
     renames Shared.Ready_At;

end Files.Mouse_Buttons;
