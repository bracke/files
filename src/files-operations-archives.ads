with Files.Model;
with Files.Settings;

--  Compressing the selection into an archive and extracting archives.
package Files.Operations.Archives is

   --  Archive container format produced by Compress_Selected.
   type Archive_Format is (Zip_Archive, Seven_Zip_Archive);

   --  Compress the selected items into a single archive in the current
   --  directory, then reload so the new archive appears and is selected.
   --  Directories are recursed; files are stored with directory-relative entry
   --  names. The archive is named after the first selected item with the
   --  format's extension (.zip / .7z), made unique if it already exists.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-compress reload.
   --  @param Format Archive container format to produce.
   --  @return Structured operation result.
   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result;

   --  Extract each selected archive (.zip or .7z) into a new directory in the
   --  current directory named after the archive's base name, made unique if it
   --  already exists, then reload so the first created directory is selected.
   --
   --  @param Model Window model providing the selection and current directory.
   --  @param Settings Settings model used for the post-extract reload.
   --  @return Structured operation result.
   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Archives;
