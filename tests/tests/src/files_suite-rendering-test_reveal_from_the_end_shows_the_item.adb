with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  At the end of a list the view draws at the exact maximum, which is
   --  rarely a whole row period, while any other offset is snapped down to
   --  a row. Revealing an item above the view from there asked for the
   --  lines rounded up, and when those reached the last pixel the view was
   --  drawn at the end again: the item stayed cut off. Revealing now asks
   --  Layouts.Lines_For_Offset, as the wheel does, in every view mode and
   --  at many window heights.
   procedure Test_Reveal_From_The_End_Shows_The_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Preference_Types.View_Mode :=
        [Files.Preference_Types.Small_Icons, Files.Preference_Types.Large_Icons, Files.Preference_Types.Details];
      LH    : constant Positive := 20;
      Count : constant Positive := 400;

      function Shown (Snapshot : View_Snapshot; Layout : Guikit.Draw.Layout_Metrics; Index : Positive)
        return Boolean is
      begin
         for Cell of Calculate_Item_Layout (Snapshot, Layout, Line_Height => LH) loop
            if Cell.Visible_Index = Index then
               return Cell.Height > 0;
            end if;
         end loop;
         return False;
      end Shown;

      Checked : Natural := 0;
   begin
      for Mode of Modes loop
         for Step in 0 .. 40 loop
            declare
               Height   : constant Natural := 400 + Step * 7;
               Snapshot : View_Snapshot := Sample_Snapshot (Count, Mode);
               Layout   : constant Guikit.Draw.Layout_Metrics :=
                 Calculate_Layout (Snapshot, Width => 1000, Height => Height, Line_Height => LH);
               Name     : constant String := Files.Preference_Types.View_Mode'Image (Mode) & Height'Image;
            begin
               for Index in reverse Count - 40 .. Count loop
                  --  From the very end of the list.
                  Snapshot.Main_View_Scroll_Lines := Natural'Last / 2;
                  if not Shown (Snapshot, Layout, Index) then
                     Snapshot.Main_View_Scroll_Lines := Scroll_Lines_Revealing (Snapshot, Layout, LH, Index);
                     Assert (Shown (Snapshot, Layout, Index), Name & ": item" & Index'Image & " revealed whole");
                     Checked := Checked + 1;
                  end if;
               end loop;
            end;
         end loop;
      end loop;
      Assert (Checked > 0, "some items start above the view at the end");
   end Test_Reveal_From_The_End_Shows_The_Item;
