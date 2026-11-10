separate (Files_Suite.Interaction)
   --  Favorites are folder-tree roots: starring or unstarring one with the
   --  tree shown reseeds it, so the tree never lists a stale set of roots.
   procedure Test_Favorite_Toggle_Reseeds_Tree (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "favorites.conf");
      Item     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt");

      procedure Run (Command : Files.Commands.Command_Id) is
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, (Kind => Files.Events.Command_Input_Action, Command => Command),
            Base_Font, Guikit.Input.No_Modifiers, Result);
      end Run;

      function Tree_Has_Root (Root : String) return Boolean is
      begin
         for Row of Files.Model.Tree_Visible_Rows (Model) loop
            if Row.Depth = 0 and then Ada.Strings.Unbounded.To_String (Row.Path) = Root then
               return True;
            end if;
         end loop;
         return False;
      end Tree_Has_Root;
   begin
      Files_Suite.Support.Reset_Root;
      Run (Files.Commands.Toggle_Folder_Tree_Command);
      Assert (Files.Model.Tree_Is_Seeded (Model), "the tree is shown and seeded");
      Assert (not Tree_Has_Root (Item), "the file is not a tree root before it is a favorite");

      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Run (Files.Commands.Toggle_Favorite_Command);
      Assert (Tree_Has_Root (Item), "starring it adds it to the shown tree's roots");

      Run (Files.Commands.Toggle_Favorite_Command);
      Assert (not Tree_Has_Root (Item), "unstarring it takes it out again");
   end Test_Favorite_Toggle_Reseeds_Tree;
