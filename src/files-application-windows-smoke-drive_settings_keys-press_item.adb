separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Press_Item (Visible_Index : Positive) is
      Window_W, Window_H, Frame_W, Frame_H : Glfw.Size := 0;
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
   begin
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Layouts.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
      begin
         for Cell of Files.Rendering.Layouts.Calculate_Item_Layout (Snapshot, Layout, Line_Height) loop
            if Cell.Visible_Index = Visible_Index and then Cell.Height > 0 and then Frame_W > 0 then
               Runtime.Handle.Drag_Start_X :=
                 Glfw.Input.Mouse.Coordinate
                   (Float (Cell.X + Cell.Width / 2) * Float (Window_W) / Float (Frame_W));
               Runtime.Handle.Drag_Start_Y :=
                 Glfw.Input.Mouse.Coordinate
                   (Float (Cell.Y + Cell.Height / 2) * Float (Window_H) / Float (Frame_H));
               Runtime.Handle.Pending_Mouse.Append
                 (Guikit.Input.Mouse_Buttons.Button_Event'
                    (Button    => Guikit.Input.Mouse_Buttons.Left_Mouse_Button,
                     Pressed   => True,
                     X         => Runtime.Handle.Drag_Start_X,
                     Y         => Runtime.Handle.Drag_Start_Y,
                     Modifiers => Guikit.Input.No_Modifiers,
                     Dragged   => False,
                     At_Time   => Ada.Real_Time.Clock));
               Runtime.Handle.Drag_Moved := False;
               Handle_Mouse (Runtime);
               exit;
            end if;
         end loop;
      end;
   end Press_Item;
