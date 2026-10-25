separate (Files_Suite.Rendering)
   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base   : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Base, 1000, 800, 20);
      Items  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Base, Layout, 20);
      Cell   : Item_Layout;
      Found  : Boolean := False;
   begin
      for C of Items loop
         if C.Visible_Index = 2 then
            Cell  := C;
            Found := True;
         end if;
      end loop;
      Assert (Found, "a layout cell exists for the hovered item");

      declare
         HX           : constant Natural := Cell.X + Cell.Width / 2;
         HY           : constant Natural := Cell.Y + Cell.Height / 2;
         Menu_Open    : View_Snapshot := Base;
         Closed_Frame : constant Frame_Commands :=
           Build_Frame_Commands
             (Base, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
      begin
         Assert
           (Cell_Has_Hover_Highlight (Closed_Frame, Cell),
            "with no context menu the hovered cell shows the main-grid hover highlight");

         Menu_Open.Context_Menu_Open := True;
         declare
            Open_Frame : constant Frame_Commands :=
              Build_Frame_Commands
                (Menu_Open, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Assert
              (not Cell_Has_Hover_Highlight (Open_Frame, Cell),
               "with the context menu open the hovered main-grid cell shows no hover highlight");
         end;
      end;
   end Test_Context_Menu_Suppresses_Item_Hover;
