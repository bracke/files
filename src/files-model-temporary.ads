--  The temporary state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Temporary is

   --  Begin temporary create-file state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary file name.
   procedure Begin_Create_File
     (Model : in out Window_Model;
      Name  : String);

   --  Begin temporary create-folder state and enter rename mode.
   --
   --  @param Model Model to update.
   --  @param Name Temporary folder name.
   procedure Begin_Create_Folder
     (Model : in out Window_Model;
      Name  : String);

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

   --  Cancel temporary create-file state.
   --
   --  @param Model Model to update.
   procedure Cancel_Create_File
     (Model : in out Window_Model);

end Files.Model.Temporary;
