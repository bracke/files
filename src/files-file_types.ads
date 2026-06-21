with Files.Settings;
with Files.Types;

--  Filetype detection and icon classification.
package Files.File_Types is

   --  Return the extension of Name without the dot.
   --
   --  @param Name File name to inspect.
   --  @return Lower-case extension without a leading dot.
   function Extension_Of
     (Name : String)
      return String;

   --  Determine a filetype from item kind, file name, and settings mappings.
   --
   --  @param Settings Settings model containing extension mappings.
   --  @param Kind Filesystem item kind.
   --  @param Name File name to inspect.
   --  @return Filetype identifier.
   function Detect_Filetype
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Name     : String)
      return String;

   --  Determine an icon identifier from item kind, filetype, and settings mappings.
   --
   --  @param Settings Settings model containing icon mappings.
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier.
   --  @return Icon identifier.
   function Icon_Id_For
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String;

end Files.File_Types;
