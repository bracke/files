--  Creating a file or folder: the temporary row a new item's name is typed
--  into, before Files.Operations commits it.
package Files.Model.Creation is

   --  Begin temporary create-file state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary file name.
   --  @param Classes The maps the new row's type and icon are worked out by
   --    (Files.Settings.Classification_Of the settings in force).
   procedure Begin_Create_File
     (Model   : in out Window_Model;
      Name    : String;
      Classes : Files.File_Types.Classification);

   --  Begin temporary create-folder state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary folder name.
   --  @param Classes The maps the new row's type and icon are worked out by.
   procedure Begin_Create_Folder
     (Model   : in out Window_Model;
      Name    : String;
      Classes : Files.File_Types.Classification);

   --  Return whether a temporary create-file item is active.
   --
   --  @param Model Model to inspect.
   --  @return True when temporary item exists.
   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return whether the active temporary item creates a directory.
   --
   --  @param Model Model to inspect.
   --  @return True when the temporary item is a directory.
   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean;

   --  Return temporary item name.
   --
   --  @param Model Model to inspect.
   --  @return Temporary item name or an empty string.
   function Temporary_Item_Name
     (Model : Window_Model)
      return String;

end Files.Model.Creation;
