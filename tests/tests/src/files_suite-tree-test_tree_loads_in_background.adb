with Ada.Real_Time;
with Files.Application.Tree_Reader;
with Files.Application.Window_Polls;
with Files.Model.Tree_Panel;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Tree)
   --  A window reads its tree's children on the worker: an expand only
   --  asks, the node says it is loading and keeps the children it had, and
   --  a later poll attaches the read. A folder made since shows then.
   procedure Test_Tree_Loads_In_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      use type Ada.Real_Time.Time;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Tree_Dir : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "tree");
      Seeds    : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
      Ignored  : Files.Controller.Controller_Result;
      Owner    : constant Files.Application.Tree_Reader.Requester := 7_001;

      function Names return String is
         Result : Unbounded_String;
      begin
         for R of Files.Model.Tree_Panel.Visible_Rows (Model) loop
            Append (Result, R.Name & (if R.Loading then "*" else "") & ";");
         end loop;
         return To_String (Result);
      end Names;

      --  Poll as the window loop does until the worker's read is in.
      procedure Settle is
         Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (20);
      begin
         while Files.Model.Tree_Panel.Pending_Load (Model) /= 0 and then Ada.Real_Time.Clock < Deadline loop
            Files.Application.Window_Polls.Poll_Tree_Children (Model, Settings, Owner);
            delay 0.005;
         end loop;
      end Settle;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Files_Suite.Support.Disk.Join (Tree_Dir, "old"));
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'(Path => To_Unbounded_String (Tree_Dir), Name => To_Unbounded_String ("tree")));
      Files.Model.Tree_Panel.Seed (Model, Seeds);
      Files.Model.Tree_Panel.Open (Model);
      Files.Model.Tree_Panel.Load_In_Background (Model);

      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Files_Suite.Support.Assert_Equal (Names, "tree*;", "the expand only asks: the node shows it is loading");
      Settle;
      Files_Suite.Support.Assert_Equal (Names, "tree;old;", "the read is attached on a later poll");

      Ada.Directories.Create_Path (Files_Suite.Support.Disk.Join (Tree_Dir, "new"));
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Files_Suite.Support.Assert_Equal
        (Names, "tree*;old;", "expanded again, it shows the children it had while it reads them again");
      Settle;
      Files_Suite.Support.Assert_Equal (Names, "tree;new;old;", "a folder made since shows once read");

      Ada.Directories.Delete_Tree (Tree_Dir);
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Ignored := Files.Controller.Toggle_Tree_Node (Model, Settings, 1);
      Settle;
      Files_Suite.Support.Assert_Equal
        (Names, "tree;new;old;", "a read that fails ends the loading and keeps the children");
      Assert (Files.Model.Last_Error_Key (Model) /= "", "and says why");
      Files.Application.Tree_Reader.Release (Owner);
   end Test_Tree_Loads_In_Background;
