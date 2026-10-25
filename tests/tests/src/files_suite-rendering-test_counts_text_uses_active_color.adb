separate (Files_Suite.Rendering)
   --  The counts (hidden-files toggle) and the free-space field (free/used
   --  toggle) are both clickable, so their text uses the same active colour as
   --  the info-pane toggle button.
   procedure Test_Counts_Text_Uses_Active_Color (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Vis_Lbl  : constant String := Files.Localization.Text ("status.visible");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Counts_C, Free_C, Pane_C : Guikit.Draw.Render_Color;
         Has_Counts, Has_Free, Has_Pane : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), Vis_Lbl) > 0 then
                  Counts_C := C.Color;
                  Has_Counts := True;
               elsif Ada.Strings.Fixed.Index (To_String (C.Text), Free_Sfx) > 0 then
                  Free_C := C.Color;
                  Has_Free := True;
               elsif C.X >= Bar.Info_Pane_X then
                  Pane_C := C.Color;
                  Has_Pane := True;
               end if;
            end if;
         end loop;
         Assert (Has_Counts, "the counts, free-space and info-pane texts are all present (counts)");
         Assert (Has_Free, "the counts, free-space and info-pane texts are all present (free space)");
         Assert (Has_Pane, "the counts, free-space and info-pane texts are all present (info pane)");
         Assert (Counts_C = Pane_C,
                 "the counts text uses the same active colour as the info-pane toggle");
         Assert (Counts_C = Free_C,
                 "the clickable free-space field uses the same active colour as the counts");
      end;
   end Test_Counts_Text_Uses_Active_Color;
