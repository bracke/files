separate (Files_Suite.Rendering)
   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Types.View_Mode :=
        [Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details];
   begin
      for Mode of Modes loop
         declare
            Snapshot : constant View_Snapshot := Sample_Snapshot (6, Mode);
            Layout   : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
            Items    : constant Item_Layout_Vectors.Vector :=
              Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
         begin
            Files_Suite.Support.Assert_Equal (Natural (Items.Length), 6, "every visible item is laid out");
            for Cell of Items loop
               Assert (Cell.Width > 0 and then Cell.Height > 0, "item cell has a positive size");
               Assert
                 (Cell.X >= Layout.Main_X
                  and then Cell.X + Cell.Width <= Layout.Main_X + Layout.Main_Width,
                  "item cell stays within the main-view width");
               Assert (Cell.Y >= Layout.Main_Y, "item cell starts at or below the main-view top");
            end loop;
            for Index in Items.First_Index .. Items.Last_Index - 1 loop
               declare
                  This_Cell : constant Item_Layout := Items.Element (Index);
                  Next_Cell : constant Item_Layout := Items.Element (Index + 1);
               begin
                  Assert
                    (Next_Cell.X >= This_Cell.X + This_Cell.Width
                     or else Next_Cell.Y >= This_Cell.Y + This_Cell.Height,
                     "consecutive items advance right or down without overlapping");
               end;
            end loop;
            declare
               First : constant Item_Layout := Items.Element (Items.First_Index);
            begin
               Files_Suite.Support.Assert_Equal
                 (Item_At (Items, First.X + First.Width / 2, First.Y + First.Height / 2),
                  First.Visible_Index,
                  "a hit test inside a cell returns that item");
            end;
         end;
      end loop;
   end Test_Item_Layout_Invariants;
