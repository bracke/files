separate (Files.File_System.Roots)
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
         when Native_Adapter_Windows =>
            return Files.Platform.Windows.API_Profile;
         when Native_Adapter_Macos =>
            return Files.Platform.Macos.API_Profile;
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
