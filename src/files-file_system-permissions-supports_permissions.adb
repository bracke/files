separate (Files.File_System.Permissions)
function Supports_Permissions return Boolean is
begin
   return Hostkit.Metadata.Permissions_Supported;
end Supports_Permissions;
