package body Files.Platform.Windows.Volumes is
   function Binding_Status return Files.File_System.Native_API_Binding_Status is
   begin
      return Files.File_System.Native_API_Not_Target;
   end Binding_Status;

   function Can_Query return Boolean is
   begin
      return False;
   end Can_Query;
end Files.Platform.Windows.Volumes;
