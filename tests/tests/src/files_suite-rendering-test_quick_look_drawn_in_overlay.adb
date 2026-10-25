separate (Files_Suite.Rendering)
   --  Quick Look composites in the overlay layer (on top of the grid), so its
   --  panel background is an overlay rectangle and its preview icon is flagged
   --  as an overlay icon; nothing leaks into the main layer under the grid.
   procedure Test_Quick_Look_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      QL     : Quick_Look_Layout;
      Frame  : Frame_Commands;

      function Panel_Bg_In (Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector) return Boolean is
      begin
         for R of Rects loop
            if R.Color = Pane_Color and then R.X = QL.X and then R.Y = QL.Y
              and then R.Width = QL.Width and then R.Height = QL.Height
            then
               return True;
            end if;
         end loop;
         return False;
      end Panel_Bg_In;

      Icon_Overlay      : Boolean := False;
      A11y_Count       : Natural := 0;
      Dialog_Described : Boolean := False;
   begin
      Snap.Quick_Look_Open := True;
      Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
      Snap.Quick_Look_Name := To_Unbounded_String ("notes.txt");
      Snap.Quick_Look_Icon_Id := To_Unbounded_String ("document");
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      QL     := Calculate_Quick_Look_Layout (Layout, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);

      Assert (Panel_Bg_In (Frame.Overlay_Rectangles),
              "the quick look panel background is drawn in the overlay layer");
      Assert (not Panel_Bg_In (Frame.Rectangles),
              "the quick look panel background does not leak into the main layer under the grid");

      for Icon of Frame.Icons loop
         if Icon.Overlay then
            Icon_Overlay := True;
         end if;
      end loop;
      Assert (Icon_Overlay, "the quick look preview icon is flagged as an overlay icon");

      for Node of Frame.Accessibility loop
         A11y_Count := A11y_Count + 1;
         Files_Suite.Support.Assert_Inside
           (Node.X, Node.Y, Node.Width, Node.Height, QL.X, QL.Y, QL.Width, QL.Height,
            "Quick Look exposes no background accessibility nodes");
         if Node.Role = Role_Dialog
           and then Node.Description = Snap.Quick_Look_Name
         then
            Dialog_Described := True;
         end if;
      end loop;
      Assert (A11y_Count > 0, "Quick Look retains its own accessibility nodes");
      Assert
        (Dialog_Described,
         "the Quick Look dialog identifies the item currently being previewed");

      --  The generic info preview used to size its icon from width alone, so a
      --  short panel drew the icon and following metadata through its bottom
      --  border.  Every emitted preview command must fit the compact panel.
      declare
         Compact_W      : constant Natural := 160;
         Compact_H      : constant Natural := 80;
         Compact_Layout : constant Guikit.Draw.Layout_Metrics :=
           Calculate_Layout (Snap, Compact_W, Compact_H, LH);
         Compact_QL     : constant Quick_Look_Layout :=
           Calculate_Quick_Look_Layout (Compact_Layout, LH);
         Compact_Frame  : constant Frame_Commands :=
           Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
      begin
         Assert
           (Compact_QL.Content_X + Compact_QL.Content_Width
              <= Compact_QL.X + Compact_QL.Width
            and then Compact_QL.Content_Y + Compact_QL.Content_Height
              <= Compact_QL.Y + Compact_QL.Height,
            "the compact Quick Look content box stays inside its panel");
         for Icon of Compact_Frame.Icons loop
            if Icon.Overlay then
               Assert
                 (Icon.X + Icon.Size <= Compact_QL.X + Compact_QL.Width
                  and then Icon.Y + Icon.Size <= Compact_QL.Y + Compact_QL.Height,
                  "a compact Quick Look info icon stays inside the panel");
            end if;
         end loop;
         for Text of Compact_Frame.Overlay_Text loop
            Assert
              (Text.X + Text.Width <= Compact_QL.X + Compact_QL.Width
               and then Text.Y + Text.Height <= Compact_QL.Y + Compact_QL.Height,
               "compact Quick Look text stays inside the panel");
         end loop;
      end;
   end Test_Quick_Look_Drawn_In_Overlay;
