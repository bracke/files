separate (Files_Suite.Rendering)
   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Selected_Word : constant String := Files.Localization.Text ("status.selected");
      Mib_Unit      : constant String := Files.Localization.Text ("details.size.unit.mib");
      One_Mib       : constant Long_Long_Integer := 1024 * 1024;
      Snapshot      : View_Snapshot := Sample_Snapshot (5, Files.Types.Small_Icons);
      Frame         : Frame_Commands;

      procedure Mark_Selected (Index : Positive; Size : Long_Long_Integer) is
         Item : Item_Snapshot := Snapshot.Items.Element (Index);
      begin
         Item.Selected := True;
         Item.Size_Available := True;
         Item.Size := Size;
         Snapshot.Items.Replace_Element (Index, Item);
      end Mark_Selected;
   begin
      --  Free space is intentionally left unknown so the only size unit that can
      --  appear in the bar originates from the selection summary.
      Snapshot.Free_Space_Known := False;

      --  Neutral state: nothing selected shows the count without a size total.
      Snapshot.Selected_Count := 0;
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Selected_Word),
              "the bottom bar shows the selection label in the neutral state");
      Assert (not Frame_Has_Text (Frame, Mib_Unit),
              "the neutral bottom bar shows no selection size total");

      --  Three selected items with known sizes summing to 3 MB. The bottom bar
      --  reads the combined selection total (files plus measured folder sizes),
      --  which Build_Snapshot computes; here the snapshot is built directly, so
      --  set it to the sum.
      Mark_Selected (1, One_Mib);
      Mark_Selected (2, One_Mib);
      Mark_Selected (3, One_Mib);
      Snapshot.Selected_Count := 3;
      Snapshot.Selection_Total_Bytes := 3 * One_Mib;
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Selected_Word),
              "the bottom bar shows the selection label when items are selected");
      Assert (Frame_Has_Text (Frame, "3"),
              "the bottom bar reflects the selection count");
      Assert (Frame_Has_Text (Frame, Mib_Unit),
              "the bottom bar shows the summed size of the selected items");
   end Test_Bottom_Bar_Selection_Summary;
