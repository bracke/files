separate (Files.File_System)
   function Supports_Ownership return Boolean is
   begin
      return Files.Platform.Metadata.Ownership_Supported;
   end Supports_Ownership;
