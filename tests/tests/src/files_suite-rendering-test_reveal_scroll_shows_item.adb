separate (Files_Suite.Rendering)
   procedure Test_Reveal_Scroll_Shows_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Types.View_Mode :=
        [Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details];

      --  Whether the item with Visible_Index is laid out whole.
      function Shown (Snapshot : View_Snapshot; Layout : Guikit.Draw.Layout_Metrics; Index : Positive)
        return Boolean is
      begin
         for Cell of Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20) loop
            if Cell.Visible_Index = Index then
               return Cell.Height > 0;
            end if;
         end loop;
         return False;
      end Shown;
   begin
      for Mode of Modes loop
         declare
            Snapshot : View_Snapshot := Sample_Snapshot (400, Mode);
            Layout   : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snapshot, Width => 1000, Height => 600, Line_Height => 20);
         begin
            Assert (not Shown (Snapshot, Layout, 390), "a far item starts out of view");
            Snapshot.Main_View_Scroll_Lines := Scroll_Lines_Revealing (Snapshot, Layout, 20, 390);
            Assert (Shown (Snapshot, Layout, 390), "revealing scrolls a far item whole into view");
            Files_Suite.Support.Assert_Equal
              (Scroll_Lines_Revealing (Snapshot, Layout, 20, 390),
               Snapshot.Main_View_Scroll_Lines,
               "an item in view keeps the scroll");
            Snapshot.Main_View_Scroll_Lines := Scroll_Lines_Revealing (Snapshot, Layout, 20, 1);
            Assert (Snapshot.Main_View_Scroll_Lines = 0 and then Shown (Snapshot, Layout, 1),
                    "revealing the first item scrolls back to the top");
            Assert (Main_View_Page_Rows (Snapshot, Layout, 20) > 1, "the view shows several rows");
         end;
      end loop;

      declare
         Model : Files.Model.Window_Model;
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         for Index in 1 .. 60 loop
            Items.Append
              (Files.File_System.Make_Item
                 (Files_Suite.Support.Root, "f" & Index'Image, Files.Types.Regular_File_Item, "text/plain"));
         end loop;
         Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
         Files.Model.Set_View_Mode (Model, Files.Types.Details);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Set_Selection_Page_Rows (Model, 23);
         Files.Model.Move_Selection_By_Page (Model, Files.Model.Selection_Page_Rows (Model), True);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            24,
            "Page Down moves by the measured rows in view");
      end;
   end Test_Reveal_Scroll_Shows_Item;
