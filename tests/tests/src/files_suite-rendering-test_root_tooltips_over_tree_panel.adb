separate (Files_Suite.Rendering)
   --  The root selector opens over the folder-tree panel. Its rows' tooltips
   --  are its own, registered after the covered controls' were dropped: they
   --  show over the panel like anywhere else.
   procedure Test_Root_Tooltips_Over_Tree_Panel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap   : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout : Guikit.Draw.Layout_Metrics;
      Root   : Root_Selector_Layout;
      Tree   : Tree_Panel_Layout;
      Rows   : Root_Path_Layout_Vectors.Vector;
   begin
      Snap.Tree_Panel_Open := True;
      Snap.Root_Selector_Open := True;
      Snap.Root_Selected_Index := 1;
      Snap.Root_Paths.Append (To_Unbounded_String ("/"));
      Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));
      Layout := Calculate_Layout (Snap, 640, 480, 20);
      Root := Calculate_Root_Selector_Layout (Snap, Layout, 20);
      Rows := Calculate_Root_Path_Layout (Snap, Root);
      Tree := Calculate_Tree_Panel_Layout (Snap, Layout, 20);
      declare
         Row : constant Root_Path_Layout := Rows.First_Element;
         X   : constant Natural := Row.X + Natural'Min (Row.Width, Tree.Width) / 2;
         Y   : constant Natural := Row.Y + Row.Height / 2;
         function Texts (Hover : Boolean) return Natural is
           (Natural (Build_Frame_Commands
              (Snap, 640, 480, 20,
               Pointer => (Hover_X => X, Hover_Y => Y, Has_Hover => Hover, others => <>)).Overlay_Text.Length));
      begin
         Assert (X >= Tree.X and then X < Tree.X + Tree.Width and then Y >= Tree.Y and then Y < Tree.Y + Tree.Height,
                 "the probed root row lies over the tree panel");
         Assert (Texts (Hover => True) > Texts (Hover => False),
                 "hovering a root row over the tree panel shows its tooltip");
      end;
   end Test_Root_Tooltips_Over_Tree_Panel;
