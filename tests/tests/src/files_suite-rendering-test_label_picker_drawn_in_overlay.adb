separate (Files_Suite.Rendering)
   --  File icons are submitted after main-layer rectangles and text.  A
   --  floating picker therefore has to live wholly in the overlay layer or a
   --  grid icon beneath it can punch through the panel.
   procedure Test_Label_Picker_Drawn_In_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      Picker : Label_Picker_Layout;
      Frame  : Frame_Commands;
      A11y_Count : Natural := 0;

      function Panel_Bg_In (Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector) return Boolean is
      begin
         for Rect of Rects loop
            if Rect.Color = Pane_Color
              and then Rect.X = Picker.X
              and then Rect.Y = Picker.Y
              and then Rect.Width = Picker.Width
              and then Rect.Height = Picker.Height
            then
               return True;
            end if;
         end loop;
         return False;
      end Panel_Bg_In;
   begin
      Snap.Label_Picker_Open := True;
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Picker := Calculate_Label_Picker_Layout (Layout, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);

      Assert
        (Panel_Bg_In (Frame.Overlay_Rectangles),
         "the label picker panel background is drawn in the overlay layer");
      Assert
        (not Panel_Bg_In (Frame.Rectangles),
         "the label picker panel background does not remain beneath grid icons");
      for Node of Frame.Accessibility loop
         A11y_Count := A11y_Count + 1;
         Files_Suite.Support.Assert_Inside
           (Node.X, Node.Y, Node.Width, Node.Height, Picker.X, Picker.Y, Picker.Width, Picker.Height,
            "the label picker exposes no background accessibility nodes");
      end loop;
      Assert
        (A11y_Count > 1,
         "the label picker retains its dialog and color-choice accessibility nodes");

      --  A compact window clips the panel itself.  Its swatches and assistive
      --  hit regions must shrink with it instead of retaining desktop-sized
      --  geometry outside the visible panel.
      declare
         Compact_W      : constant Natural := 160;
         Compact_H      : constant Natural := 55;
         Compact_Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Compact_Layout : Guikit.Draw.Layout_Metrics;
         Compact_Picker : Label_Picker_Layout;
         Compact_Frame  : Frame_Commands;
      begin
         Compact_Snap.Label_Picker_Open := True;
         Compact_Layout := Calculate_Layout (Compact_Snap, Compact_W, Compact_H, LH);
         Compact_Picker := Calculate_Label_Picker_Layout (Compact_Layout, LH);
         Compact_Frame := Build_Frame_Commands (Compact_Snap, Compact_W, Compact_H, LH);

         Assert
           (Compact_Picker.Swatch_Size > 0,
            "a compact but usable picker retains visible color swatches");
         for Swatch of Compact_Picker.Swatches loop
            Files_Suite.Support.Assert_Inside
              (Swatch.X, Swatch.Y, Swatch.Width, Swatch.Height,
               Compact_Picker.X, Compact_Picker.Y, Compact_Picker.Width, Compact_Picker.Height,
               "every compact color swatch stays inside the picker panel");
         end loop;
         for Node of Compact_Frame.Accessibility loop
            Files_Suite.Support.Assert_Inside
              (Node.X, Node.Y, Node.Width, Node.Height,
               Compact_Picker.X, Compact_Picker.Y, Compact_Picker.Width, Compact_Picker.Height,
               "compact picker accessibility regions stay inside the visible panel");
         end loop;
      end;
   end Test_Label_Picker_Drawn_In_Overlay;
