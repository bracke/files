with Files.UTF8;

package body Files.File_Types is

   function Trim_Name (Name : String) return String is
      First_Offset      : Natural := 0;
      Last_Content_Last : Natural := 0;
   begin
      if Name = "" then
         return "";
      end if;

      while First_Offset < Name'Length loop
         declare
            Separator_Length : constant Natural := Files.UTF8.Whitespace_Separator_Length (Name, First_Offset);
         begin
            exit when Separator_Length = 0;
            First_Offset := First_Offset + Separator_Length;
         end;
      end loop;

      if First_Offset >= Name'Length then
         return "";
      end if;

      declare
         Position : Natural := First_Offset;
      begin
         while Position < Name'Length loop
            declare
               Separator_Length : constant Natural := Files.UTF8.Whitespace_Separator_Length (Name, Position);
               Next_Position    : Natural := Position;
            begin
               if Separator_Length > 0 then
                  Next_Position := Position + Separator_Length;
               else
                  Next_Position := Files.UTF8.Next_Boundary (Name, Position);
                  if Next_Position <= Position then
                     Next_Position := Position + 1;
                  end if;
                  Last_Content_Last := Name'First + Next_Position - 1;
               end if;

               Position := Next_Position;
            end;
         end loop;
      end;

      if Last_Content_Last < Name'First + First_Offset then
         return "";
      end if;

      return Name (Name'First + First_Offset .. Last_Content_Last);
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
