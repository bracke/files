separate (Files_Suite.Rendering)
   procedure Test_Marquee_Frame_Draws_Rectangle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      Idle     : constant Frame_Commands :=
        Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Active   : constant Frame_Commands :=
        Build_Frame_Commands
          (Snapshot, 1000, 800, 20,
           Marquee_Active => True,
           Marquee_X      => 100,
           Marquee_Y      => 120,
           Marquee_W      => 200,
           Marquee_H      => 150);
   begin
      Assert (not Has_Rectangle_Colored (Idle, Marquee_Color),
              "no marquee rectangle is drawn while the marquee is inactive");
      Assert (Has_Rectangle_Colored (Active, Marquee_Color),
              "an active marquee draws a translucent marquee-colored fill over the grid");
   end Test_Marquee_Frame_Draws_Rectangle;
