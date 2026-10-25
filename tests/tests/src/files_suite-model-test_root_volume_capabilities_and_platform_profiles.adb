separate (Files_Suite.Model)
   procedure Test_Root_Volume_Capabilities_And_Platform_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Volume_Caps : constant Files.File_System.Root_Volume_Capabilities :=
        Files.File_System.Root_Volume_Capabilities_Of_Current_Environment;
      Edge_Profile : constant Files.File_System.Filesystem_Edge_Case_Profile :=
        Files.File_System.Filesystem_Edge_Case_Profile_Of_Current_Environment;
      Linux_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Linux);
      Current_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.Platform.Current_API_Profile;
      Windows_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Windows);
      Macos_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Macos);
   begin
      Assert
        (not Volume_Caps.Labels_From_Platform_Api,
         "root volume capabilities do not claim platform labels yet");
      Assert (Volume_Caps.Readiness_From_Platform_Api, "root volume capabilities expose readiness checks");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Capacity_From_Platform_Api,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume capacity capability matches capacity-byte availability");
      Assert
        (Volume_Caps.Native_Binding_Status = Files.File_System.Native_API_Binding_Available,
         "current target exposes native volume binding status");
      Files_Suite.Support.Assert_Equal
        (To_String (Volume_Caps.Binding_Unit),
         "Files.File_System",
         "root volume capabilities expose binding unit");
      Assert
        (Edge_Profile.Permission_Errors_Recoverable,
         "filesystem edge-case profile records recoverable permission errors");
      Assert (Edge_Profile.Symlink_Items_Represented, "filesystem edge-case profile records symlink items");
      Assert
        (Edge_Profile.Special_File_Items_Represented,
         "filesystem edge-case profile records special file items");
      Assert
        (Edge_Profile.Cross_Device_Rename_Recoverable,
         "filesystem edge-case profile records recoverable cross-device rename failures");
      Assert (Edge_Profile.Trash_Preflight, "filesystem edge-case profile records trash preflight");
      Assert
        (Edge_Profile.Metadata_Partial_Items,
         "filesystem edge-case profile records partial metadata items");
      Assert
        (Edge_Profile.Removable_Root_Metadata,
         "filesystem edge-case profile records removable root metadata");
      Assert
        (Edge_Profile.Native_Root_Volume_Details,
         "filesystem edge-case profile records native root volume details");
      Assert
        (Linux_Profile.Adapter = Files.File_System.Native_Adapter_Linux,
         "Linux native profile identifies adapter");
      --  Exactly one adapter is the current target, and which one depends on the
      --  host. This block used to assert it was always Linux, which is why every
      --  one of these failed the moment the suite first ran on a Mac.
      Files_Suite.Support.Assert_Equal
        (Linux_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Linux),
         "the Linux profile marks itself the current target exactly on Linux");
      Files_Suite.Support.Assert_Equal
        (Windows_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Windows),
         "the Windows profile marks itself the current target exactly on Windows");
      Files_Suite.Support.Assert_Equal
        (Macos_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Macos),
         "the macOS profile marks itself the current target exactly on macOS");
      Assert (Current_Profile.Current_Target, "the current profile is the current target");
      Assert
        (Linux_Profile.Volume_Binding_Status = Volume_Caps.Native_Binding_Status,
         "Linux native profile follows volume capability binding status");
      Files_Suite.Support.Assert_Equal
        (To_String (Linux_Profile.Volume_Binding_Unit),
         "Files.File_System.Root_Volume_Details_For",
         "Linux native profile records volume binding unit");
      declare
         Host_Profile : constant Files.File_System.Native_Platform_API_Profile :=
           Files.File_System.Native_Platform_API_Profile_For (Current_Profile.Adapter);
      begin
         Assert
           (Current_Profile.Volume_Binding_Status = Host_Profile.Volume_Binding_Status,
            "platform current API profile follows host volume status");
         Files_Suite.Support.Assert_Equal
           (To_String (Current_Profile.Volume_Binding_Unit),
            To_String (Host_Profile.Volume_Binding_Unit),
            "platform current API profile exposes host binding unit");
      end;
      Assert
        (Current_Profile.Adapter = Files.File_System.Native_Adapter_Windows
         or else Windows_Profile.Trash_Binding_Status = Files.File_System.Native_API_Not_Target,
         "Windows native profile is not active off Windows");
      Files_Suite.Support.Assert_Equal
        (To_String (Windows_Profile.Trash_Binding_Unit),
         "Hostkit.Trash",
         "Windows native profile records the unit that owns the trash binding");
      Files_Suite.Support.Assert_Equal
        (To_String (Windows_Profile.Volume_API_Name),
         "GetVolumeInformationW+GetDiskFreeSpaceExW",
         "Windows native profile records volume APIs");
      Assert
        (Current_Profile.Adapter = Files.File_System.Native_Adapter_Macos
         or else Macos_Profile.Volume_Binding_Status = Files.File_System.Native_API_Not_Target,
         "macOS native profile is not active off macOS");
      Files_Suite.Support.Assert_Equal
        (To_String (Macos_Profile.Required_Framework),
         "Foundation",
         "macOS native profile names the framework its trash binding actually needs");
      --  The project file no longer selects per-OS bodies -- there are none left
      --  to select. files_suite-startup asserts the single source list.
      --  The Windows and macOS trash bindings, and the C imports behind them --
      --  SHFileOperationW, the UTF-16 path it needs, NSFileManager's trash --
      --  moved to Hostkit.Trash, and hostkit's release checker asserts each body
      --  still binds its host's call (check_hostkit's Require_Binding). It did
      --  not when these assertions were first removed from here, which is worth
      --  remembering: "the other crate checks it" is a claim to verify, not to
      --  make. What stays checkable here is that files reports which unit owns
      --  the binding, above.
      --  (The two volume imports named here were never called: the volumes bodies
      --  declared them and then pragma Unreferenced'd them. The volume query has
      --  always been the metadata one, which is Hostkit.Metadata now.)
      Assert
        (To_String (Volume_Caps.Native_Api_Name) = "none"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "sysfs",
         "root volume capabilities name adapter");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Source_Device_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume source-device availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Mount_Options_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume mount-options availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Network_Metadata_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume network metadata availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Free_Bytes_Known,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume free-byte availability follows capacity availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Inode_Count_Known,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume inode availability follows statvfs availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Read_Only_Available,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume read-only availability follows statvfs availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Name_Max_Available,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume name-limit availability follows statvfs availability");
      Assert (not Volume_Caps.Eject_Available, "root volume capabilities do not claim eject support");
   end Test_Root_Volume_Capabilities_And_Platform_Profiles;
