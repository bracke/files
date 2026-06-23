package body Files.Features is

   function Included_In_First_Implementation
     (Feature : Feature_Id)
      return Boolean is
   begin
      case Feature is
         when Shell_Open_By_Default =>
            return False;
         when Drag_And_Drop
            | Thumbnail_Generation
            | Recursive_Search
            | File_Watching
            | Permanent_Delete
            | Network_Filesystem_Special_Handling
            | Gpu_Screenshot_Tests
            | Platform_Trash
            | Root_Discovery
            | Open_Action_Execution
            | Settings_Editing
            | Desktop_Packaging =>
            return True;
      end case;
   end Included_In_First_Implementation;

end Files.Features;
