separate (Files_Suite.Rendering)
   procedure Test_Compact_Empty_State_Stays_In_View
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      LH      : constant Positive := 20;
      Height  : constant Natural :=
        3 * LH + 2 * Guikit.Layout.Bottom_Bar_Padding + 1;
      Snap    : constant View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      Found   : Boolean := False;
   begin
      for Width in 1 .. 120 loop
         declare
            Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snap, Width, Height, LH);
            Frame  : constant Frame_Commands :=
              Build_Frame_Commands (Snap, Width, Height, LH);
         begin
            Files_Suite.Support.Assert_Equal (Layout.Main_Height, 1, "the compact case has a one-pixel main view");
            for Command of Frame.Text loop
               if Command.Y >= Layout.Main_Y
                 and then Command.Y < Layout.Main_Y + Layout.Main_Height
               then
                  Found := True;
                  Files_Suite.Support.Assert_Inside
                    (Command.X, Command.Y, Command.Width, Command.Height,
                     Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height,
                     "empty-state text stays inside the compact main view");
               end if;
            end loop;
         end;
      end loop;
      Assert (Found, "the compact cases exercise visible empty-state text");
   end Test_Compact_Empty_State_Stays_In_View;
