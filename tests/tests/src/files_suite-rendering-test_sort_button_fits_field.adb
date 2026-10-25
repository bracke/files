separate (Files_Suite.Rendering)
   --  The sort button tracks the active field's label width (narrower for a short
   --  field), while the sort dropdown is sized to the widest field so no row clips.
   procedure Test_Sort_Button_Fits_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Find_Clipped_Width return Natural is
      begin
         for Width in 1 .. 1_000 loop
            declare
               Bar : constant Guikit.Layout.Bottom_Bar_Layout :=
                 Files.UI.Calculate_Bottom_Bar_Layout
                   (Width, Files.Types.Sort_Name, 20);
            begin
               if Bar.Sort_Button_Width > 0
                 and then Bar.Sort_Button_X + Files.UI.Sort_Menu_Width (20) > Width
               then
                  return Width;
               end if;
            end;
         end loop;
         return 0;
      end Find_Clipped_Width;

      Name_Bar : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Types.Sort_Name, 20);
      Chg_Bar  : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Types.Sort_Changed, 20);
      Menu_W   : constant Natural := Files.UI.Sort_Menu_Width (20);
      Compact_W : constant Natural := Find_Clipped_Width;
   begin
      Assert (Name_Bar.Sort_Button_Width > 0 and then Chg_Bar.Sort_Button_Width > 0,
              "the sort button is laid out for both fields");
      Assert (Name_Bar.Sort_Button_Width < Chg_Bar.Sort_Button_Width,
              "the sort button is narrower for a shorter field label");
      Assert (Menu_W >= Chg_Bar.Sort_Button_Width,
              "the sort menu is at least as wide as the widest field's button");
      Assert (Menu_W > Name_Bar.Sort_Button_Width,
              "the sort menu is wider than the snug button for a short field");
      Assert (Compact_W > 0, "a compact width clips the preferred sort menu");
      if Compact_W > 0 then
         declare
            Height   : constant Natural := 800;
            Row_H    : constant Natural :=
              20 + 2 * Guikit.Layout.Bottom_Bar_Padding;
            Bottom_Y : constant Natural := Height - Row_H;
            Menu_H   : constant Natural :=
              5 * Row_H + 2 * Guikit.Layout.Sort_Menu_Padding;
            Rows_Y   : constant Natural :=
              Bottom_Y - Menu_H + Guikit.Layout.Sort_Menu_Padding;
            Row_Y    : constant Natural := Rows_Y + Row_H / 2;
            Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
              Files.UI.Calculate_Bottom_Bar_Layout
                (Compact_W, Files.Types.Sort_Name, 20);
            Visible_W : constant Natural :=
              Files.UI.Sort_Menu_Visible_Width
                (Compact_W, Files.Types.Sort_Name, 20);
         begin
            Files_Suite.Support.Assert_Equal
              (Bar.Sort_Button_X + Visible_W,
               Compact_W,
               "the visible sort menu stops at the right framebuffer edge");
            Assert
              (Visible_W < Menu_W,
               "the compact sort menu is clipped from its preferred width");
            Assert
              (Files.Rendering.Hit.Bottom_Bar_Sort_Menu_Command_At
                 (Compact_W, Row_Y, Compact_W, Height,
                  Files.Types.Sort_Name, 20) = Files.Commands.No_Command,
               "the clipped sort-menu edge cannot select a row");
            Assert
              (not Files.Rendering.Hit.Bottom_Bar_Sort_Menu_Contains
                 (Compact_W, Row_Y, Compact_W, Height,
                  Files.Types.Sort_Name, 20),
               "the clipped sort-menu edge is outside the menu");
         end;
      end if;

      declare
         Short_H : constant Natural := 20;
         Bar     : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout
             (1000, Files.Types.Sort_Name, 20);
      begin
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Bottom_Bar_Sort_Menu_Command_At
              (Bar.Sort_Button_X, 0, 1000, Short_H, Files.Types.Sort_Name, 20),
            Files.Commands.No_Command,
            "compact sort-menu padding does not select a row");
         Assert
           (Files.Rendering.Hit.Bottom_Bar_Sort_Menu_Contains
              (Bar.Sort_Button_X, 0, 1000, Short_H,
               Files.Types.Sort_Name, 20),
            "visible compact sort-menu padding remains inside the clipped panel");
      end;
   end Test_Sort_Button_Fits_Field;
