separate (Files.Application.Windows)
   procedure Handle_Mouse
     (Runtime : in out Runtime_Window)
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;

      --  A right press: the context menu for what lies where it went down.
      procedure Right_Press (Event : Files.Mouse_Buttons.Button_Event) is
      begin
         declare
            Press_X  : constant Glfw.Input.Mouse.Coordinate := Event.X;
            Press_Y  : constant Glfw.Input.Mouse.Coordinate := Event.Y;
            X        : constant Natural := Scale_Coordinate (Press_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Press_Y, Window_H, Frame_H);
            Slot     : constant Snapshot_Slot := Hit_Slot (Runtime);
            Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Slot);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H),
                 Cell_Height_For (Runtime.Font_Pixel_Size));
            Item_Layout : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout
                (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size));
            Menu : constant Files.Rendering.Context_Menu_Layout :=
              Files.Rendering.Calculate_Context_Menu_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H), Cell_Height_For (Runtime.Font_Pixel_Size));
            --  The menu is drawn over the view: the item beneath it is not
            --  what a right-click on it meant.
            On_Menu : constant Boolean :=
              Menu.Visible
              and then X >= Menu.X and then X - Menu.X < Menu.Width
              and then Y >= Menu.Y and then Y - Menu.Y < Menu.Height;
            In_Main : constant Boolean :=
              not On_Menu
              and then Files.Rendering.Hit.On_Main_View (Layout, X, Y);
            Item_Index : constant Natural :=
              (if In_Main
               then Current_Item_Index (Runtime, Slot, Files.Rendering.Hit.Item_At (Item_Layout, X, Y))
               else 0);
            In_Details_Header : constant Boolean :=
              In_Main
              and then Files.Rendering.Hit.Details_Header_Cell_At
                (Snapshot, Layout, X, Y, Cell_Height_For (Runtime.Font_Pixel_Size)).Present;
            Result : Files.Interaction.Interaction_Result;
         begin
            --  Scale_Coordinate deliberately returns the framebuffer extent for
            --  a cursor on/beyond the bottom or right edge. Such a coordinate
            --  names no pixel and must not close or replace a context menu.
            if Cursor_Is_Inside_Window (Press_X, Press_Y, Window_W, Window_H)
              and then Frame_W > 0 and then Frame_H > 0
              and then X < Natural (Frame_W) and then Y < Natural (Frame_H)
            then
               Files.Interaction.Apply_Right_Click
                 (Model             => Runtime.Model,
                  Settings          => Runtime.Settings,
                  In_Main           => In_Main,
                  Item_Index        => Item_Index,
                  X                 => X,
                  Y                 => Y,
                  Result            => Result,
                  In_Details_Header => In_Details_Header,
                  On_Context_Menu   => On_Menu);
               Apply_Interaction_Result (Runtime, Result);
            end if;
         end;
      end Right_Press;

      --  A left press: a click where the button went down, with the
      --  modifiers held then.
      procedure Left_Press (Event : Files.Mouse_Buttons.Button_Event) is
      begin
         if Files.Model.Context_Menu_Is_Open (Runtime.Model) then
            declare
               --  Where the button went down, as for any other click.
               Press_X  : constant Glfw.Input.Mouse.Coordinate := Event.X;
               Press_Y  : constant Glfw.Input.Mouse.Coordinate := Event.Y;
               X        : constant Natural := Scale_Coordinate (Press_X, Window_W, Frame_W);
               Y        : constant Natural := Scale_Coordinate (Press_Y, Window_H, Frame_H);
               Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Hit_Slot (Runtime));
               Menu     : constant Files.Rendering.Context_Menu_Layout :=
                 Files.Rendering.Calculate_Context_Menu_Layout
                   (Snapshot, Natural (Frame_W), Natural (Frame_H),
                    Cell_Height_For (Runtime.Font_Pixel_Size));
               Row      : constant Natural := Files.Rendering.Hit.Context_Menu_Row_At (Menu, X, Y);
               Modifiers : constant Guikit.Input.Modifier_Set := Event.Modifiers;
               Command  : constant Files.Commands.Command_Id :=
                 (if Row > 0 and then Row <= Menu.Row_Count then Menu.Rows (Row).Command
                  else Files.Commands.No_Command);
               Result   : Files.Interaction.Interaction_Result;
            begin
               if Cursor_Is_Inside_Window (Press_X, Press_Y, Window_W, Window_H)
                 and then Frame_W > 0 and then Frame_H > 0
                 and then X < Natural (Frame_W) and then Y < Natural (Frame_H)
               then
                  Files.Interaction.Apply_Context_Menu_Command
                    (Model             => Runtime.Model,
                     Settings          => Runtime.Settings,
                     Settings_Path     => To_String (Runtime.Settings_Path),
                     Command           => Command,
                     Modifiers         => Modifiers,
                     Result            => Result);
                  Apply_Interaction_Result (Runtime, Result);
               end if;
            end;
            return;
         end if;

         declare
            Now       : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
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
              and then Files.Model.Is_Selected (Runtime.Model, Positive (Action.Item_Index))
              and then (Files.Model.Selected_Count (Runtime.Model) > 1 or else Modifiers (Guikit.Input.Control_Key))
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
      procedure Left_Release (Event : Files.Mouse_Buttons.Button_Event) is
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
                  Handle_Item_Drop (Runtime, Action.Item_Index, Modifiers);
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
      --  release between two presses, is handled where it happened.
      while Runtime.Handle /= null and then not Runtime.Handle.Pending_Mouse.Is_Empty loop
         declare
            Event : constant Files.Mouse_Buttons.Button_Event := Runtime.Handle.Pending_Mouse.First_Element;
         begin
            Runtime.Handle.Pending_Mouse.Delete_First;
            case Event.Button is
               when Files.Mouse_Buttons.Right_Mouse_Button =>
                  Right_Press (Event);
               when Files.Mouse_Buttons.Left_Mouse_Button =>
                  if Event.Pressed then
                     Left_Press (Event);
                  else
                     Left_Release (Event);
                  end if;
            end case;
         end;
      end loop;
   end Handle_Mouse;
