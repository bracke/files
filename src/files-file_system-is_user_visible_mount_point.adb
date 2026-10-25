separate (Files.File_System)
function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean is
   function Under (Container : String) return Boolean is
     (Mount_Point'Length > Container'Length + 1
      and then Mount_Point (Mount_Point'First .. Mount_Point'First + Container'Length) = Container & "/");

   Is_Container : constant Boolean :=
     Mount_Point in "/mnt" | "/media" | "/run/media" | "/Volumes" | "/System/Volumes"
     or else (Runtime_Gvfs /= "" and then Mount_Point = Runtime_Gvfs);
begin
   return not Is_Container
     and then (Mount_Point = "/"
               or else Under ("/mnt")
               or else Under ("/media")
               or else Under ("/run/media")
               or else Under ("/Volumes")
               or else Under ("/System/Volumes")
               or else (Runtime_Gvfs /= "" and then Under (Runtime_Gvfs)));
end Is_User_Visible_Mount_Point;
