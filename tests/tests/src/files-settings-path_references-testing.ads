--  Test seam of Files.Settings.Path_References: match stored paths as a
--  host whose volumes fold names (Windows) does, on any host.
package Files.Settings.Path_References.Testing is

   --  From now on (Fold => True) stored paths are matched without regard to
   --  case, as on Windows; Fold => False puts back this host's own rule.
   --
   --  @param Fold Whether to match as a folding host.
   procedure Simulate_Folding_Host (Fold : Boolean);

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

end Files.Settings.Path_References.Testing;
