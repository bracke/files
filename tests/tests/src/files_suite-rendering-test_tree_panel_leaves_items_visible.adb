separate (Files_Suite.Rendering)
   --  The folder tree takes the view's left side instead of covering it: the
   --  view starts where the panel ends, so no item lies under the panel where
   --  a marquee or the arrow keys could select it unseen.
   procedure Test_Tree_Panel_Leaves_Items_Visible (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Mode in Files.Types.View_Mode loop
         declare
            Snap   : View_Snapshot := Sample_Snapshot (40, Mode);
            Closed : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 900, 600, 20);
         begin
            Snap.Tree_Panel_Open := True;
            declare
               Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 900, 600, 20);
               Tree   : constant Tree_Panel_Layout := Calculate_Tree_Panel_Layout (Snap, Layout, 20);
               Items  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Snap, Layout, 20);
            begin
               Assert (Closed.Main_X = 0, Mode'Image & ": without the panel the view starts at the left");
               Assert (Tree.Width > 0 and then Layout.Main_X = Tree.X + Tree.Width,
                       Mode'Image & ": with it the view starts where the panel ends");
               Assert (Layout.Main_Width > 0 and then Layout.Main_Width < Closed.Main_Width,
                       Mode'Image & ": and is narrower by the panel");
               for Item of Items loop
                  Assert (Item.Width = 0 or else Item.X >= Layout.Main_X,
                          Mode'Image & ": no item lies under the panel");
               end loop;
            end;
         end;
      end loop;
   end Test_Tree_Panel_Leaves_Items_Visible;
