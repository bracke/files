--  The error state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Error is

   --  Record a recoverable error key.
   --
   --  @param Model Model to update.
   --  @param Error_Key Localized error key.
   procedure Set_Error
     (Model     : in out Window_Model;
      Error_Key : String);

   --  Return the last recoverable error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Last_Error_Key
     (Model : Window_Model)
      return String;

end Files.Model.Error;
