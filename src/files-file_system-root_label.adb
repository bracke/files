separate (Files.File_System)
function Root_Label (Path : String; Kind : Root_Kind) return String is
begin
   case Kind is
      when Root_Filesystem =>
         return (if Path = "/" then "root.filesystem" else Path);
      when Root_Home =>
         return "root.home";
      when Root_Current =>
         return "root.current";
      when Root_Mount =>
         return "root.mount";
      when Root_User_Mount =>
         return "root.user_mount";
      when Root_Network_Mount =>
         return "root.network_mount";
      when Root_Windows_Drive =>
         return "root.drive";
      when Root_Favorite =>
         return "root.favorite";
   end case;
end Root_Label;
