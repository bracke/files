with Guikit.Item_Grid;
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
            --  The unscrolled screen layout gives a place only to the rows
            --  it shows; below those, rows keep stacking.
            if Plain.Element (Index).Height > 0 then
               Files_Suite.Support.Assert_Equal
                 (Content.Element (Index).Y, Plain.Element (Index).Y,
                  "every item sits where it would with no scroll, row" & Index'Image);
            end if;
            if Index > Content.First_Index then
               Assert (Content.Element (Index).Y > Content.Element (Index - 1).Y,
                       "the content rows stack downward, row" & Index'Image);
            end if;
            Assert (Content.Element (Index).Height > 0, "every item has its area, row" & Index'Image);
         end loop;
         Assert (Plain.Last_Element.Height = 0 and then Plain.Last_Element.Width = 0
                   and then Plain.Last_Element.Y = 0,
                 "a cell not on screen is laid out as no area at all");
         for Index in Screen.First_Index .. Screen.Last_Index loop
            if Screen.Element (Index).Height > 0 then
               Files_Suite.Support.Assert_Equal
                 (Screen.Element (Index).Y + Main.Scroll_Pixels, Content.Element (Index).Y,
                  "an on-screen row's content place is its screen place plus the scroll, row" & Index'Image);
            end if;
         end loop;
      end;

      --  In every view, grouped Details too, the cells on screen are where
      --  the whole content has them less the scroll, every other cell has
      --  no area, and nothing hit-tests a cell without one.
      for Mode in Files.Types.View_Mode loop
         for Grouped in Boolean loop
            declare
               Many   : View_Snapshot := Sample_Snapshot (400, Mode);
            begin
               if Grouped then
                  --  A header row every 25 items, as a grouped listing draws.
                  for Index in Many.Items.First_Index .. Many.Items.Last_Index loop
                     if Index mod 25 = 1 then
                        Many.Items (Index).Is_Group_Header := True;
                        Many.Items (Index).Visible_Index := 0;
                     end if;
                  end loop;
               end if;
               Many.Main_View_Scroll_Lines := 37;
               declare
                  Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Many, 1000, 800, 20);
                  Main   : constant Main_View_Layout := Calculate_Main_View_Layout (Many, Layout, 20);
                  Shown  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Many, Layout, 20);
                  Whole  : constant Item_Layout_Vectors.Vector :=
                    Calculate_Item_Layout (Many, Layout, 20, Whole_Content => True);
                  On     : Natural := 0;
                  Context : constant String :=
                    Files.Types.View_Mode'Image (Mode) & (if Grouped then " grouped" else "");
               begin
                  for Index in Shown.First_Index .. Shown.Last_Index loop
                     if Shown (Index).Height > 0 then
                        On := On + 1;
                        Files_Suite.Support.Assert_Equal
                          (Shown (Index).Y + Main.Scroll_Pixels, Whole (Index).Y,
                           Context & ": an on-screen cell sits where the content has it, cell" & Index'Image);
                        Files_Suite.Support.Assert_Equal
                          (Shown (Index).X, Whole (Index).X, Context & ": and at its column, cell" & Index'Image);
                     else
                        Assert (Shown (Index).Width = 0 and then Shown (Index).Y = 0,
                                Context & ": an off-screen cell has no area at all, cell" & Index'Image);
                     end if;
                  end loop;
                  Assert (On > 0 and then On < 400, Context & ": a screenful is laid out, not all or none");
                  for Y in 0 .. 40 loop
                     for X in 0 .. 20 loop
                        declare
                           Hit : constant Natural := Files.Rendering.Hit.Item_At (Shown, X * 50, Y * 20);
                        begin
                           Assert (Hit = 0
                                   or else
                                     (for some Cell of Shown => Cell.Visible_Index = Hit and then Cell.Height > 0),
                                   Context & ": a hit names a cell on screen");
                        end;
                     end loop;
                  end loop;
               end;
            end;
         end loop;
      end loop;

      --  A marquee lays out only its band's rows, at their unscrolled places:
      --  every band hits exactly what the whole-content layout hits, in
      --  every view, partly cut rows and cells included.
      for Mode in Files.Types.View_Mode loop
         declare
            Many   : constant View_Snapshot := Sample_Snapshot (400, Mode);
            Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Many, 1000, 800, 20);
            Whole  : constant Item_Layout_Vectors.Vector :=
              Calculate_Item_Layout (Many, Layout, 20, Whole_Content => True);
            use type Guikit.Item_Grid.Visible_Index_Vectors.Vector;
         begin
            for Top in 0 .. 40 loop
               for Height in 1 .. 4 loop
                  declare
                     Band_Y : constant Natural := Top * 137;
                     Band_H : constant Natural := Height * 53;
                     Band   : constant Item_Layout_Vectors.Vector :=
                       Calculate_Item_Layout
                         (Many, Layout, 20, Whole_Content => True, Window_Top => Band_Y, Window_Height => Band_H);
                  begin
                     Assert
                       (Files.Rendering.Hit.Items_In_Rect (Band, 30, Band_Y, 500, Band_H)
                        = Files.Rendering.Hit.Items_In_Rect (Whole, 30, Band_Y, 500, Band_H),
                        "a band layout hits what the whole content does: "
                        & Files.Types.View_Mode'Image (Mode) & Band_Y'Image & Band_H'Image);
                  end;
               end loop;
            end loop;
         end;
      end loop;
   end Test_Whole_Content_Item_Layout;
