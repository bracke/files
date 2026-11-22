with Files.File_System;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Diagnostics;

package body Files.Operations.Tree is

   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;

   function Root_Entries_With_Favorites
     (Settings : Files.Settings.Settings_Model)
      return Files.File_System_Types.Root_Entry_Vectors.Vector
   is separate;

   procedure Seed_Tree
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is separate;

   procedure Load_Tree_Children
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Positive)
   is separate;

   function Classify_Favorite (Path : String) return Favorite_Target is separate;

end Files.Operations.Tree;
