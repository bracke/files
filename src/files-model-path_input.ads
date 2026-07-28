--  The path input state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Path_Input is

   --  Focus the path input field.
   --
   --  @param Model Model to update.
   procedure Focus_Path_Input
     (Model : in out Window_Model);

   --  Set path input text.
   --
   --  @param Model Model to update.
   --  @param Text New path input text.
   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Return path input text.
   --
   --  @param Model Model to inspect.
   --  @return Current path input text.
   function Path_Input_Text
     (Model : Window_Model)
      return String;

   --  Commit path input using an externally validated path result.
   --
   --  @param Model Model to update.
   --  @param Result Validation result.
   --  @param Items Loaded destination items when Result is valid.
   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector);

   --  Return whether the path input is valid.
   --
   --  @param Model Model to inspect.
   --  @return True when no validation error is active.
   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean;

   --  Return path input validation error key.
   --
   --  @param Model Model to inspect.
   --  @return Error key or an empty string.
   function Path_Input_Error_Key
     (Model : Window_Model)
      return String;

end Files.Model.Path_Input;
