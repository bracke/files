--  First-implementation feature policy for files.
package Files.Features is

   type Feature_Id is
     (Drag_And_Drop,
      Thumbnail_Generation,
      Recursive_Search,
      File_Watching,
      Permanent_Delete,
      Network_Filesystem_Special_Handling,
      Shell_Open_By_Default,
      Gpu_Screenshot_Tests,
      Platform_Trash,
      Root_Discovery,
      Open_Action_Execution,
      Settings_Editing,
      Desktop_Packaging);

   --  Return whether Feature is intentionally included in the first implementation.
   --
   --  @param Feature Feature policy identifier.
   --  @return True when the feature belongs to the first implementation.
   function Included_In_First_Implementation
     (Feature : Feature_Id)
      return Boolean;

end Files.Features;
