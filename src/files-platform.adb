with Hostkit.Host;

package body Files.Platform is
   function Current_API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      --  Report the native adapter for the host this build is for rather than
      --  always claiming Linux. Hostkit answers from the body the build chose,
      --  so no per-OS source selection is needed here. A host Hostkit has no
      --  body for keeps the Linux profile it always had.
      case Hostkit.Host.Current is
         when Hostkit.Host.Windows =>
            return Files.File_System.Native_Platform_API_Profile_For
                     (Files.File_System.Native_Adapter_Windows);
         when Hostkit.Host.MacOS =>
            return Files.File_System.Native_Platform_API_Profile_For
                     (Files.File_System.Native_Adapter_Macos);
         when Hostkit.Host.Linux | Hostkit.Host.Unsupported =>
            return Files.File_System.Native_Platform_API_Profile_For
                     (Files.File_System.Native_Adapter_Linux);
      end case;
   end Current_API_Profile;
end Files.Platform;
