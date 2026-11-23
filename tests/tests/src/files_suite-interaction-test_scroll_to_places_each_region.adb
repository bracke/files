with Files_Suite.Support.Models;
with Files.Text_Basics;
with Files.Model.Info_Pane;
with Files.Model.Tree_Panel;
with Files_Suite.Support.Disk;
separate (Files_Suite.Interaction)
   --  Controller.Scroll_To, which a scrollbar drag and a marquee's
   --  auto-scroll place a region by, puts the main view, the info pane and
   --  the tree panel each at the position asked, and leaves the regions
   --  with no position of their own as they are.
   procedure Test_Scroll_To_Places_Each_Region (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      for Index in 1 .. 6 loop
         declare
            Name : constant String := "root" & Files.Text_Basics.Natural_Text (Index);
            Path : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, Name);
         begin
            Ada.Directories.Create_Path (Path);
            Seeds.Append
              (Files.Folder_Tree.Entry_Seed'(Path => Ada.Strings.Unbounded.To_Unbounded_String (Path),
                  Name => Ada.Strings.Unbounded.To_Unbounded_String (Name)));
         end;
      end loop;
      Files.Model.Tree_Panel.Seed (Model, Seeds);
      Files.Model.Tree_Panel.Open (Model);
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);

      Files.Controller.Scroll_To (Model, Files.Input_Actions.Scroll_Main_View, 7);
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 7, "the main view is placed");

      Files.Controller.Scroll_To (Model, Files.Input_Actions.Scroll_Info_Pane, 2);
      Assert (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model) = 2, "the info pane is placed");

      Files.Controller.Scroll_To (Model, Files.Input_Actions.Scroll_Tree_Panel, 3);
      Assert (Files.Model.Tree_Panel.Scroll_Rows (Model) = 3, "the tree panel is placed");

      Files.Controller.Scroll_To (Model, Files.Input_Actions.Scroll_Settings_Pane, 9);
      Files.Controller.Scroll_To (Model, Files.Input_Actions.No_Scroll_Target, 9);
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 7
              and then Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model) = 2
              and then Files.Model.Tree_Panel.Scroll_Rows (Model) = 3,
              "a region with no position of its own moves none of them");
      Files_Suite.Support.Disk.Reset_Root;
   end Test_Scroll_To_Places_Each_Region;
