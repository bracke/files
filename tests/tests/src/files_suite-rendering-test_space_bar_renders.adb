separate (Files_Suite.Rendering)
   --  In bar mode the free field draws a track (Input_Color) with a blue
   --  (Selection_Color) core whose width is the used fraction, and no text.
   procedure Test_Space_Bar_Renders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Render_Color;
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Used_Sfx : constant String := Files.Localization.Text ("status.used_space.suffix");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Total_Space_Bytes := 100;
      Snap.Free_Space_Bytes := 40;  --  60% used
      Snap.Info_Pane_Open := False;
      Snap.Show_Space_Bar := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Track_X, Track_Y, Track_W, Fill_W : Natural := 0;
         Has_Track : Boolean := False;
         Has_Used, Has_Free : Boolean := False;
      begin
         --  The track is the bottom-bar Input_Color rect; the fill is the
         --  Selection_Color rect at the same origin.
         for R of Frame.Rectangles loop
            if R.Y >= Bottom_Y and then R.Color = Guikit.Draw.Input_Color then
               Track_X := R.X; Track_Y := R.Y; Track_W := R.Width; Has_Track := True;
            end if;
         end loop;
         for R of Frame.Rectangles loop
            if R.Color = Guikit.Draw.Selection_Color
              and then R.X = Track_X and then R.Y = Track_Y
            then
               Fill_W := R.Width;
            end if;
         end loop;
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Used_Sfx) > 0 then
                  Has_Used := True;
               end if;
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Free_Sfx) > 0 then
                  Has_Free := True;
               end if;
            end if;
         end loop;
         Assert (Has_Track and then Track_W > 0, "space bar draws a track");
         Assert (Fill_W > 0 and then Fill_W < Track_W, "the used fill is a fraction of the track");
         Assert (abs (Fill_W * 100 / Track_W - 60) <= 8, "the fill width is ~60% (the used fraction)");
         Assert (not Has_Used and then not Has_Free, "bar mode shows no free/used suffix text");
      end;

      --  When 10% or less of the disk is free, the fill warns in red, not blue.
      Snap.Free_Space_Bytes := 5;  --  5% free (95% used)
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Track_X, Track_Y : Natural := 0;
         Has_Red, Has_Blue : Boolean := False;
      begin
         for R of Frame.Rectangles loop
            if R.Y >= Bottom_Y and then R.Color = Guikit.Draw.Input_Color then
               Track_X := R.X; Track_Y := R.Y;
            end if;
         end loop;
         for R of Frame.Rectangles loop
            if R.X = Track_X and then R.Y = Track_Y then
               if R.Color = Guikit.Draw.Error_Text_Color then
                  Has_Red := True;
               elsif R.Color = Guikit.Draw.Selection_Color then
                  Has_Blue := True;
               end if;
            end if;
         end loop;
         Assert (Has_Red, "the fill is red when 10% or less is free");
         Assert (not Has_Blue, "the fill is not blue when free space is low");
      end;

      --  Host capacity values are signed machine-wide integers.  Comparing the
      --  low-space threshold must not multiply a large valid value by ten.
      Snap.Total_Space_Bytes := Long_Long_Integer'Last;
      Snap.Free_Space_Bytes := Long_Long_Integer'Last;
      declare
         Frame : constant Frame_Commands :=
           Build_Frame_Commands (Snap, 1000, 800, 20);
      begin
         Assert (not Frame.Rectangles.Is_Empty,
                 "extreme capacity values render without threshold overflow");
      end;
   end Test_Space_Bar_Renders;
