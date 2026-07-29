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
            return "root.mount|" & Ada.Directories.Simple_Name (Path);
         when Root_User_Mount =>
            return "root.user_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Network_Mount =>
            return "root.network_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Windows_Drive =>
            return "root.drive|" & Path;
         when Root_Favorite =>
            return "root.favorite|" & Ada.Directories.Simple_Name (Path);
      end case;
   exception
      when others =>
         return Path;
   end Root_Label;
