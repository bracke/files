separate (Files.File_System)
   function Supports_Permissions return Boolean is
   begin
      return Files.Platform.Metadata.Permissions_Supported;
   end Supports_Permissions;
