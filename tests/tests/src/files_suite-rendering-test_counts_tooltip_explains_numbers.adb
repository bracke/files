separate (Files_Suite.Rendering)
   --  The counts tooltip spells out what the three numbers mean, so the compact
   --  "N/N/N" form (which drops the labels) stays understandable.
   procedure Test_Counts_Tooltip_Explains_Numbers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Legend : constant String :=
        Files.Localization.Text ("status.hidden") & " / "
        & Files.Localization.Text ("status.visible") & " / "
        & Files.Localization.Text ("status.selected");
   begin
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar   : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Found : Boolean := False;
      begin
         for C of Frame.Tooltips loop
            if C.X = Bar.Info_X and then Ada.Strings.Fixed.Index (To_String (C.Text), Legend) > 0 then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the counts tooltip names the numbers hidden / visible / selected");
      end;
   end Test_Counts_Tooltip_Explains_Numbers;
