with Ada.Strings.Unbounded;
with Files.Platform.Windows.Trash;
with Files.Platform.Windows.Volumes;

package body Files.Platform.Windows is
   use Ada.Strings.Unbounded;

   function API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      return
        (Adapter               => Files.File_System.Native_Adapter_Windows,
         Trash_Binding_Status  => Files.Platform.Windows.Trash.Binding_Status,
         Volume_Binding_Status => Files.Platform.Windows.Volumes.Binding_Status,
         Trash_API_Name        => To_Unbounded_String ("IFileOperation"),
         Volume_API_Name       => To_Unbounded_String ("GetVolumeInformationW+GetDiskFreeSpaceExW"),
         Trash_Binding_Unit    => To_Unbounded_String ("Files.Platform.Windows.Trash"),
         Volume_Binding_Unit   => To_Unbounded_String ("Files.Platform.Windows.Volumes"),
         Required_Library      => To_Unbounded_String ("shell32;ole32;kernel32"),
         Required_Framework    => Null_Unbounded_String,
         Current_Target        => False,
         Trash_Can_Execute     => False,
         Volume_Can_Query      => Files.Platform.Windows.Volumes.Can_Query);
   end API_Profile;

   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
   begin
      return Files.Platform.Windows.Trash.Evaluate (Request);
   end Evaluate_Trash;

   function Move_To_Recycle_Bin
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Windows.Trash.Move (Request);
   end Move_To_Recycle_Bin;
end Files.Platform.Windows;
