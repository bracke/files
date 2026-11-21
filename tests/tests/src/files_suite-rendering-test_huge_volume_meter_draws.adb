with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  hostkit saturates a volume's capacity to Long_Long_Integer'Last when
   --  blocks times block size overflows (a vast network mount). The space
   --  bar multiplied the used bytes by its width and raised, so the window
   --  stopped drawing for as long as that folder was open.
   procedure Test_Huge_Volume_Meter_Draws (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (3, Files.Preference_Types.Details);
   begin
      Snapshot.Free_Space_Known := True;
      Snapshot.Show_Space_Bar := True;
      Snapshot.Total_Space_Bytes := Long_Long_Integer'Last;
      Snapshot.Free_Space_Bytes := 0;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 700, 20);
      begin
         Assert (Natural (Frame.Rectangles.Length) > 0, "the frame with a saturated volume is drawn");
      end;
      Snapshot.Free_Space_Bytes := Long_Long_Integer'Last / 3;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 700, 20);
      begin
         Assert (Natural (Frame.Rectangles.Length) > 0, "a partly used saturated volume is drawn too");
      end;
   end Test_Huge_Volume_Meter_Draws;
