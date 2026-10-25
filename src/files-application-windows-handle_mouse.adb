separate (Files.Application.Windows)
   procedure Handle_Mouse
     (Runtime : in out Runtime_Window)
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
   begin
      if Runtime.Handle = null
        or else
          (Runtime.Handle.Pending_Left_Clicks = 0
           and then Runtime.Handle.Pending_Left_Releases = 0
           and then Runtime.Handle.Pending_Right_Clicks = 0)
      then
         return;
      end if;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      while Runtime.Handle.Pending_Right_Clicks > 0 loop
         Runtime.Handle.Pending_Right_Clicks := Runtime.Handle.Pending_Right_Clicks - 1;
         Refresh_Snapshot (Runtime);
         declare
            X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Snapshot : Files.Rendering.View_Snapshot renames Runtime.Snapshots (Runtime.Current_Slot);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H),
                 Cell_Height_For (Runtime.Font_Pixel_Size));
            Item_Layout : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout
                (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size));
            In_Main : constant Boolean :=
              X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
              and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
            Item_Index : constant Natural :=
              (if In_Main then Files.Rendering.Hit.Item_At (Item_Layout, X, Y) else 0);
            In_Details_Header : constant Boolean :=
              Files.Rendering.Hit.Details_Header_Cell_At
                (Snapshot, Layout, X, Y, Cell_Height_For (Runtime.Font_Pixel_Size)).Present;
            Result : Files.Interaction.Interaction_Result;
         begin
            --  Scale_Coordinate deliberately returns the framebuffer extent for
            --  a cursor on/beyond the bottom or right edge. Such a coordinate
            --  names no pixel and must not close or replace a context menu.
            if Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H)
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
                  In_Details_Header => In_Details_Header);
               Apply_Interaction_Result (Runtime, Result);
            end if;
         end;
      end loop;

      while Runtime.Handle.Pending_Left_Clicks > 0 loop
         Runtime.Handle.Pending_Left_Clicks := Runtime.Handle.Pending_Left_Clicks - 1;

         if Files.Model.Context_Menu_Is_Open (Runtime.Model) then
            Refresh_Snapshot (Runtime);
            declare
               X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
               Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
               Snapshot : Files.Rendering.View_Snapshot renames Runtime.Snapshots (Runtime.Current_Slot);
               Menu     : constant Files.Rendering.Context_Menu_Layout :=
                 Files.Rendering.Calculate_Context_Menu_Layout
                   (Snapshot, Natural (Frame_W), Natural (Frame_H),
                    Cell_Height_For (Runtime.Font_Pixel_Size));
               Row      : constant Natural := Files.Rendering.Hit.Context_Menu_Row_At (Menu, X, Y);
               Modifiers : constant Guikit.Input.Modifier_Set :=
                 To_Modifiers (As_Window (Runtime.Handle));
               Command  : constant Files.Commands.Command_Id :=
                 (if Row > 0 and then Row <= Menu.Row_Count then Menu.Commands (Row)
                  else Files.Commands.No_Command);
               Result   : Files.Interaction.Interaction_Result;
            begin
               if Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H)
                 and then Frame_W > 0 and then Frame_H > 0
                 and then X < Natural (Frame_W) and then Y < Natural (Frame_H)
               then
                  Files.Interaction.Apply_Context_Menu_Command
                    (Model             => Runtime.Model,
                     Settings          => Runtime.Settings,
                     Settings_Path     => To_String (Runtime.Settings_Path),
                     Command           => Command,
                     Current_Font_Size => Runtime.Font_Pixel_Size,
                     Modifiers         => Modifiers,
                     Result            => Result);
                  Apply_Interaction_Result (Runtime, Result);
               end if;
            end;
            goto Continue_Left_Click_Loop;
         end if;

         declare
            Now       : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
            Modifiers : constant Guikit.Input.Modifier_Set := To_Modifiers (As_Window (Runtime.Handle));
            --  Hit-test where the button went down, not where the cursor is
            --  by the time a slow frame gets to the press.
            Action    : constant Files.Events.Input_Action :=
              Current_Click_Action
                (Runtime, Window_W, Window_H, Frame_W, Frame_H,
                 Runtime.Handle.Drag_Start_X, Runtime.Handle.Drag_Start_Y, Modifiers);
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
               Runtime.Deferred_Modifiers := Modifiers;
            else
               Dispatch_Click_Action (Runtime, Action, Modifiers);
            end if;
         end;

         <<Continue_Left_Click_Loop>>
         null;
      end loop;

      while Runtime.Handle.Pending_Left_Releases > 0 loop
         Runtime.Handle.Pending_Left_Releases := Runtime.Handle.Pending_Left_Releases - 1;

         if Runtime.Handle.Drag_Moved and then Runtime.Drag_Source_Index /= 0 then
            declare
               Modifiers : constant Guikit.Input.Modifier_Set := To_Modifiers (As_Window (Runtime.Handle));
               Action    : constant Files.Events.Input_Action :=
                 Current_Click_Action
                   (Runtime, Window_W, Window_H, Frame_W, Frame_H, Cursor_X, Cursor_Y, Modifiers);
            begin
               if Action.Kind = Files.Events.Item_Click_Input_Action
                 and then Action.Item_Index /= Runtime.Drag_Source_Index
               then
                  Handle_Item_Drop (Runtime, Action.Item_Index, Modifiers);
               end if;
            end;
         end if;

         if Runtime.Deferred_Click_Pending and then not Runtime.Handle.Drag_Moved then
            Dispatch_Click_Action (Runtime, Runtime.Deferred_Click, Runtime.Deferred_Modifiers);
         end if;
         Runtime.Deferred_Click_Pending := False;
         Runtime.Drag_Source_Index := 0;
         Runtime.Handle.Drag_Moved := False;
      end loop;
   end Handle_Mouse;
