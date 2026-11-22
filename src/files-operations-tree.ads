with Files.File_System_Types;
with Files.Model;
with Files.Settings;

--  The folder tree and the root list: seeding the tree, loading a folder's
--  children, and where favorites go.
package Files.Operations.Tree is

   --  The filesystem roots followed by the user's favorites: what the root
   --  selector lists and the folder tree is seeded with. A favorite is
   --  labelled by its base name after the star, not by its full path.
   --
   --  @param Settings Settings holding the favorites.
   --  @return The roots, then the favorites.
   function Root_Entries_With_Favorites
     (Settings : Files.Settings.Settings_Model)
      return Files.File_System_Types.Root_Entry_Vectors.Vector;

   --  Seed the folder tree's root nodes from Root_Entries_With_Favorites,
   --  again whenever they changed (a favorite added, a volume mounted) since
   --  the tree was seeded. A root is named as the selector names it; a
   --  favorite by its path, which the tree has room for.
   --
   --  @param Model Window model whose tree is seeded.
   --  @param Settings Settings holding the favorites.
   procedure Seed_Tree
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Load a tree node's direct subdirectories and attach them in place of
   --  any it had, honouring the hidden-files setting. Run on every expand, so
   --  a folder made, renamed or removed since shows as it is now. An empty
   --  directory marks the node loaded, with no children; a read that fails
   --  (a permission change, a share that dropped out) keeps the children it
   --  had and reports why, rather than passing the folder off as empty.
   --
   --  @param Model Window model whose tree node is loaded.
   --  @param Settings Settings for the listing options.
   --  @param Node_Index The tree node to load.
   procedure Load_Tree_Children
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Positive);

   --  What a favorite points at now.
   type Favorite_Target is (Favorite_Folder, Favorite_File, Favorite_Stale);

   --  Classify a favorite path as a live folder, a live file, or a stale entry
   --  whose target no longer exists. Any lookup failure is treated as stale so a
   --  broken favorite click degrades to a no-op rather than raising.
   --
   --  @param Path The favorite's path.
   --  @return What it points at.
   function Classify_Favorite (Path : String) return Favorite_Target;

end Files.Operations.Tree;
