separate (Files.Application.Windows)
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window)
   is
      Events   : Input_Event_Vectors.Vector;
      Consumed : Boolean := False;
      Selected_Before : Natural := 0;
      Path_Before     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      Save_Held_Settings (Runtime, Force => False);
      --  This runs on every pass of the loop; with no key event nothing
      --  below can happen, and Selected_Index walks the items.
      if Runtime.Handle.Pending_Input.Is_Empty then
         return;
      end if;
      Selected_Before := Files.Model.Selection.Selected_Index (Runtime.Model);
      Path_Before := To_Unbounded_String (Files.Model.Current_Path (Runtime.Model));
      Events := Runtime.Handle.Pending_Input;
      Runtime.Handle.Pending_Input.Clear;
      Runtime.Handle.Last_Was_Tracked_Press := False;
      Runtime.Handle.Drop_Next_Character := False;

      for Event of Events loop
         --  A key that navigated (or reloaded) replaced the items; the next
         --  one queued in this batch walks them in the drawn group order.
         Files.Controller.Sync_Grouping (Runtime.Model, Runtime.Settings);
         case Event.Kind is
            when Key_Press_Event =>
               --  With the traces below a presented frame, CI follows a key
               --  it sends through the loop to what it did (the selection
               --  it moved, selected=<before>-><after>) and onto the screen.
               Files.Diagnostics.Trace ("Files.Application.Windows", "key=" & Guikit.Input.Key_Code'Image (Event.Key));
               declare
                  Key_Selected_Before : constant Natural := Files.Model.Selection.Selected_Index (Runtime.Model);
               begin
                  --  Any other key comes after what the held one changed is
                  --  saved: Escape must not close the pane over it.
                  if Event.Repeated then
                     Runtime.Settings_Repeat_At := Ada.Real_Time.Clock;
                  else
                     Save_Held_Settings (Runtime, Force => True);
                  end if;
                  Fire_Key (Runtime, Event.Key, Event.Modifiers, Consumed, Repeated => Event.Repeated);
                  Files.Diagnostics.Trace
                    ("Files.Application.Windows",
                     "selected=" & Files.Text_Basics.Natural_Text (Key_Selected_Before) & "->"
                     & Files.Text_Basics.Natural_Text (Files.Model.Selection.Selected_Index (Runtime.Model)));
               end;
            when Text_Event =>
               if not (Event.Parallel and then Consumed) then
                  Dispatch_Text (Runtime, To_String (Event.Text));
               end if;
               Consumed := False;
         end case;
      end loop;

      --  The selection follows the keyboard into view.
      if Runtime.Handle /= null
        and then (Files.Model.Selection.Selected_Index (Runtime.Model) /= Selected_Before
                  or else Files.Model.Current_Path (Runtime.Model) /= To_String (Path_Before)
                  or else Files.Model.Reveal_Is_Pending (Runtime.Model))
      then
         Reveal_Selection (Runtime);
      end if;
   end Handle_Keyboard;
