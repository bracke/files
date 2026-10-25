separate (Files_Suite.Rendering)
   procedure Test_Detail_Header_Separator_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
      Items  : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Base, Layout, Line_Height => 20);

      Row      : Item_Layout;
      Found    : Boolean := False;
      Header_Y : Natural;
   begin
      --  Column boundaries align between the header and the item rows, so a data
      --  row's per-column left edges give the exact separator x positions.
      for Cell of Items loop
         if Cell.Visible_Index = 1 then
            Row := Cell;
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "the details list lays out a first data row");

      --  A y between the pane top and the first row lands inside the header band.
      Header_Y := (Layout.Main_Y + Row.Y) / 2;

      declare
         At_Size : constant Detail_Column_Separator :=
           Files.Rendering.Hit.Details_Header_Separator_At (Base, Layout, Row.Size_X, Header_Y, Line_Height => 20);
         At_Modified : constant Detail_Column_Separator :=
           Files.Rendering.Hit.Details_Header_Separator_At (Base, Layout, Row.Modified_X, Header_Y, Line_Height => 20);
         Mid_Name : constant Detail_Column_Separator :=
           Files.Rendering.Hit.Details_Header_Separator_At
             (Base, Layout, Row.Name_X + Row.Name_Width / 2, Header_Y, Line_Height => 20);
         Above_Header : constant Detail_Column_Separator :=
           Files.Rendering.Hit.Details_Header_Separator_At
             (Base, Layout, Row.Size_X, Row.Y + Row.Height, Line_Height => 20);
      begin
         Assert (At_Size.Present and then At_Size.Column = Files.Types.Size_Column,
                 "a press on the size column's left edge resolves to the size separator");
         Assert (At_Size.Origin_X = Row.Size_X and then At_Size.Width = Row.Size_Width,
                 "the separator reports the column's edge and current width");
         Assert (At_Modified.Present and then At_Modified.Column = Files.Types.Modified_Column,
                 "the boundary between name and the first fixed column resizes that fixed column");
         Assert (not Mid_Name.Present,
                 "a press in the middle of a header cell is not a separator");
         Assert (not Above_Header.Present,
                 "a press below the header band is not a separator");
      end;
   end Test_Detail_Header_Separator_Hit_Test;
