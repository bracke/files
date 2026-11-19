separate (Files.Application.Windows)
   procedure Handle_Mouse
     (Runtime : in out Runtime_Window)
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;

      --  A right press: the context menu for what lies where it went down.
      --  Files.Events translates it against the snapshot on screen; an item
      --  drawn there is found again in the model as it is now.
      procedure Right_Press (Event : Guikit.Input.Mouse_Buttons.Button_Event) is
      begin
         --  Scale_Coordinate deliberately returns the framebuffer extent for
         --  a cursor on/beyond the bottom or right edge. Such a coordinate
         --  names no pixel and must not close or replace a context menu.
         if not Files.Window_Policy.Cursor_Is_Inside_Window (Event.X, Event.Y, Window_W, Window_H)
           or else Frame_W <= 0 or else Frame_H <= 0
         then
            return;
         end if;
         declare
            Slot   : constant Snapshot_Slot := Hit_Slot (Runtime);
            Action : Files.Events.Input_Action :=
              Files.Events.Translate_Right_Click
                (Snapshot    => Runtime.View.Snapshots (Slot),
                 X           => Files.Window_Policy.Scale_X (Event.X, Window_W, Frame_W),
                 Y           => Files.Window_Policy.Scale_Coordinate (Event.Y, Window_H, Frame_H),
                 Width       => Natural (Frame_W),
                 Height      => Natural (Frame_H),
                 Line_Height => Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size));
         begin
            if Action.Kind = Files.Events.Right_Click_Input_Action then
               Action.Target_Item := Current_Item_Index (Runtime, Slot, Action.Target_Item);
               Dispatch_Click_Action (Runtime, Action, Event.Modifiers);
            end if;
         end;
      end Right_Press;

      --  A left press: a click where the button went down, with the
      --  modifiers held then. Files.Events translates it, an open context
      --  menu's rows included.
      procedure Left_Press (Event : Guikit.Input.Mouse_Buttons.Button_Event) is
      begin
         declare
            --  When the button went down, not when this pass got to it: a
            --  slow frame between two clicks does not split a double click.
            Now       : constant Ada.Real_Time.Time := Event.At_Time;
            Modifiers : constant Guikit.Input.Modifier_Set := Event.Modifiers;
            --  Hit-test where the button went down, not where the cursor is
            --  (or where a later press was) by the time a slow frame gets to it.
            Action    : constant Files.Events.Input_Action :=
              Current_Click_Action
                (Runtime, Window_W, Window_H, Frame_W, Frame_H,
                 Event.X, Event.Y, Modifiers);
            Is_Item   : constant Boolean :=
              Action.Kind = Files.Events.Item_Click_Input_Action
              and then Action.Item_Index in 1 .. Files.Model.Visible_Count (Runtime.Model);
            Path      : constant String :=
              (if Is_Item
               then To_String (Files.Model.Visible_Item (Runtime.Model, Action.Item_Index).Full_Path)
               else "");
            --  A double click is two clicks on the same file: the same row of
            --  a listing reordered in between, or of the folder the first
            --  click opened, is not.
            Activate  : constant Boolean :=
              Is_Item
              and then Action.Item_Index = Runtime.Last_Click_Item
              and then Path = To_String (Runtime.Last_Click_Path)
              and then Now <= Runtime.Last_Click_Time + Double_Click_Interval;
         begin
            Runtime.Press_X := Files.Window_Policy.Scale_X (Event.X, Window_W, Frame_W);
            Runtime.Press_Y := Files.Window_Policy.Scale_Coordinate (Event.Y, Window_H, Frame_H);
            Runtime.Deferred_Click_Pending := False;
            if Is_Item and then not Activate then
               Runtime.Last_Click_Item := Action.Item_Index;
               Runtime.Last_Click_Path := To_Unbounded_String (Path);
               Runtime.Last_Click_Time := Now;
               Runtime.Drag_Source_Index := Action.Item_Index;
            else
               --  A double click is spent: a third click starts over.
               Runtime.Last_Click_Item := 0;
               Runtime.Last_Click_Path := Null_Unbounded_String;
               Runtime.Drag_Source_Index := (if Is_Item then Action.Item_Index else 0);
            end if;

            if Activate then
               declare
                  Activated_Action : Files.Events.Input_Action := Action;
               begin
                  Activated_Action.Activate := True;
                  Dispatch_Click_Action (Runtime, Activated_Action, Modifiers);
               end;
            elsif Is_Item
              and then not Modifiers (Guikit.Input.Shift_Key)
              and then Files.Model.Selection.Is_Selected (Runtime.Model, Positive (Action.Item_Index))
              and then (Files.Model.Selection.Selected_Count (Runtime.Model) > 1
                        or else Modifiers (Guikit.Input.Control_Key))
            then
               --  A press on part of the selection may start dragging all of
               --  it: only a release without a drag selects just this item
               --  (or, with Ctrl, toggles it).
               Runtime.Deferred_Click_Pending := True;
               Runtime.Deferred_Click := Action;
               Runtime.Deferred_Click_Path := To_Unbounded_String (Path);
               Runtime.Deferred_Modifiers := Modifiers;
            else
               Dispatch_Click_Action (Runtime, Action, Modifiers);
            end if;
         end;
      end Left_Press;

      --  A left release: the end of a drag (a drop) or of a deferred click.
      procedure Left_Release (Event : Guikit.Input.Mouse_Buttons.Button_Event) is
      begin
         if Event.Dragged and then Runtime.Drag_Source_Index /= 0 then
            declare
               Modifiers : constant Guikit.Input.Modifier_Set := Event.Modifiers;
               Action    : constant Files.Events.Input_Action :=
                 Current_Click_Action
                   (Runtime, Window_W, Window_H, Frame_W, Frame_H, Event.X, Event.Y, Modifiers);
            begin
               if Action.Kind = Files.Events.Item_Click_Input_Action
                 and then Action.Item_Index /= Runtime.Drag_Source_Index
               then
                  Dispatch_Click_Action
                    (Runtime, (Kind => Files.Events.Item_Drop_Input_Action, Drop_Target => Action.Item_Index),
                     Modifiers);
               end if;
            end;
         end if;

         if Runtime.Deferred_Click_Pending and then not Event.Dragged then
            declare
               Index : constant Natural :=
                 Files.Model.Visible_Index_Of (Runtime.Model, To_String (Runtime.Deferred_Click_Path));
               Click : Files.Events.Input_Action := Runtime.Deferred_Click;
            begin
               --  Gone since the press: the click has nothing left to act on.
               if Index > 0 then
                  Click.Item_Index := Index;
                  Dispatch_Click_Action (Runtime, Click, Runtime.Deferred_Modifiers);
               end if;
            end;
         end if;
         Runtime.Deferred_Click_Pending := False;
         Runtime.Drag_Source_Index := 0;
         --  The drag this release ended is over, unless the button is down
         --  again already: a later press reset the flag for its own drag.
         if not Runtime.Handle.Left_Mouse_Down then
            Runtime.Handle.Drag_Moved := False;
         end if;
      end Left_Release;
   begin
      if Runtime.Handle = null or else Runtime.Handle.Pending_Mouse.Is_Empty then
         return;
      end if;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);

      --  In arrival order: a right click between two left clicks, or a
      --  release between two presses, is handled where it happened. A left
      --  release still inside its debounce window stays queued, with all
      --  after it, so a bounce press can withdraw it; a later pass, woken
      --  by Mouse_Buttons.Ready_At, takes it.
      while Runtime.Handle /= null loop
         declare
            Event : Guikit.Input.Mouse_Buttons.Button_Event;
            Taken : Boolean;
         begin
            Guikit.Input.Mouse_Buttons.Next_Ready (Runtime.Handle.Pending_Mouse, Ada.Real_Time.Clock, Event, Taken);
            exit when not Taken;
            case Event.Button is
               when Guikit.Input.Mouse_Buttons.Right_Mouse_Button =>
                  Right_Press (Event);
               when Guikit.Input.Mouse_Buttons.Left_Mouse_Button =>
                  if Event.Pressed then
                     Left_Press (Event);
                  else
                     Left_Release (Event);
                  end if;
            end case;
         end;
      end loop;
      --  A command a click ran (a menu's Open Containing Folder) may have
      --  selected an item by name: it comes into view.
      Reveal_Pending_Selection (Runtime);
   end Handle_Mouse;
