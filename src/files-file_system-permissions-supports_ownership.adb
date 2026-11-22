separate (Files.File_System.Permissions)
function Supports_Ownership return Boolean is
begin
   return Hostkit.Metadata.Ownership_Supported;
end Supports_Ownership;
