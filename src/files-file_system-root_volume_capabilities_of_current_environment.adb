separate (Files.File_System)
   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities is
      Has_Proc_Mounts : constant Boolean := Ada.Directories.Exists ("/proc/mounts");
      Has_Sys_Block   : constant Boolean := Ada.Directories.Exists ("/sys/block");
      Has_Statvfs     : constant Boolean :=
        Files.Platform.Metadata.Volume_Capacity_Of ("/").Available;
   begin
      return
        (Labels_From_Platform_Api    => False,
         Readiness_From_Platform_Api => True,
         Removable_From_Platform_Api => Has_Sys_Block,
         Capacity_From_Platform_Api  => Has_Statvfs,
         Filesystem_Type_Available   => Has_Proc_Mounts,
         Eject_Available             => False,
         Native_Api_Name             =>
           To_Unbounded_String
             ((if Has_Statvfs and then Has_Proc_Mounts and then Has_Sys_Block then
                  "statvfs+proc.mounts+sysfs"
               elsif Has_Statvfs and then Has_Proc_Mounts then "statvfs+proc.mounts"
               elsif Has_Statvfs then "statvfs"
               elsif Has_Proc_Mounts and then Has_Sys_Block then "proc.mounts+sysfs"
               elsif Has_Proc_Mounts then "proc.mounts"
               elsif Has_Sys_Block then "sysfs"
               else "none")),
         Native_Binding_Status       =>
           (if Has_Statvfs or else Has_Proc_Mounts or else Has_Sys_Block
            then Native_API_Binding_Available
            else Native_API_Binding_Missing),
         Binding_Unit                => To_Unbounded_String ("Files.File_System"),
         Source_Device_Available     => Has_Proc_Mounts,
         Mount_Options_Available     => Has_Proc_Mounts,
         Network_Metadata_Available  => Has_Proc_Mounts,
         Removable_Status_Available  => Has_Sys_Block,
         Capacity_Bytes_Known        => Has_Statvfs,
         Free_Bytes_Known            => Has_Statvfs,
         Inode_Count_Known           => Has_Statvfs,
         Read_Only_Available         => Has_Statvfs,
         Name_Max_Available          => Has_Statvfs);
   end Root_Volume_Capabilities_Of_Current_Environment;
