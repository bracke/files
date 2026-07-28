separate (Files.Application.Windows)
   function Scenario_Region
     (Runtime  : Runtime_Window;
      Scenario : Live_Smoke_Scenario;
      Frame_W  : Natural;
      Frame_H  : Natural)
      return Region_Rect
   is
      Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
      Snapshot    : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
      Layout      : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Frame_W, Frame_H, Line_Height);
   begin
      if Frame_W = 0 or else Frame_H = 0 or else Layout.Width = 0 then
         return (others => <>);
      end if;

      case Scenario is
         when Scenario_Default =>
            --  The toolbar band spans the frame top and always draws a distinct
            --  bar plus buttons/icons, so its layout rectangle must hold ink.
            if Layout.Toolbar_Height = 0 then
               return (others => <>);
            end if;
            return
              (Valid => True,
               X     => 0,
               Y     => 0,
               W     => Layout.Width,
               H     => Layout.Toolbar_Height);

         when Scenario_Selection =>
            --  The selected item's cell rectangle must hold ink: its icon,
            --  label and selection fill render there.
            declare
               Items        : constant Files.Rendering.Item_Layout_Vectors.Vector :=
                 Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
               Target_Index : Natural := 0;
            begin
               for Item of Snapshot.Items loop
                  if Item.Selected then
                     Target_Index := Item.Visible_Index;
                     exit;
                  end if;
               end loop;

               if Target_Index = 0 then
                  return (others => <>);
               end if;

               for Cell of Items loop
                  if Cell.Visible_Index = Target_Index
                    and then Cell.Width > 0
                    and then Cell.Height > 0
                  then
                     return
                       (Valid => True,
                        X     => Cell.X,
                        Y     => Cell.Y,
                        W     => Cell.Width,
                        H     => Cell.Height);
                  end if;
               end loop;

               return (others => <>);
            end;

         when others =>
            return (others => <>);
      end case;
   end Scenario_Region;
