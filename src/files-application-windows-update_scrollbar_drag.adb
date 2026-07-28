separate (Files.Application.Windows)
   procedure Update_Scrollbar_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
   is
      use type Files.Events.Scroll_Target;
      pragma Unreferenced (Cursor_X);
   begin
      if Runtime.Scrollbar_Drag_Target = Files.Events.Scroll_Auto then
         return;
      elsif not Mouse_Down
        or else Window_W = 0 or else Window_H = 0
        or else Frame_W = 0 or else Frame_H = 0
      then
         Runtime.Scrollbar_Drag_Target := Files.Events.Scroll_Auto;
         return;
      end if;

      declare
         Y_Frame      : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Line_Height  : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot     : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);

         procedure Apply_Drag
           (Track_Y     : Natural;
            Track_H     : Natural;
            Thumb_H     : Natural;
            Content_H   : Natural;
            View_H      : Natural;
            Apply_Lines : access procedure (Lines : Natural))
         is
            Drag_Range    : constant Integer := Integer'Max (0, Integer (Track_H) - Integer (Thumb_H));
            Max_Scroll_Px : constant Integer := Integer'Max (0, Integer (Content_H) - Integer (View_H));
            Wanted_Top    : constant Integer := Integer (Y_Frame) - Runtime.Scrollbar_Drag_Anchor;
            Rel_Y         : Integer := Wanted_Top - Integer (Track_Y);
            Scroll_Px     : Integer := 0;
         begin
            if Drag_Range <= 0 or else Max_Scroll_Px <= 0 then
               return;
            end if;
            if Rel_Y < 0 then
               Rel_Y := 0;
            elsif Rel_Y > Drag_Range then
               Rel_Y := Drag_Range;
            end if;
            Scroll_Px :=
              Integer
                (Long_Long_Integer (Rel_Y)
                   * Long_Long_Integer (Max_Scroll_Px)
                   / Long_Long_Integer (Drag_Range));
            Apply_Lines.all (Natural'Max (0, Scroll_Px / Line_Height));
         end Apply_Drag;

         procedure Set_Main_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, Lines);
         end Set_Main_Lines;

         procedure Set_Info_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Info_Pane_Scroll_Lines (Runtime.Model, Lines);
         end Set_Info_Lines;
      begin
         case Runtime.Scrollbar_Drag_Target is
            when Files.Events.Scroll_Main_View =>
               declare
                  Main_View : constant Files.Rendering.Main_View_Layout :=
                    Files.Rendering.Calculate_Main_View_Layout
                      (Snapshot, Layout, Line_Height);
               begin
                  if Main_View.Scrollbar_Visible then
                     Apply_Drag
                       (Track_Y     => Main_View.Scrollbar_Y,
                        Track_H     => Main_View.Scrollbar_Track_Height,
                        Thumb_H     => Main_View.Scrollbar_Height,
                        Content_H   => Main_View.Content_Height,
                        View_H      => Main_View.Scrollbar_Track_Height,
                        Apply_Lines => Set_Main_Lines'Access);
                  end if;
               end;
            when Files.Events.Scroll_Info_Pane =>
               declare
                  Info_Pane : constant Files.Rendering.Info_Pane_Layout :=
                    Files.Rendering.Calculate_Info_Pane_Layout
                      (Snapshot, Layout, Line_Height);
               begin
                  if Info_Pane.Scrollbar_Visible then
                     Apply_Drag
                       (Track_Y     => Info_Pane.Scrollbar_Y,
                        Track_H     => Info_Pane.Scrollbar_Track_Height,
                        Thumb_H     => Info_Pane.Scrollbar_Height,
                        Content_H   => Info_Pane.Content_Height,
                        View_H      => Info_Pane.Height,
                        Apply_Lines => Set_Info_Lines'Access);
                  end if;
               end;
            when others =>
               null;
         end case;
      end;
   end Update_Scrollbar_Drag;
