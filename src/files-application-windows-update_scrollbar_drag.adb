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

      procedure Cancel_Drag is
      begin
         Runtime.Scrollbar_Drag_Target := Files.Events.Scroll_Auto;
         Runtime.Scrollbar_Drag_Anchor := 0;
      end Cancel_Drag;
   begin
      if Runtime.Scrollbar_Drag_Target = Files.Events.Scroll_Auto then
         return;
      elsif not Mouse_Down
        or else Window_W = 0 or else Window_H = 0
        or else Frame_W = 0 or else Frame_H = 0
      then
         Cancel_Drag;
         return;
      end if;

      Refresh_Snapshot (Runtime);
      declare
         Y_Frame      : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Line_Height  : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot     : Files.Rendering.View_Snapshot renames Runtime.Snapshots (Runtime.Current_Slot);
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);

         procedure Apply_Drag
           (Track_Y     : Natural;
            Track_H     : Natural;
            Thumb_H     : Natural;
            Maximum     : Natural;
            Apply_Lines : access procedure (Lines : Natural))
         is
            --  Scroll_Drag_Anchor is a packed event payload. Use a wider type
            --  for the subtraction so even a malformed extreme value is
            --  clamped instead of overflowing before validation can contain it.
            Drag_Range : constant Long_Long_Integer :=
              Long_Long_Integer'Max
                (0, Long_Long_Integer (Track_H) - Long_Long_Integer (Thumb_H));
            Wanted_Top : constant Long_Long_Integer :=
              Long_Long_Integer (Y_Frame)
              - Long_Long_Integer (Runtime.Scrollbar_Drag_Anchor);
            Rel_Y      : Long_Long_Integer :=
              Wanted_Top - Long_Long_Integer (Track_Y);
         begin
            if Drag_Range <= 0 or else Maximum = 0 then
               Cancel_Drag;
               return;
            end if;
            if Rel_Y < 0 then
               Rel_Y := 0;
            elsif Rel_Y > Drag_Range then
               Rel_Y := Drag_Range;
            end if;
            Apply_Lines.all
              (Scrollbar_Drag_Offset
                 (Thumb_Top    => Natural (Rel_Y),
                  Track_Length => Track_H,
                  Thumb_Length => Thumb_H,
                  Maximum      => Maximum));
         end Apply_Drag;

         function Maximum_Line_Offset
           (Content_Height  : Natural;
            Viewport_Height : Natural)
            return Natural is
           (Files.Rendering.Max_Scroll_Lines (Content_Height, Viewport_Height, Line_Height));

         procedure Set_Main_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, Lines);
         end Set_Main_Lines;

         procedure Set_Info_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Info_Pane_Scroll_Lines (Runtime.Model, Lines);
         end Set_Info_Lines;

         procedure Set_Tree_Rows (Rows : Natural) is
         begin
            Files.Model.Set_Tree_Panel_Scroll_Rows (Runtime.Model, Rows);
         end Set_Tree_Rows;
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
                        Maximum     =>
                          Maximum_Line_Offset
                            (Main_View.Content_Height,
                             Main_View.Scrollbar_Track_Height),
                        Apply_Lines => Set_Main_Lines'Access);
                  else
                     Cancel_Drag;
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
                        Maximum     =>
                          Maximum_Line_Offset
                            (Info_Pane.Content_Height, Info_Pane.Height),
                        Apply_Lines => Set_Info_Lines'Access);
                  else
                     Cancel_Drag;
                  end if;
               end;
            when Files.Events.Scroll_Tree_Panel =>
               declare
                  Tree_Panel : constant Files.Rendering.Tree_Panel_Layout :=
                    Files.Rendering.Calculate_Tree_Panel_Layout
                      (Snapshot, Layout, Line_Height);
                  Tree_Count : constant Natural :=
                    Natural (Snapshot.Tree_Rows.Length);
                  Capacity : constant Natural :=
                    Files.Rendering.Tree_Row_Capacity (Snapshot, Tree_Panel);
                  Maximum : constant Natural :=
                    (if Tree_Count > Capacity then Tree_Count - Capacity else 0);
               begin
                  if Tree_Panel.Scrollbar_Visible
                    and then Tree_Panel.Row_Height > 0
                  then
                     Apply_Drag
                       (Track_Y     => Tree_Panel.Scrollbar_Y,
                        Track_H     => Tree_Panel.Scrollbar_Track_Height,
                        Thumb_H     => Tree_Panel.Scrollbar_Height,
                        Maximum     => Maximum,
                        Apply_Lines => Set_Tree_Rows'Access);
                  else
                     Cancel_Drag;
                  end if;
               end;
            when others =>
               Cancel_Drag;
         end case;
      end;
   end Update_Scrollbar_Drag;
