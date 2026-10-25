separate (Files_Suite.Rendering)
   --  In used-space mode the field's label shows the used-space suffix, not the
   --  free-space one.
   procedure Test_Used_Space_Label_After_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Used_Sfx : constant String := Files.Localization.Text ("status.used_space.suffix");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Total_Space_Bytes := 100_000_000_000;
      Snap.Show_Used_Space := True;
      declare
         Layout    : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame     : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y  : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Has_Used  : Boolean := False;
         Has_Free  : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Used_Sfx) > 0 then
                  Has_Used := True;
               elsif Ada.Strings.Fixed.Index (To_String (C.Text), " " & Free_Sfx) > 0 then
                  Has_Free := True;
               end if;
            end if;
         end loop;
         Assert (Has_Used, "used-space mode shows the used-space suffix");
         Assert (not Has_Free, "used-space mode does not show the free-space suffix");
      end;
   end Test_Used_Space_Label_After_Toggle;
