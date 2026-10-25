separate (Files_Suite.Rendering)
   --  Folder-tree sidebar.
   procedure Test_Folder_Tree_Close_Button_Layering (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      Panel  : Tree_Panel_Layout;
      Rows   : Tree_Row_Layout_Vectors.Vector;
      Close  : Close_Button_Layout;
      Frame  : Frame_Commands;
   begin
      Snap.Tree_Panel_Open := True;
      Snap.Tree_Rows.Append
        (Files.Folder_Tree.Visible_Row'
           (Node_Index   => 1,
            Path         => To_Unbounded_String ("/deep"),
            Name         => To_Unbounded_String ("deep"),
            Depth        => 20,
            Expanded     => False,
            Loaded       => True,
            Has_Children => True));
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Panel  := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
      Rows   := Calculate_Tree_Row_Layout (Snap, Panel, LH);
      Close  := Panel_Close_Button (Panel.X, Panel.Y, Panel.Width, Panel.Height, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
      Assert (Close.Visible, "the folder tree hosts a close button");
      Assert
        (Has_Close_Button_Node (Frame, Close),
         "the open folder tree emits a close-button accessibility node");
      Assert
        (not Rows.Is_Empty
         and then Rows.First_Element.Triangle_W = 0,
         "a deeply indented expander clipped outside the sidebar is not clickable");

      --  The tree can remain visible beneath the modal settings pane. Its
      --  close button must not receive a click through that overlay.
      Snap.Settings_Pane_Open := True;
      Frame := Build_Frame_Commands (Snap, Width, Height, LH);
      declare
         Covered_Close : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snap, Frame,
              Close.X + Close.Width / 2,
              Close.Y + Close.Height / 2,
              Width, Height, Line_Height => LH);
      begin
         Assert
           (Covered_Close.Kind /= Files.Events.Command_Input_Action
            or else Covered_Close.Command /= Files.Commands.Toggle_Folder_Tree_Command,
            "the modal settings pane owns clicks above the visible folder tree");
      end;

      --  Quick Look is a higher modal layer than the persistent tree. It
      --  clears the tree from the active accessibility surface after the
      --  tree has been drawn underneath it.
      Snap.Settings_Pane_Open := False;
      Snap.Quick_Look_Open := True;
      Snap.Quick_Look_Name := To_Unbounded_String ("preview.txt");
      Frame := Build_Frame_Commands (Snap, Width, Height, LH);
      declare
         Tree_Accessible : Boolean := False;
      begin
         for Node of Frame.Accessibility loop
            Tree_Accessible :=
              Tree_Accessible
              or else To_String (Node.Name) =
                Files.Localization.Text ("accessibility.tree_panel");
         end loop;
         Assert
           (not Tree_Accessible,
            "Quick Look hides the covered folder tree from accessibility");
      end;
   end Test_Folder_Tree_Close_Button_Layering;
