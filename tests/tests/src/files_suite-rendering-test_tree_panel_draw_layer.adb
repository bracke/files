separate (Files_Suite.Rendering)
   --  The folder tree sits beside the view, so it is drawn with the view, not
   --  as an overlay over it; only while it picks a destination, which blocks
   --  the rest of the window, does it go above everything.
   procedure Test_Tree_Panel_Draw_Layer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width : constant Natural  := 1000;
      Height : constant Natural := 800;
      LH    : constant Positive := 20;
      Snap  : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);

      function Inside (Rects : Rectangle_Command_Vectors.Vector; Panel : Tree_Panel_Layout) return Natural is
         Count : Natural := 0;
      begin
         for R of Rects loop
            if R.X >= Panel.X and then R.X < Panel.X + Panel.Width
              and then R.Y >= Panel.Y and then R.Y < Panel.Y + Panel.Height
            then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Inside;
      --  Whether a rectangle in Rects covers exactly the panel's bounds.
      function Covers (Rects : Rectangle_Command_Vectors.Vector; Panel : Tree_Panel_Layout) return Boolean is
        (for some R of Rects =>
           R.X = Panel.X and then R.Y = Panel.Y and then R.Width = Panel.Width and then R.Height = Panel.Height);

      Row_Label : constant String := "tree-row-label";

      --  Whether a text command reading Row_Label is in Commands.
      function Has_Label (Commands : Text_Command_Vectors.Vector) return Boolean is
        (for some Command of Commands => To_String (Command.Text) = Row_Label);
   begin
      Snap.Tree_Rows.Append
        (Files.Folder_Tree.Visible_Row'
           (Node_Index => 1, Path => To_Unbounded_String ("/tree-row"), Name => To_Unbounded_String (Row_Label),
            others     => <>));
      Snap.Tree_Panel_Open := True;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, Width, Height, LH);
         Panel  : constant Tree_Panel_Layout := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
         Closed : Frame_Commands;
      begin
         Assert (Panel.Width > 0, "the tree takes the view's left side");
         Snap.Tree_Panel_Open := False;
         Closed := Build_Frame_Commands (Snap, Width, Height, LH);
         Snap.Tree_Panel_Open := True;
         Assert (Covers (Frame.Rectangles, Panel), "browsing, the tree's panel is drawn in the view's layer");
         Assert (not Covers (Closed.Rectangles, Panel), "a closed tree draws no panel");
         Files_Suite.Support.Assert_Equal
           (Inside (Frame.Overlay_Rectangles, Panel), 0, "and nothing of it is an overlay");
         Assert (Has_Label (Frame.Text), "its row labels are drawn with the view");
         Assert (not Has_Label (Frame.Overlay_Text), "and not as overlay text");
         Assert (not Has_Label (Closed.Text), "a closed tree draws no rows");
      end;
      Snap.Tree_Pick_Active := True;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, Width, Height, LH);
         Panel  : constant Tree_Panel_Layout := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         Assert (Inside (Frame.Overlay_Rectangles, Panel) > 1,
                 "picking a destination, it is drawn above the backdrop that blocks the rest");
         Assert (Has_Label (Frame.Overlay_Text), "its row labels go above the backdrop too");
         Assert (not Has_Label (Frame.Text), "and not under it");
      end;
   end Test_Tree_Panel_Draw_Layer;
