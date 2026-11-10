with Hostkit.Mounts;
separate (Files.File_System)
--  Whether a mount is a volume a person put there: one inside a folder the
--  host mounts volumes in (Hostkit.Mounts.Volume_Places) or the session's
--  gvfs folder, but not that folder itself.
function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean is
   function Under (Container : String) return Boolean is
     (Mount_Point'Length > Container'Length + 1
      and then Mount_Point (Mount_Point'First .. Mount_Point'First + Container'Length) = Container & "/");
begin
   if Mount_Point = "/" then
      return True;
   elsif Runtime_Gvfs /= "" and then Under (Runtime_Gvfs) then
      return True;
   end if;
   for Place of Hostkit.Mounts.Volume_Places loop
      if Hostkit.Mounts."/=" (Place.Kind, Hostkit.Mounts.Drive_Root)
        and then Under (To_String (Place.Path))
      then
         return True;
      end if;
   end loop;
   return False;
end Is_User_Visible_Mount_Point;
