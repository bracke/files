--  What the suite reaches of Files.Icon_Assets that is not part of its interface.
package Files.Icon_Assets.Testing is

   --  Return the contents of the bundled .icon file for an icon id and theme, or
   --  an empty string when it cannot be read. Results (including misses) are
   --  cached, so this does no per-frame disk access.
   --
   --  @param Icon_Id Bundled icon identifier (e.g. "folder").
   --  @param Theme_Name Icon theme identifier (e.g. "files-high-contrast").
   --  @return The icon definition, or "" when the file is missing/unreadable.
   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String;

   --  Return the compiled-in copy of a bundled icon definition: the text of
   --  share/files/icons[/<theme subfolder>]/<Icon_Id>.icon.
   --
   --  @param Icon_Id Bundled icon identifier (e.g. "folder").
   --  @param Theme_Name Icon theme identifier, or "" for the base set.
   --  @return The icon definition, or "" for an id or theme files does not ship.
   function Builtin_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String;

end Files.Icon_Assets.Testing;
