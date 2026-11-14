with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

--  What the settings keep about paths: favorites, recently opened items and
--  color labels, an index of them for callers that ask about many paths,
--  and how they follow an item that is moved or removed.
package Files.Settings.Path_References is

   --  Report whether Path is currently stored in the favorites list.
   --
   --  @param Settings Settings model to query.
   --  @param Path Full item or folder path to test.
   --  @return True when Path is a stored favorite, False otherwise.
   function Is_Favorite
     (Settings : Settings_Model;
      Path     : String)
      return Boolean;

   --  Toggle Path in the favorites list, adding it when absent and removing
   --  every entry for it when present. The empty path is ignored.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path to add or remove.
   procedure Toggle_Favorite_Path
     (Settings : in out Settings_Model;
      Path     : String);

   --  Return the recently-opened paths, most-recent-first. The list is capped at
   --  Max_Recent_Items and never contains duplicates or the empty path.
   --
   --  @param Settings Settings model to query.
   --  @return Ordered recent paths, freshest first.
   function Recent_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector;

   --  Record Path as the most recently opened item: move it to the front,
   --  removing any earlier occurrence, and drop the oldest entries once the list
   --  exceeds Max_Recent_Items. The empty path is ignored. Records both files and
   --  folders.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path that was just opened.
   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String);

   --  Clear the entire recently-opened list.
   --
   --  @param Settings Settings model updated in place.
   procedure Clear_Recent
     (Settings : in out Settings_Model);

   --  Return the color label stored for Path.
   --
   --  @param Settings Settings model to query.
   --  @param Path Full item or folder path to look up.
   --  @return The stored color label, or No_Label when Path has none.
   function Label_Of
     (Settings : Settings_Model;
      Path     : String)
      return Files.Types.Color_Label;

   --  Assign Label to Path, replacing any existing label. Passing No_Label
   --  clears Path's label by removing its stored entry. The empty path is
   --  ignored.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path to label.
   --  @param Label Color label to assign, or No_Label to clear.
   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Types.Color_Label);

   --  Set_Label for each of Paths, in one pass over the stored labels: the
   --  same result as calling it per path, without a search of every label
   --  per path (labelling a large selection was quadratic).
   --
   --  @param Settings Settings model updated in place.
   --  @param Paths Full item or folder paths to label.
   --  @param Label Color label to assign, or No_Label to clear.
   procedure Set_Labels
     (Settings : in out Settings_Model;
      Paths    : String_Vectors.Vector;
      Label    : Files.Types.Color_Label);

   --  Path-keyed color labels, as indexed by Index_Paths.
   package Path_Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Files.Types.Color_Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Files.Types."=");

   --  Favorite paths, as indexed by Index_Paths.
   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   --  The favorites and labels of one settings model, hashed by path so a
   --  caller that asks about many paths (one view snapshot asks once per
   --  listed item) pays one lookup per path instead of a scan of both lists.
   --  It is a copy: build it again after the settings change.
   type Path_Index is record
      Favorites : Path_Sets.Set;
      Labels    : Path_Label_Maps.Map;
   end record;

   --  Index the favorites and labels of Settings by path.
   --
   --  @param Settings Settings model to index.
   --  @return Index answering exactly as Is_Favorite and Label_Of on Settings do.
   function Index_Paths
     (Settings : Settings_Model)
      return Path_Index;

   --  Report whether Path is a stored favorite, as Is_Favorite on the indexed
   --  settings would.
   --
   --  @param Index Index built by Index_Paths.
   --  @param Path Full item or folder path to test.
   --  @return True when Path is a stored favorite, False otherwise.
   function Is_Favorite
     (Index : Path_Index;
      Path  : String)
      return Boolean;

   --  Return the color label stored for Path, as Label_Of on the indexed
   --  settings would.
   --
   --  @param Index Index built by Index_Paths.
   --  @param Path Full item or folder path to look up.
   --  @return The stored color label, or No_Label when Path has none.
   function Label_Of
     (Index : Path_Index;
      Path  : String)
      return Files.Types.Color_Label;

   --  Follow a rename or move: every label, favorite and recent path that is
   --  From, or lies inside the folder From, is rewritten to the same place
   --  under To, so a label stays with its item and a new item at the old path
   --  does not inherit it. A rewritten favorite or recent path already listed
   --  is not listed twice, and a label left at a path a labelled entry moved
   --  onto goes: the moved entry's label holds there.
   --
   --  @param Settings Settings model updated in place.
   --  @param From Old full path of the moved item.
   --  @param To New full path of the moved item.
   --  @param Changed True when any stored path was rewritten.
   procedure Move_Path_References
     (Settings : in out Settings_Model;
      From     : String;
      To       : String;
      Changed  : out Boolean);

   --  Forget an item that is gone for good: every label, favorite and recent
   --  path that is Path, or lies inside the folder Path, is dropped, so a new
   --  item later created there does not inherit them.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full path of the removed item.
   --  @param Changed True when any stored path was dropped.
   procedure Forget_Path_References
     (Settings : in out Settings_Model;
      Path     : String;
      Changed  : out Boolean);

end Files.Settings.Path_References;
