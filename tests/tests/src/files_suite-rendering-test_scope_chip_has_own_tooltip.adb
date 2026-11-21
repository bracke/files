with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  Hovering the search-scope chip shows a tooltip describing the scope, not
   --  the filter field's tooltip that spans the same toolbar section.
   procedure Test_Scope_Chip_Has_Own_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap  : constant View_Snapshot := Sample_Snapshot (5, Files.Preference_Types.Small_Icons);
      Tip   : constant String := Files.Localization.Text ("search.scope.tooltip");
      Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1400, 800, 20);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (1400);
      Chip  : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Files.Rendering.Layouts.Filter_Scope_Chip_Width (20), 20);
      Found : Boolean := False;
   begin
      Assert (Chip.Visible, "the search-scope chip is visible in a wide window");
      Assert (Tip'Length > 0, "the scope tooltip text is localized");
      declare
         CX : constant Natural := Chip.X + Chip.Width / 2;
         CY : constant Natural := Chip.Y + Chip.Height / 2;
      begin
         for C of reverse Frame.Tooltips loop
            if CX >= C.X and then CX < C.X + C.Width
              and then CY >= C.Y and then CY < C.Y + C.Height
            then
               --  The last tooltip covering the point wins, as Tooltip_At resolves it.
               Files_Suite.Support.Assert_Equal
                 (To_String (C.Text),
                  Tip,
                  "the topmost tooltip over the scope chip describes the scope");
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "a tooltip covers the scope chip");
         --  The tooltip the hover shows: the chip's, recorded over the
         --  filter field's, not the field's beneath it.
         declare
            Hovered : constant Frame_Commands :=
              Build_Frame_Commands
                (Snap, 1400, 800, 20,
                 Pointer => (Hover_X => CX, Hover_Y => CY, Has_Hover => True, others => <>));
            Shown : Boolean := False;
         begin
            for Row of Hovered.Overlay_Text loop
               declare
                  Text : constant String := To_String (Row.Text);
               begin
                  if Text'Length > 0
                    and then Text'Length <= Tip'Length
                    and then Tip (Tip'First .. Tip'First + Text'Length - 1) = Text
                  then
                     Shown := True;
                  end if;
               end;
            end loop;
            Assert (Shown, "hovering the scope chip shows the scope tooltip");
         end;
      end;
   end Test_Scope_Chip_Has_Own_Tooltip;
