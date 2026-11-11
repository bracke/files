--  The icon themes files ships, by name: what the settings file stores, what
--  the snapshot carries and what an icon command asks Guikit.Draw for.
package Files.Icon_Themes
  with Pure
is

   type Icon_Theme is (Basic, High_Contrast);

   --  The theme's name in settings files and icon commands.
   --
   --  @param Theme An icon theme.
   --  @return "files-basic" or "files-high-contrast".
   function Image (Theme : Icon_Theme) return String is
     (case Theme is
         when Basic         => "files-basic",
         when High_Contrast => "files-high-contrast");

   --  Whether Name names a theme, ignoring case and surrounding blanks.
   --
   --  @param Name Text from a settings file.
   --  @return True when Value would accept it.
   function Is_Name (Name : String) return Boolean;

   --  The theme Name names, ignoring case and surrounding blanks.
   --
   --  @param Name Text for which Is_Name holds.
   --  @return The theme; Basic for any other text.
   function Value (Name : String) return Icon_Theme;

   --  Where the theme's .icon files sit under the bundled icons folder.
   --
   --  @param Theme An icon theme.
   --  @return "" for the base set, or a subfolder starting with "/".
   function Subdirectory (Theme : Icon_Theme) return String is
     (case Theme is
         when Basic         => "",
         when High_Contrast => "/high-contrast");

end Files.Icon_Themes;
