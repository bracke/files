with Files.File_System.Permissions;
with Hostkit.Host;
with Hostkit.Metadata;
with Files.Model.Tree_Panel;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Tree)
   --  Expanding a folder the tree can no longer read keeps the children it
   --  showed and says why: the folder is not passed off as empty, and its
   --  expander stays.
   procedure Test_Tree_Unreadable_Folder_Keeps_Children (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Tree_Dir : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "tree");
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Ignored  : Files.Controller.Controller_Result;
   begin
      --  Mode 0 is an empty DACL on Windows, which refuses listing to an
      --  elevated process too; POSIX root reads past mode 0.
      if Hostkit.Metadata.Mode_Bits_Are_Native and then Hostkit.Host.Is_Elevated then
         Files_Suite.Support.Skip
           ("Test_Tree_Unreadable_Folder_Keeps_Children", "an elevated process ignores mode 0");
         return;
      end if;
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Files_Suite.Support.Disk.Join (Tree_Dir, "alpha"));
      Ada.Directories.Create_Path (Files_Suite.Support.Disk.Join (Tree_Dir, "beta"));
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Tree_Panel.Seed (Model, Seeds);
      Files.Model.Tree_Panel.Open (Model);

      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Tree_Panel.Visible_Rows (Model).Length), 3, "the readable folder shows its two children");
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Tree_Panel.Visible_Rows (Model).Length), 1, "collapsing hides them");

      Assert
        (Files.File_System.Permissions.Set_Permissions (Tree_Dir, 8#000#).Success,
         "the folder is made unreadable");
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Assert
        (Files.File_System.Permissions.Set_Permissions (Tree_Dir, 8#755#).Success,
         "the folder is made readable again");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Tree_Panel.Visible_Rows (Model).Length), 3,
         "re-expanding an unreadable folder keeps the children it had");
      Assert (Files.Model.Tree_Panel.Visible_Rows (Model).Element (1).Has_Children, "and its expander");
      Assert (Files.Model.Last_Error_Key (Model) /= "", "and the failed read is reported");
   end Test_Tree_Unreadable_Folder_Keeps_Children;
