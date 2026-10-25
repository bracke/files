separate (Files.File_System)
function Native_Platform_API_Profile_For
  (Adapter : Native_Platform_Adapter)
   return Native_Platform_API_Profile
is
   Caps : constant Root_Volume_Capabilities := Root_Volume_Capabilities_Of_Current_Environment;
begin
   case Adapter is
      when Native_Adapter_Linux =>
         return
           (Adapter               => Native_Adapter_Linux,
            Trash_Binding_Status  =>
              (if Trash_Backend_Of_Current_Environment in
                Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home
               then Native_API_Binding_Available
               else Native_API_Binding_Missing),
            Volume_Binding_Status => Caps.Native_Binding_Status,
            Trash_API_Name        => To_Unbounded_String ("freedesktop.trash"),
            Volume_API_Name       => Caps.Native_Api_Name,
            Trash_Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
            Volume_Binding_Unit   => To_Unbounded_String ("Files.File_System.Root_Volume_Details_For"),
            Required_Library      => To_Unbounded_String ("libc"),
            Required_Framework    => Null_Unbounded_String,
            --  Only when Linux really is the target. The Windows and macOS
            --  profiles already answer this from their per-OS bodies; this
            --  branch used to say True unconditionally, so on a Mac both the
            --  Linux and the macOS adapter claimed to be the current one.
            Current_Target        => Files_Config.Alire_Host_OS = "linux",
            Trash_Can_Execute     => Trash_Is_Available,
            Volume_Can_Query      => Caps.Capacity_Bytes_Known or else Caps.Filesystem_Type_Available);
      when Native_Adapter_Windows | Native_Adapter_Macos =>
         --  These were two per-OS bodies each, in four platform directories,
         --  to express one thing: whether this adapter is the build's target
         --  and whether its bindings are present. Both are answerable here --
         --  the target from the same config the project file selects sources
         --  with, the bindings from Hostkit, which owns them now.
         declare
            Windows_Adapter : constant Boolean := Adapter = Native_Adapter_Windows;
            Is_Target       : constant Boolean :=
              Files_Config.Alire_Host_OS = (if Windows_Adapter then "windows" else "macos");
            Facility        : constant Hostkit.Trash.Facility := Hostkit.Trash.Current;

            --  Only the host this was built for has the bindings compiled in;
            --  for the other adapter the honest answer is "not the target",
            --  which is what Native_API_Not_Target says.
            Binding : constant Native_API_Binding_Status :=
              (if not Is_Target then Native_API_Not_Target
               elsif Facility.Available then Native_API_Binding_Available
               else Native_API_Binding_Missing);
         begin
            return
              (Adapter               => Adapter,
               Trash_Binding_Status  => Binding,
               Volume_Binding_Status => Binding,
               --  Named by the host rather than by us. This used to say
               --  IFileOperation on Windows while the code called
               --  SHFileOperationW.
               Trash_API_Name        =>
                 (if Is_Target and then Facility.Api_Name /= Null_Unbounded_String
                  then Facility.Api_Name
                  elsif Windows_Adapter then To_Unbounded_String ("SHFileOperationW")
                  else To_Unbounded_String ("NSFileManager.trashItemAtURL")),
               Volume_API_Name       =>
                 To_Unbounded_String
                   ((if Windows_Adapter
                     then "GetVolumeInformationW+GetDiskFreeSpaceExW"
                     else "statfs")),
               Trash_Binding_Unit    => To_Unbounded_String ("Hostkit.Trash"),
               Volume_Binding_Unit   => To_Unbounded_String ("Hostkit.Metadata"),
               Required_Library      =>
                 (if Windows_Adapter
                  then To_Unbounded_String ("shell32;ole32;kernel32")
                  else Null_Unbounded_String),
               Required_Framework    =>
                 (if Windows_Adapter
                  then Null_Unbounded_String
                  else To_Unbounded_String ("Foundation")),
               Current_Target        => Is_Target,
               Trash_Can_Execute     => Is_Target and then Facility.Available,
               Volume_Can_Query      =>
                 Is_Target
                   and then (Caps.Capacity_Bytes_Known or else Caps.Filesystem_Type_Available));
         end;
      when Native_Adapter_None =>
         return
           (Adapter               => Native_Adapter_None,
            Trash_Binding_Status  => Native_API_Binding_Missing,
            Volume_Binding_Status => Native_API_Binding_Missing,
            Trash_API_Name        => To_Unbounded_String ("none"),
            Volume_API_Name       => To_Unbounded_String ("none"),
            Trash_Binding_Unit    => To_Unbounded_String ("none"),
            Volume_Binding_Unit   => To_Unbounded_String ("none"),
            Required_Library      => Null_Unbounded_String,
            Required_Framework    => Null_Unbounded_String,
            Current_Target        => False,
            Trash_Can_Execute     => False,
            Volume_Can_Query      => False);
   end case;
end Native_Platform_API_Profile_For;
