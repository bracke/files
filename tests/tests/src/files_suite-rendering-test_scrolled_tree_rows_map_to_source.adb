separate (Files_Suite.Rendering)
   --  A scrolled destination tree maps its clipped layout rows back to the
   --  correct source rows and leaves the picker footer unobstructed.
   procedure Test_Scrolled_Tree_Rows_Map_To_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      LH     : constant Positive := 20;
      Snap       : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout     : Guikit.Draw.Layout_Metrics;
      Panel      : Tree_Panel_Layout;
      Buttons    : Tree_Pick_Button_Layout;
      Rows       : Tree_Row_Layout_Vectors.Vector;
      Frame      : Frame_Commands;
      Fourth_Seen : Boolean := False;
   begin
      Snap.Tree_Panel_Open := True;
      Snap.Tree_Pick_Active := True;
      Snap.Tree_Panel_Scroll_Rows := 3;
      for Index in 1 .. 12 loop
         Snap.Tree_Rows.Append
           (Files.Folder_Tree.Visible_Row'
              (Node_Index   => Index,
               Path         => To_Unbounded_String
                 ("/tree/" & Natural'Image (Index)),
               Name         => To_Unbounded_String
                 ("tree-row" & Natural'Image (Index)),
               Depth        => 0,
               Expanded     => False,
               Loaded       => True,
               Has_Children => False));
      end loop;

      Layout  := Calculate_Layout (Snap, Width, 200, LH);
      Panel   := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
      Buttons := Tree_Pick_Buttons (Panel, LH);
      Rows    := Calculate_Tree_Row_Layout (Snap, Panel, LH);
      Frame   := Build_Frame_Commands (Snap, Width, 200, LH);

      Assert (not Rows.Is_Empty, "tree scrolling lays out the requested source row first (any rows)");
      Files_Suite.Support.Assert_Equal
        (Rows.First_Element.Visible_Row_Index, 4,
         "tree scrolling lays out the requested source row first (visible row index)");
      Files_Suite.Support.Assert_Equal
        (Rows.First_Element.Node_Index, 4, "tree scrolling lays out the requested source row first (node index)");
      Assert (Panel.Scrollbar_Visible, "an overflowing tree exposes a bounded scrollbar thumb (visible)");
      Assert (Panel.Scrollbar_Height > 0, "an overflowing tree exposes a bounded scrollbar thumb (thumb height)");
      Assert
        (Panel.Scrollbar_Track_Height > Panel.Scrollbar_Height,
         "an overflowing tree exposes a bounded scrollbar thumb (thumb shorter than track)");
      Assert
        (not Buttons.Visible
         or else Panel.Scrollbar_Y + Panel.Scrollbar_Track_Height <= Buttons.Y,
         "the tree scrollbar track stays above the destination-picker footer");
      for Row of Rows loop
         Assert
           (not Buttons.Visible
            or else Row.Y + Row.Height <= Buttons.Y,
            "scrolled destination rows stay above the picker button bar");
      end loop;
      for Node of Frame.Accessibility loop
         if To_String (Node.Name) = "tree-row 4" then
            Fourth_Seen := True;
         end if;
      end loop;
      Assert
        (Fourth_Seen,
         "rendering and accessibility use the scrolled row's source data");
   end Test_Scrolled_Tree_Rows_Map_To_Source;
