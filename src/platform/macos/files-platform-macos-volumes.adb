with Interfaces.C;
with System;

package body Files.Platform.Macos.Volumes is
   type Statfs_Record is record
      Spare : Interfaces.C.char_array (1 .. 216);
   end record
     with Convention => C;

   function Statfs
     (Path   : System.Address;
      Buffer : access Statfs_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "statfs";

   function Binding_Status return Files.File_System.Native_API_Binding_Status is
      pragma Unreferenced (Statfs);
   begin
      return Files.File_System.Native_API_Binding_Available;
   end Binding_Status;

   function Can_Query return Boolean is
   begin
      return Binding_Status = Files.File_System.Native_API_Binding_Available;
   end Can_Query;
end Files.Platform.Macos.Volumes;
