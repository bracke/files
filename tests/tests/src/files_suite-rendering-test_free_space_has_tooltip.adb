separate (Files_Suite.Rendering)
   --  The free-space field carries its own tooltip, positioned over the field
   --  (right side of the info region), distinct from the toggle's tooltip.
   procedure Test_Free_Space_Has_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Tip_Txt : constant String := Files.Localization.Text ("status.free_space.tooltip");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar   : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Found : Boolean := False;
      begin
         Assert (Tip_Txt'Length > 0, "the free-space tooltip text is localized");
         for C of Frame.Tooltips loop
            if To_String (C.Text) = Tip_Txt then
               Found := True;
               --  It sits over the free field, in the right half of the info area.
               Assert (C.X >= Bar.Info_X + Bar.Info_Width / 2,
                       "the free-space tooltip covers the field on the right of the info area");
            end if;
         end loop;
         Assert (Found, "the free-space field has its own tooltip");
      end;
   end Test_Free_Space_Has_Tooltip;
