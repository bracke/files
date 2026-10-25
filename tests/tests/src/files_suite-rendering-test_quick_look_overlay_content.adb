separate (Files_Suite.Rendering)
   procedure Test_Quick_Look_Overlay_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  A text preview draws its dialog panel and the previewed lines.
      declare
         Snap  : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Text_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("readme.txt");
         Snap.Quick_Look_Text_Lines.Append (To_Unbounded_String ("first preview line"));
         Snap.Quick_Look_Text_Lines.Append (To_Unbounded_String ("second preview line"));
         Frame := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Frame_Has_Role (Frame, Role_Dialog), "the quick look overlay emits a dialog panel node");
         Assert (Frame_Has_Text (Frame, "readme.txt"), "the quick look title shows the item name");
         Assert (Frame_Has_Text (Frame, "first preview line"), "the quick look text body shows the first line");
      end;

      --  When the compact panel cannot display every loaded line, its final
      --  row explicitly says the preview is truncated instead of silently
      --  ending at an arbitrary source line.
      declare
         Snap  : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Text_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("long.txt");
         for Line in 1 .. 30 loop
            Snap.Quick_Look_Text_Lines.Append
              (To_Unbounded_String ("preview line" & Integer'Image (Line)));
         end loop;
         Frame := Build_Frame_Commands (Snap, 480, 360, LH);
         Assert
           (Frame_Has_Text (Frame, Files.Localization.Text ("quick_look.truncated")),
            "a compact quick look marks panel-height truncation");
         Assert
           (not Frame_Has_Text (Frame, "preview line 30"),
            "a compact quick look reserves its final visible row for the truncation notice");
      end;

      --  When closed the overlay draws nothing.
      declare
         Snap  : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         Assert (not Frame_Has_Text (Frame, "readme.txt"), "no quick look content is drawn when closed");
      end;
   end Test_Quick_Look_Overlay_Content;
