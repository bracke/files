separate (Files_Suite.Rendering)
   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Items    : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      First    : constant Item_Layout := Items.Element (Items.First_Index);
      On_Item  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame,
           X      => First.X + First.Width / 2,
           Y      => First.Y + First.Height / 2,
           Width  => 1000,
           Height => 800);
      Last     : constant Item_Layout := Items.Element (Items.Last_Index);
      Empty_Y  : constant Natural := Last.Y + Last.Height + 20;
      Off_Item : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame,
           X => Layout.Main_X + 20, Y => Empty_Y, Width => 1000, Height => 800);
      Outside  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X => 999, Y => 799, Width => 1000, Height => 800);
   begin
      Assert
        (On_Item.Kind /= Files.Events.No_Input_Action,
         "clicking an item produces an input action");
      Assert
        (Empty_Y < Layout.Main_Y + Layout.Main_Height,
         "the six-row list leaves empty grid space below its last row");
      Files_Suite.Support.Assert_Equal
        (Off_Item.Kind,
         Files.Events.Marquee_Begin_Input_Action,
         "pressing empty grid space begins a rubber-band marquee");
      Assert
        (Outside.Kind /= Files.Events.Marquee_Begin_Input_Action,
         "pressing the chrome outside the grid never begins a marquee");
      declare
         Edge_Snapshot : View_Snapshot := Snapshot;
      begin
         Edge_Snapshot.Sort_Menu_Open := True;
         declare
            Edge_Frame : constant Frame_Commands :=
              Build_Frame_Commands (Edge_Snapshot, 1000, 800, 20);
            Right_Edge : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Edge_Snapshot, Edge_Frame,
                 X => 1000, Y => 400, Width => 1000, Height => 800);
            Bottom_Edge : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Edge_Snapshot, Edge_Frame,
                 X => 500, Y => 800, Width => 1000, Height => 800);
         begin
            Files_Suite.Support.Assert_Equal
              (Right_Edge.Kind,
               Files.Events.No_Input_Action,
               "the right framebuffer extent is not an actionable pixel");
            Files_Suite.Support.Assert_Equal
              (Bottom_Edge.Kind,
               Files.Events.No_Input_Action,
               "the bottom framebuffer extent is not an actionable pixel");
         end;
      end;
   end Test_Click_Translation_Behavior;
