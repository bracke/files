separate (Files_Suite.Rendering)
   --  A wide bar shows the labelled counts; a narrow one drops the labels and
   --  slash-separates the three numbers.
   procedure Test_Counts_Compact_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Vis_Lbl : constant String := Files.Localization.Text ("status.visible");

      function Bottom_Has
        (Frame : Frame_Commands; Layout : Guikit.Draw.Layout_Metrics; Sub : String) return Boolean
      is
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y and then Ada.Strings.Fixed.Index (To_String (C.Text), Sub) > 0 then
               return True;
            end if;
         end loop;
         return False;
      end Bottom_Has;
   begin
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      begin
         Assert (Bottom_Has (Frame, Layout, Vis_Lbl), "a wide bar shows the labelled counts");
      end;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 600, 800, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 600, 800, 20);
      begin
         Assert (not Bottom_Has (Frame, Layout, Vis_Lbl), "a narrow bar drops the count labels");
         Assert (Bottom_Has (Frame, Layout, "/"), "a narrow bar slash-separates the numbers");
      end;
   end Test_Counts_Compact_When_Narrow;
