package body Files.File_Types is

   function Trim_Name (Name : String) return String is
      First : Natural := Name'First;
      Last  : Natural := Name'Last;
   begin
      while First <= Last
        and then (Name (First) = ' '
                  or else Name (First) = ASCII.HT
                  or else Name (First) = ASCII.CR
                  or else Name (First) = ASCII.LF
                  or else Name (First) = ASCII.VT
                  or else Name (First) = ASCII.FF
                  or else Character'Pos (Name (First)) = 133)
      loop
         First := First + 1;
      end loop;

      while Last >= First
        and then (Name (Last) = ' '
                  or else Name (Last) = ASCII.HT
                  or else Name (Last) = ASCII.CR
                  or else Name (Last) = ASCII.LF
                  or else Name (Last) = ASCII.VT
                  or else Name (Last) = ASCII.FF
                  or else Character'Pos (Name (Last)) = 133)
      loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      end if;

      return Name (First .. Last);
   end Trim_Name;

   function Leaf_Name (Name : String) return String is
      Clean : constant String := Trim_Name (Name);
      First : Natural := Clean'First;
   begin
      for Index in reverse Clean'Range loop
         if Clean (Index) = '/' or else Clean (Index) = '\' then
            First := Index + 1;
            exit;
         end if;
      end loop;

      if Clean = "" or else First > Clean'Last then
         return "";
      end if;

      return Clean (First .. Clean'Last);
   end Leaf_Name;

   function Extension_Of
     (Name : String)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
      Dot : Natural := 0;
   begin
      for Index in reverse Clean'Range loop
         if Clean (Index) = '.' then
            Dot := Index;
            exit;
         end if;
      end loop;

      if Dot = 0 or else Dot = Clean'First or else Dot = Clean'Last then
         return "";
      end if;

      return Files.Settings.Normalize_Extension (Clean (Dot + 1 .. Clean'Last));
   end Extension_Of;

   function Filetype_For_Name
     (Settings : Files.Settings.Settings_Model;
      Name     : String)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
   begin
      for Index in Clean'Range loop
         if Clean (Index) = '.'
           and then Index > Clean'First
           and then Index < Clean'Last
         then
            declare
               Candidate : constant String :=
                 Files.Settings.Normalize_Extension (Clean (Index + 1 .. Clean'Last));
               Mapped    : constant String :=
                 Files.Settings.Filetype_For_Extension (Settings, Candidate);
            begin
               if Mapped /= "" then
                  return Mapped;
               end if;
            end;
         end if;
      end loop;

      return "";
   end Filetype_For_Name;

   function Detect_Filetype
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Name     : String)
      return String
   is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return "inode/directory";
         when Files.Types.Symlink_Item =>
            return "inode/symlink";
         when Files.Types.Executable_Item =>
            return "application/x-executable";
         when others =>
            declare
               Mapped : constant String := Filetype_For_Name (Settings, Name);
            begin
               if Mapped /= "" then
                  return Mapped;
               end if;
            end;
      end case;

      return "application/octet-stream";
   end Detect_Filetype;

   function Icon_Id_For
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String
   is
      Mapped : constant String := Files.Settings.Icon_For_Filetype (Settings, Filetype);
   begin
      if Mapped /= "" then
         return Mapped;
      end if;

      case Kind is
         when Files.Types.Directory_Item =>
            return "folder";
         when Files.Types.Symlink_Item =>
            return "link";
         when Files.Types.Executable_Item =>
            return "executable";
         when others =>
            return "unknown";
      end case;
   end Icon_Id_For;

end Files.File_Types;
