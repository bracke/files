--  The icon definitions files draws with: the share/files/icons/*.icon files,
--  read at runtime and served to Guikit.Draw, so the .icon files are the single
--  place icons are edited. Guikit knows no icons of its own; when a bundled file
--  is absent or unreadable this package's compiled-in copy of it is served
--  instead, so the app still shows icons without its share folder. A test holds
--  the compiled-in copies byte-for-byte equal to the .icon files.
--
--  The source is installed when this package is elaborated (and again by
--  Register), so every program that links it draws with these definitions.
package Files.Icon_Assets is

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

   --  The definition files draws an icon with: the bundled file when it reads
   --  and parses, otherwise the compiled-in copy. Cached per icon and theme.
   --  This is the function registered as the Guikit.Draw icon-definition source.
   --
   --  @param Icon_Id Bundled icon identifier (e.g. "folder").
   --  @param Theme_Name Icon theme identifier, or "" for the base set.
   --  @return The icon definition, or "" for an id or theme files does not ship.
   function Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String;

   --  Install Icon_Asset as the Guikit.Draw icon-definition source. Elaboration
   --  already does this; calling it again is harmless.
   procedure Register;

end Files.Icon_Assets;
