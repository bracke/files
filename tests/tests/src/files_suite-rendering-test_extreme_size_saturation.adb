separate (Files_Suite.Rendering)
   procedure Test_Extreme_Size_Saturation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (8, Files.Types.Details);
      Layout   : Guikit.Draw.Layout_Metrics;
      Items    : Item_Layout_Vectors.Vector;
      Main     : Main_View_Layout;
   begin
      Snapshot.Info_Pane_Open := True;
      Snapshot.Selected_Info.Append (Info_Snapshot'(others => <>));
      Snapshot.Main_View_Scroll_Lines := Natural'Last;

      --  None of these may raise CONSTRAINT_ERROR at extreme sizes; reaching
      --  the assertions proves the layout saturates instead of overflowing.
      Layout := Calculate_Layout
        (Snapshot, Width => Natural'Last, Height => Natural'Last, Line_Height => Positive'Last);
      Items  := Calculate_Item_Layout (Snapshot, Layout, Line_Height => Positive'Last);
      Main   := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height => Positive'Last);

      declare
         Info  : constant Info_Pane_Layout :=
           Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => Positive'Last);
         Frame : constant Frame_Commands :=
           Build_Frame_Commands
             (Snapshot, Width => Natural'Last, Height => Natural'Last, Line_Height => Positive'Last);
      begin
         Files_Suite.Support.Assert_Equal (Natural (Items.Length), 8, "items are still laid out at extreme sizes");
         Files_Suite.Support.Assert_Equal
           (Layout.Toolbar_Height,
            Natural'Last,
            "a huge line height saturates the toolbar height");
         Files_Suite.Support.Assert_Equal
           (Main.Content_Height,
            Natural'Last,
            "huge content height saturates instead of overflowing");
         Assert (Main.Scroll_Pixels <= Main.Content_Height, "the saturated scroll offset stays bounded");
         Assert (Info.Scroll_Pixels <= Info.Content_Height, "the info-pane scroll offset stays bounded");
         Files_Suite.Support.Assert_Equal
           (Frame.Layout.Toolbar_Height,
            Natural'Last,
            "the rendered frame layout also saturates");
      end;

      declare
         Overlay : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
      begin
         Overlay.Quick_Look_Open := True;
         Overlay.Context_Menu_Open := True;
         Overlay.Context_Menu_Target := Files.Types.Context_Menu_Item;
         Overlay.Context_Menu_X := Natural'Last;
         Overlay.Context_Menu_Y := Natural'Last;
         declare
            Overlay_Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout
                (Overlay, Natural'Last, Natural'Last, Positive'Last);
            Quick_Look : constant Quick_Look_Layout :=
              Calculate_Quick_Look_Layout (Overlay_Layout, Positive'Last);
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout
                (Overlay, Natural'Last, Natural'Last, Positive'Last);
         begin
            Assert
              (Quick_Look.Width <= Overlay_Layout.Width
               and then Quick_Look.Height <= Overlay_Layout.Height,
               "quick-look extreme dimensions remain inside the layout");
            Assert
              (Menu.X <= Natural'Last - Menu.Width
               and then Menu.Y <= Natural'Last - Menu.Height,
               "context-menu extreme coordinates remain representable");
         end;
      end;

      declare
         Boundary_Frame : Frame_Commands;
         Boundary_Menu  : Context_Menu_Layout;
      begin
         Boundary_Frame.Conflict_Hits.Append
           (Conflict_Hit_Region'
              (Kind   => Conflict_Hit_Replace,
             X      => Natural'Last,
             Y      => Natural'Last,
             Width  => 1,
             Height => 1));
         Assert
           (Files.Rendering.Hit.Conflict_Hit_At
              (Boundary_Frame, Natural'Last, Natural'Last).Kind =
                Conflict_Hit_Replace,
            "hit testing accepts a one-pixel region at the coordinate limit");

         Boundary_Menu.Visible := True;
         Boundary_Menu.X := Natural'Last;
         Boundary_Menu.Y := Natural'Last;
         Boundary_Menu.Width := 1;
         Boundary_Menu.Height := 1;
         Boundary_Menu.Row_Height := 1;
         Boundary_Menu.Row_Count := 1;
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Context_Menu_Row_At (Boundary_Menu, Natural'Last, Natural'Last),
            1,
            "context-menu hit testing accepts the coordinate limit");
      end;
   end Test_Extreme_Size_Saturation;
