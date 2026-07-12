with Interfaces.C;
with System;

package body Files.Platform.Windows.Volumes is
   use type Files.File_System.Native_API_Binding_Status;

   function GetVolumeInformationW
     (Root_Path_Name          : System.Address;
      Volume_Name_Buffer     : System.Address;
      Volume_Name_Size       : Interfaces.C.unsigned;
      Volume_Serial_Number   : System.Address;
      Maximum_Component_Size : System.Address;
      File_System_Flags      : System.Address;
      File_System_Name       : System.Address;
      File_System_Name_Size  : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Import, Convention => Stdcall, External_Name => "GetVolumeInformationW";

   function GetDiskFreeSpaceExW
     (Directory_Name            : System.Address;
      Free_Bytes_Available     : System.Address;
      Total_Number_Of_Bytes    : System.Address;
      Total_Number_Of_Free_Bytes : System.Address)
      return Interfaces.C.int
     with Import, Convention => Stdcall, External_Name => "GetDiskFreeSpaceExW";

   pragma Unreferenced (GetVolumeInformationW, GetDiskFreeSpaceExW);

   function Binding_Status return Files.File_System.Native_API_Binding_Status is
   begin
      return Files.File_System.Native_API_Binding_Available;
   end Binding_Status;

   function Can_Query return Boolean is
   begin
      return Binding_Status = Files.File_System.Native_API_Binding_Available;
   end Can_Query;
end Files.Platform.Windows.Volumes;
