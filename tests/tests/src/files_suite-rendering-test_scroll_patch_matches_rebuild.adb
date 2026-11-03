separate (Files_Suite.Rendering)
   --  The window patches a snapshot's three scroll fields when only a scroll
   --  offset moved (Snapshot_Policy.Patch_Scroll). That is right only if every
   --  scroll setter moves Scroll_Revision and not Revision, and if those three
   --  fields are all a scroll changes in a snapshot.
   procedure Test_Scroll_Patch_Matches_Rebuild (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;

      procedure Check (Step : String; Change : not null access procedure) is
         Patched  : Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
         Revision : constant Natural := Files.Model.Revision (Model);
         Scroll   : constant Natural := Files.Model.Scroll_Revision (Model);
         function Offsets return String is
           (Files.Model.Main_View_Scroll_Lines (Model)'Image & Files.Model.Info_Pane_Scroll_Lines (Model)'Image
            & Files.Model.Tree_Panel_Scroll_Rows (Model)'Image);
         Before   : constant String := Offsets;
      begin
         Change.all;
         --  Each step really scrolls: a step that moved nothing would prove
         --  nothing about the patch.
         Assert (Offsets /= Before, Step & ": an offset moves");
         Files_Suite.Support.Assert_Equal (Files.Model.Revision (Model), Revision, Step & ": the revision stays");
         Assert
           ((Files.Model.Scroll_Revision (Model) /= Scroll) = (Offsets /= Before),
            Step & ": the scroll revision moves exactly when an offset did");
         --  What Refresh_Snapshot does for Patch_Scroll.
         Patched.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
         Patched.Info_Pane_Scroll_Lines := Files.Model.Info_Pane_Scroll_Lines (Model);
         Patched.Tree_Panel_Scroll_Rows := Files.Model.Tree_Panel_Scroll_Rows (Model);
         Assert
           (Patched = Files.Rendering.Build_Snapshot (Model, Settings),
            Step & ": the patched snapshot is the rebuilt one");
      end Check;

      procedure Main is begin Files.Model.Scroll_Main_View (Model, 2); end Main;
      procedure Main_Set is begin Files.Model.Set_Main_View_Scroll_Lines (Model, 0); end Main_Set;
      procedure Info is begin Files.Model.Scroll_Info_Pane (Model, 3); end Info;
      procedure Info_Set is begin Files.Model.Set_Info_Pane_Scroll_Lines (Model, 0); end Info_Set;
      procedure Tree is begin Files.Model.Scroll_Tree_Panel (Model, 1); end Tree;
      procedure Tree_Set is begin Files.Model.Set_Tree_Panel_Scroll_Rows (Model, 0); end Tree_Set;
   begin
      --  Enough rows that the view really scrolls.
      declare
         Items : Files.Items.Item_Vectors.Vector;
      begin
         for Index in 1 .. 60 loop
            Items.Append
              (Files.File_System.Make_Item
                 (Files_Suite.Support.Root, "row" & Index'Image, Files.Types.Regular_File_Item, "text/plain"));
         end loop;
         Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      end;
      --  The info pane and the tree scroll only while open, and the tree only
      --  when it has rows to scroll through.
      Files.Model.Open_Tree_Panel (Model);
      declare
         Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      begin
         for Index in 1 .. 8 loop
            Roots.Append
              (Files.Folder_Tree.Entry_Seed'
                 (Path =>
                    To_Unbounded_String (Files_Suite.Support.Join (Files_Suite.Support.Root, "dir" & Index'Image)),
                  Name => To_Unbounded_String ("dir" & Index'Image)));
         end loop;
         Files.Model.Seed_Tree (Model, Roots);
      end;
      Files.Model.Select_Visible (Model, 1);
      if not Files.Model.Info_Pane_Is_Open (Model) then
         Files.Model.Toggle_Info_Pane (Model);
      end if;
      Check ("scroll the view", Main'Access);
      Check ("set the view's offset", Main_Set'Access);
      Check ("scroll the info pane", Info'Access);
      Check ("set the info pane's offset", Info_Set'Access);
      Check ("scroll the tree", Tree'Access);
      Check ("set the tree's offset", Tree_Set'Access);

      --  Opening the tree is no scroll: it changes what is shown.
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Close_Tree_Panel (Model);
         Assert (Files.Model.Revision (Model) /= Revision, "closing the tree moves the revision");
      end;
   end Test_Scroll_Patch_Matches_Rebuild;
