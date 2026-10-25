separate (Files_Suite.Rendering)
   procedure Test_Detail_Column_Customization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Name_Width_Of (Items : Item_Layout_Vectors.Vector) return Natural is
      begin
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               return Cell.Name_Width;
            end if;
         end loop;
         return 0;
      end Name_Width_Of;

      function Size_Width_Of (Items : Item_Layout_Vectors.Vector) return Natural is
      begin
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               return Cell.Size_Width;
            end if;
         end loop;
         return 0;
      end Size_Width_Of;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
      Base_Items : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Base, Layout, Line_Height => 20);
      Base_Name_W : constant Natural := Name_Width_Of (Base_Items);
   begin
      Assert (Base_Name_W > 0, "the name column has a positive width");
      Assert (Size_Width_Of (Base_Items) > 0, "the size column is laid out when visible");

      --  Hiding the size column drops its width to zero and widens the name
      --  column, which must always remain present.
      declare
         Hidden : View_Snapshot := Base;
         Items  : Item_Layout_Vectors.Vector;
      begin
         Hidden.Detail_Columns_Visible (Files.Types.Size_Column) := False;
         Items := Calculate_Item_Layout (Hidden, Layout, Line_Height => 20);
         Files_Suite.Support.Assert_Equal (Size_Width_Of (Items), 0, "a hidden column contributes no width");
         Assert (Name_Width_Of (Items) > Base_Name_W,
                 "hiding a column re-flows its width into the remaining columns");
      end;

      --  A custom width is honoured; a sub-minimum request is clamped up.
      declare
         Wide : View_Snapshot := Base;
         Thin : View_Snapshot := Base;
         Wide_Items : Item_Layout_Vectors.Vector;
         Thin_Items : Item_Layout_Vectors.Vector;
      begin
         Wide.Detail_Column_Widths (Files.Types.Size_Column) := 220;
         Thin.Detail_Column_Widths (Files.Types.Size_Column) := 4;
         Wide_Items := Calculate_Item_Layout (Wide, Layout, Line_Height => 20);
         Thin_Items := Calculate_Item_Layout (Thin, Layout, Line_Height => 20);
         Files_Suite.Support.Assert_Equal
           (Size_Width_Of (Wide_Items),
            220,
            "a custom column width drives the layout width");
         Files_Suite.Support.Assert_Equal
           (Size_Width_Of (Thin_Items),
            Files.Types.Minimum_Detail_Column_Width,
            "a sub-minimum custom width is clamped up to the minimum");
      end;
   end Test_Detail_Column_Customization;
