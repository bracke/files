separate (Files.File_System)
   function Trash_Files_Directory return String is
      Base    : constant String := Trash_Base_Path;
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
   begin
      if Base = "" then
         return "";
      end if;

      case Backend is
         when Trash_Macos_Home =>
            return Base;
         when Trash_Xdg_Data_Home | Trash_Home_Data =>
            return Join_Path (Base, "files");
         when others =>
            return "";
      end case;
   exception
      when others =>
         return "";
   end Trash_Files_Directory;
