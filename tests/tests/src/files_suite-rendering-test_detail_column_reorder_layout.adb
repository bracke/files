separate (Files_Suite.Rendering)
   procedure Test_Detail_Column_Reorder_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Row_Found : Boolean := False;
      Row       : Item_Layout;

      procedure Locate_Row (Items : Item_Layout_Vectors.Vector) is
      begin
         Row_Found := False;
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Row_Found := True;
               exit;
            end if;
         end loop;
      end Locate_Row;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
   begin
      --  Baseline (enum order): modified precedes size left to right.
      Locate_Row (Calculate_Item_Layout (Base, Layout, Line_Height => 20));
      Assert (Row_Found, "the details list lays out a first data row");
      Assert (Row.Modified_X < Row.Size_X, "the default order lays modified left of size");

      --  Moving size before modified swaps their left-to-right positions while
      --  each column keeps its own width (widths follow the column, not the slot).
      declare
         Reordered : View_Snapshot := Base;
      begin
         Reordered.Detail_Column_Widths (Files.Types.Size_Column) := 150;
         Reordered.Detail_Column_Order :=
           Files.Types.Move_Column (Base.Detail_Column_Order, Files.Types.Size_Column, 2);
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row_Found, "the reordered details list lays out a first data row");
         Assert (Row.Size_X < Row.Modified_X, "the reordered order lays size left of modified");
         Files_Suite.Support.Assert_Equal
           (Row.Size_Width,
            150,
            "the customized width follows its column across the reorder");
      end;

      --  A hidden column contributes no width, but re-showing it restores it to
      --  its ordered slot (here: first optional column after the name column).
      declare
         Reordered : View_Snapshot := Base;
      begin
         Reordered.Detail_Column_Order :=
           Files.Types.Move_Column (Base.Detail_Column_Order, Files.Types.Filetype_Column, 2);
         Reordered.Detail_Columns_Visible (Files.Types.Filetype_Column) := False;
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row_Found, "the list lays out a first row with a hidden reordered column");
         Files_Suite.Support.Assert_Equal
           (Row.Filetype_Width,
            0,
            "a hidden column contributes no width in its ordered slot");

         Reordered.Detail_Columns_Visible (Files.Types.Filetype_Column) := True;
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row.Filetype_Width > 0, "re-showing the column restores its width");
         Assert (Row.Filetype_X < Row.Modified_X and then Row.Filetype_X < Row.Size_X,
                 "the re-shown column reappears in its ordered slot ahead of the others");
      end;
   end Test_Detail_Column_Reorder_Layout;
