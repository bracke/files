with Files.Controller;
with Files.Model.Recent;
with Files.Input_Actions;
with Files.Model.Tree_Panel;
with Files.Settings.Path_References;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Tree)
   --  Favorites are folder-tree roots: starring or unstarring one with the
   --  tree shown reseeds it, so the tree never lists a stale set of roots.
   procedure Test_Favorite_Toggle_Reseeds_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "favorites.conf");
      Item     : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "Alpha.txt");

      procedure Run (Command : Files.Commands.Command_Id) is
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, (Kind => Files.Input_Actions.Command_Input_Action, Command => Command),
            Guikit.Input.No_Modifiers, Result);
      end Run;

      function Tree_Has_Root (Root : String) return Boolean is
      begin
         for Row of Files.Model.Tree_Panel.Visible_Rows (Model) loop
            if Row.Depth = 0 and then Ada.Strings.Unbounded.To_String (Row.Path) = Root then
               return True;
            end if;
         end loop;
         return False;
      end Tree_Has_Root;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Run (Files.Commands.Toggle_Folder_Tree_Command);
      Assert (Files.Model.Tree_Panel.Is_Seeded (Model), "the tree is shown and seeded");
      Assert (not Tree_Has_Root (Item), "the file is not a tree root before it is a favorite");

      Files_Suite.Support.Models.Select_Name (Model, "Alpha.txt");
      Run (Files.Commands.Toggle_Favorite_Command);
      Assert (Tree_Has_Root (Item), "starring it adds it to the shown tree's roots");

      Run (Files.Commands.Toggle_Favorite_Command);
      Assert (not Tree_Has_Root (Item), "unstarring it takes it out again");

      --  Every other way the favorites change has the shown tree follow too:
      --  the path bar's star, ...
      declare
         Current : constant String := Files.Model.Current_Path (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, (Kind => Files.Input_Actions.Path_Favorite_Toggle_Input_Action),
            Guikit.Input.No_Modifiers, Result);
         Assert (Tree_Has_Root (Current), "the path bar's star adds the folder to the shown tree's roots");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, (Kind => Files.Input_Actions.Path_Favorite_Toggle_Input_Action),
            Guikit.Input.No_Modifiers, Result);
         Assert (not Tree_Has_Root (Current), "the path bar's star takes it out again");
      end;

      --  ... a favorite moved or renamed, ...
      declare
         Moved    : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "Moved.txt");
         Followed : Boolean;
      begin
         Files_Suite.Support.Models.Select_Name (Model, "Alpha.txt");
         Run (Files.Commands.Toggle_Favorite_Command);
         Assert (Tree_Has_Root (Item), "the file is a tree root again");
         Files.Model.Recent.Note_Path_Move (Model, Item, Moved);
         Followed := Files.Controller.Follow_Path_Moves (Model, Settings, Path);
         Assert (Followed, "the favorite follows the move");
         Assert (Tree_Has_Root (Moved) and then not Tree_Has_Root (Item),
                 "the shown tree's root follows the moved favorite");
      end;

      --  ... and favorites changed in another window.
      declare
         Shared : Files.Settings.Settings_Model := Settings;
      begin
         Files.Settings.Path_References.Toggle_Favorite_Path (Shared, Item);
         Files.Controller.Adopt_Shared_Settings (Model, Settings, Shared);
         Assert (Tree_Has_Root (Item), "a favorite another window added is a root of the shown tree");
      end;
   end Test_Favorite_Toggle_Reseeds_Tree;
