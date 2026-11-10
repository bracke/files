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
   begin
      Snap.Tree_Panel_Open := True;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, Width, Height, LH);
         Panel  : constant Tree_Panel_Layout := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         Assert (Panel.Width > 0, "the tree takes the view's left side");
         Assert (Inside (Frame.Rectangles, Panel) > 0, "browsing, the tree is drawn with the view");
         Files_Suite.Support.Assert_Equal
           (Inside (Frame.Overlay_Rectangles, Panel), 0, "and nothing of it is an overlay");
      end;
      Snap.Tree_Pick_Active := True;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, Width, Height, LH);
         Panel  : constant Tree_Panel_Layout := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         Assert (Inside (Frame.Overlay_Rectangles, Panel) > 1,
                 "picking a destination, it is drawn above the backdrop that blocks the rest");
      end;
   end Test_Tree_Panel_Draw_Layer;
