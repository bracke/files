--  Loads the bundled files-icon-v1 icon definitions from the share/files/icons
--  directory at runtime and registers them with Guikit.Draw, so the .icon files
--  are the single place icons are edited. When a file cannot be read the built-in
--  copy in Guikit.Draw is used instead, so the app still shows icons if the
--  bundled files are absent.
package Files.Icon_Assets is

   --  Return the contents of the bundled .icon file for an icon id and theme, or
   --  an empty string when it cannot be read. Results (including misses) are
   --  cached, so this does no per-frame disk access. This is the function
   --  registered as the Guikit.Draw icon-definition source.
   --
   --  @param Icon_Id Bundled icon identifier (e.g. "folder").
   --  @param Theme_Name Icon theme identifier (e.g. "files-high-contrast").
   --  @return The icon definition, or "" when the file is missing/unreadable.
   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String;

   --  Install Disk_Icon_Asset as the Guikit.Draw icon-definition source. Call once
   --  at startup before any rendering.
   procedure Register;

end Files.Icon_Assets;
