separate (Files.File_System)
   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile is
   begin
      return
        (Permission_Errors_Recoverable => True,
         Symlink_Items_Represented     => True,
         Special_File_Items_Represented => True,
         Cross_Device_Rename_Recoverable => True,
         Trash_Preflight               => True,
         Metadata_Partial_Items        => True,
         Removable_Root_Metadata       => True,
         Native_Root_Volume_Details    => True);
   end Filesystem_Edge_Case_Profile_Of_Current_Environment;
