separate (Files.Rendering.Build_Frame_Commands.Draw_Toolbar)
   --  The view-mode switcher, a segmented control.
   procedure Draw_View_Switcher is
   begin
      --  The view-mode switcher is a segmented control over the view-mode region.
      declare
         --  Labels come from Files.UI.View_Mode_Segments so the widths drawn
         --  here match the widths the click hit-test measures; the renderer only
         --  adds the per-cell tooltip and enabled state.
         View_Segments : Guikit.Segmented.Segment_Vectors.Vector := Files.UI.View_Mode_Segments;
         Seg_Rects     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Seg_Text      : Guikit.Draw.Text_Command_Vectors.Vector;
         Seg_Tips      : Guikit.Draw.Tooltip_Command_Vectors.Vector;
         Seg_Nodes     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Active        : constant Natural :=
           (case Snapshot.View_Mode is
               when Files.Types.Small_Icons => 1,
               when Files.Types.Large_Icons => 2,
               when Files.Types.Details     => 3);

         procedure Enrich (Cell : Positive; Command : Files.Commands.Registered_Command_Id) is
            S : Guikit.Segmented.Segment := View_Segments.Element (Cell);
         begin
            S.Tooltip := Command_Label (Command);
            S.Enabled := Snapshot.Command_Enabled (Command);
            View_Segments.Replace_Element (Cell, S);
         end Enrich;
      begin
         Enrich (1, Files.Commands.Select_Small_Icons_Command);
         Enrich (2, Files.Commands.Select_Large_Icons_Command);
         Enrich (3, Files.Commands.Select_Details_Command);
         Guikit.Segmented.Build_Frame
           (Segments      => View_Segments,
            Active        => Active,
            Region_X      => Bottom.View_Mode_X,
            Region_Y      => Bottom_Y,
            Region_Width  => Bottom.View_Mode_Width,
            Region_Height => Layout.Bottom_Bar_Height,
            Clip_Width    => Width,
            Clip_Height   => Height,
            Line_Height   => Line_Height,
            Hover_X       => (if Has_Hover then Hover_X else -1),
            Hover_Y       => (if Has_Hover then Hover_Y else -1),
            --  Cells fill the full bar, but sit the labels on the shared bottom-bar
            --  text baseline instead of centring them in the taller cell.
            Label_Inset   => Bottom_Content_Y - Bottom_Y,
            Rectangles    => Seg_Rects,
            Text          => Seg_Text,
            Tooltips      => Seg_Tips,
            Accessibility => Seg_Nodes);
         for C of Seg_Rects loop
            Result.Rectangles.Append (C);
         end loop;
         for C of Seg_Text loop
            Result.Text.Append (C);
         end loop;
         for C of Seg_Tips loop
            Add_Tooltip_Text (C.X, C.Y, C.Width, C.Height, C.Text);
         end loop;
         for N of Seg_Nodes loop
            Add_Accessibility_Node
              (N.Role,
               N.X,
               N.Y,
               N.Width,
               N.Height,
               N.Name,
               N.Description,
               N.Enabled,
               N.Selected,
               N.Focused);
         end loop;
      end;
   end Draw_View_Switcher;
