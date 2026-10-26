with Hostkit.Mounts;

separate (Files.File_System)
function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is
   Found  : Boolean;
   Mount  : constant Hostkit.Mounts.Mount := Hostkit.Mounts.Find (Hostkit.Mounts.Table, Path, Found);
   Known  : Boolean;
   Result : Mount_Metadata;
begin
   if Found then
      Result.Source_Device := Mount.Source;
      Result.Filesystem_Type := Mount.Filesystem_Type;
      Result.Mount_Options := Mount.Options;
      Result.Removable := Hostkit.Mounts.Removable (To_String (Mount.Source), Known);
      Result.Removable_Known := Known;
      Result.Found := True;
   end if;
   return Result;
end Mount_Metadata_For_Root;
