separate (Files_Suite.Rendering)
   --  The counts (hidden-files toggle) and the free-space field (free/used
   --  toggle) are two separate hover regions: hovering one highlights only it.
   procedure Test_Free_Space_Outside_Toggle_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         HY       : constant Natural := Bottom_Y + Layout.Bottom_Bar_Height / 2;
         Counts_X : constant Natural := Bar.Info_X + 5;
         Free_HX  : constant Natural := Bar.Info_X + Bar.Info_Width - 5;

         --  True when, with the cursor at Hover_At, a hover highlight rectangle
         --  in the bottom bar covers Check_X.
         function Highlight_At (Hover_At, Check_X : Natural) return Boolean is
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snap, 1000, 800, 20, Hover_X => Hover_At, Hover_Y => HY, Has_Hover => True);
         begin
            for R of Frame.Rectangles loop
               if R.Color = Hover_Color and then R.Y >= Bottom_Y
                 and then Check_X >= R.X and then Check_X < R.X + R.Width
               then
                  return True;
               end if;
            end loop;
            return False;
         end Highlight_At;
      begin
         Assert (Highlight_At (Counts_X, Counts_X),
                 "hovering the counts area highlights it");
         Assert (not Highlight_At (Counts_X, Free_HX),
                 "hovering the counts area does not highlight the free-space field");
         Assert (Highlight_At (Free_HX, Free_HX),
                 "hovering the free-space field highlights it");
         Assert (not Highlight_At (Free_HX, Counts_X),
                 "hovering the free-space field does not highlight the counts area");
      end;
   end Test_Free_Space_Outside_Toggle_Hover;
