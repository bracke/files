separate (Files_Suite.Rendering)
   --  Every text element in the bottom bar -- including the view-mode chooser's
   --  segment labels -- sits on a single shared baseline, so nothing looks
   --  vertically off-centre relative to the rest of the bar.
   procedure Test_Bottom_Bar_Text_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      Baseline : Integer := -1;
      Labels   : Natural := 0;
   begin
      for C of Frame.Text loop
         if C.Y >= Bottom_Y then
            if Baseline < 0 then
               Baseline := C.Y;
            else
               Files_Suite.Support.Assert_Equal
                 (C.Y,
                  Baseline,
                  "all bottom-bar text shares a single vertical baseline");
            end if;
            if To_String (C.Text) = "Small" or else To_String (C.Text) = "Large"
              or else To_String (C.Text) = "Details"
            then
               Labels := Labels + 1;
            end if;
         end if;
      end loop;
      Assert (Baseline >= 0, "the bottom bar draws text");
      Assert (Labels >= 3, "the three view-mode chooser labels are drawn in the bottom bar");
   end Test_Bottom_Bar_Text_Baseline;
