with Files.Preference_Types;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

private with Hostkit.Host;

--  What the settings keep about paths: favorites, recently opened items and
--  color labels, an index of them for callers that ask about many paths,
--  and how they follow an item that is moved or removed.
--
--  On Windows, whose volumes fold names, a stored path is matched without
--  regard to case: C:\Users\Me\Notes and c:\users\me\notes are one entry,
--  however the folder was typed or a setting written. On macOS a path is
--  matched so where its volume folds names (Hostkit.Fs.Folds_Name_Case:
--  APFS and HFS+ as formatted by default), and exactly on a volume formatted
--  case-sensitive.
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

   --  Return the favorites in the order they were starred. Every way in
   --  (Parse, Toggle_Favorite_Path) refuses a path Persistent_Path_Is_Valid
   --  rejects, so each entry is one Is_Favorite answers for.
   --
   --  @param Settings Settings model to query.
   --  @return The favorite paths.
   function Favorite_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector;

   --  Return the color labels, one entry per labelled path.
   --
   --  @param Settings Settings model to query.
   --  @return The path labels.
   function Path_Labels
     (Settings : Settings_Model)
      return Path_Label_Vectors.Vector;

   --  Whether Settings holds exactly Favorites, compared in place (no copy):
   --  for checks made on every frame.
   --
   --  @param Settings Settings model to query.
   --  @param Favorites Favorite paths to compare with.
   --  @return True when the favorites equal Favorites, in order.
   function Same_Favorites
     (Settings  : Settings_Model;
      Favorites : String_Vectors.Vector)
      return Boolean;

   --  Whether Settings holds exactly Labels, compared in place (no copy).
   --
   --  @param Settings Settings model to query.
   --  @param Labels Path labels to compare with.
   --  @return True when the labels equal Labels, in order.
   function Same_Labels
     (Settings : Settings_Model;
      Labels   : Path_Label_Vectors.Vector)
      return Boolean;

   --  Which write the favorites and labels came from: equal stamps mean
   --  equal favorites and labels (a different stamp may still hold the same
   --  ones). Zero for settings whose favorites and labels no write touched.
   --
   --  @param Settings Settings model to query.
   --  @return The stamp of the last write to its favorites or labels.
   function Path_Stamp (Settings : Settings_Model) return Natural;

   --  Toggle Path in the favorites list, adding it when absent and removing
   --  it when present. An invalid path is ignored.
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

   --  Add Path as the last favorite, as a settings file lists it: an invalid
   --  path or one already a favorite is left out, so the favorites never
   --  repeat.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path read from the file.
   procedure Add_Favorite
     (Settings : in out Settings_Model;
      Path     : String);

   --  Add Path as the oldest recent item so far, as a settings file lists
   --  them (freshest first): an invalid path, one already listed, or one past
   --  Max_Recent_Items is left out.
   --
   --  @param Settings Settings model updated in place.
   --  @param Path Full item or folder path read from the file.
   procedure Add_Recent
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
      return Files.Preference_Types.Color_Label;

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
      Label    : Files.Preference_Types.Color_Label);

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
      Label    : Files.Preference_Types.Color_Label);

   --  Path-keyed color labels, as indexed by Index_Paths.
   package Path_Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Files.Preference_Types.Color_Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Files.Preference_Types."=");

   --  Where each label stands in the settings, by the form its path is
   --  matched in, as Load_Label keeps it.
   package Label_Position_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Set_Label for a settings file being read: the path is matched through
   --  Known instead of against every label read before it, so reading n labels
   --  takes n lookups, not n squared comparisons (each of which, on macOS,
   --  asks the volume whether it folds case). Known starts empty and is kept
   --  by the caller across one read; it is rebuilt whenever it does not
   --  account for every label.
   --
   --  @param Settings Settings model being read.
   --  @param Known The labels' places, by matched path.
   --  @param Path Full item or folder path to label.
   --  @param Label Color label to assign, or No_Label to clear.
   procedure Load_Label
     (Settings : in out Settings_Model;
      Known    : in out Label_Position_Maps.Map;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label);

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
      return Files.Preference_Types.Color_Label;

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

private

   --  Whether every stored path is matched without regard to case
   --  (Windows). Test seam (Files.Settings.Path_References.Testing), so the
   --  Windows matching is checked on every host.
   Folds_Paths : Boolean := Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows);

   --  Whether the host asks each path's volume instead (macOS).
   Asks_Volume : constant Boolean := Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.MacOS);

end Files.Settings.Path_References;
