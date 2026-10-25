separate (Files_Suite.Rendering)
   --  A marquee that auto-scrolls hit-tests every item where it sits in the
   --  unscrolled content: a row scrolled off screen has no area on screen,
   --  yet it is still inside the band and must stay selected.
   procedure Test_Whole_Content_Item_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Unscrolled : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
      Scrolled   : View_Snapshot := Unscrolled;
   begin
      Scrolled.Main_View_Scroll_Lines := 10;
      declare
         Layout  : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Scrolled, 1000, 800, 20);
         Main    : constant Main_View_Layout := Calculate_Main_View_Layout (Scrolled, Layout, 20);
         Plain   : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Unscrolled, Layout, 20);
         Screen  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Scrolled, Layout, 20);
         Content : constant Item_Layout_Vectors.Vector :=
           Calculate_Item_Layout (Scrolled, Layout, 20, Whole_Content => True);
      begin
         Assert (Main.Scroll_Pixels > 0, "the 40-row list scrolls");
         Files_Suite.Support.Assert_Equal
           (Screen.First_Element.Height, 0, "on screen, the scrolled-off first row has no area");
         Files_Suite.Support.Assert_Equal
           (Natural (Content.Length), 40, "the whole-content layout places every item");
         for Index in Content.First_Index .. Content.Last_Index loop
            Files_Suite.Support.Assert_Equal
              (Content.Element (Index).Y, Plain.Element (Index).Y,
               "every item sits where it would with no scroll, row" & Index'Image);
            Assert (Content.Element (Index).Height > 0, "every item has its area, row" & Index'Image);
         end loop;
         for Index in Screen.First_Index .. Screen.Last_Index loop
            if Screen.Element (Index).Height > 0 then
               Files_Suite.Support.Assert_Equal
                 (Screen.Element (Index).Y + Main.Scroll_Pixels, Content.Element (Index).Y,
                  "an on-screen row's content place is its screen place plus the scroll, row" & Index'Image);
            end if;
         end loop;
      end;
   end Test_Whole_Content_Item_Layout;
