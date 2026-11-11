separate (Files.Rendering.Build_Snapshot_Into)
   function Filetype_Detail
     (Item : Files.Items.Directory_Item)
      return UString
   is
      --  Upper-case only ASCII letters. A byte-wise To_Upper would corrupt a
      --  UTF-8 extension: a 3-byte lead (0xE0..0xEF) falls in Latin-1's lowercase
      --  range and would be mapped, mojibaking a CJK or emoji extension.
      function Upper_Extension (Extension : String) return String is
         Result : String (Extension'Range);
      begin
         for Index in Extension'Range loop
            if Extension (Index) in 'a' .. 'z' then
               Result (Index) := Ada.Characters.Handling.To_Upper (Extension (Index));
            else
               Result (Index) := Extension (Index);
            end if;
         end loop;

         return Result;
      end Upper_Extension;

      function Extension_File_Label return UString is
         Extension : constant String := Files.File_Types.Extension_Of (To_String (Item.Name));
      begin
         if Extension = "" then
            return Cached_Text ("info.kind.file");
         end if;

         return
           To_Unbounded_String (Upper_Extension (Extension));
      end Extension_File_Label;
   begin
      case Item.Kind is
         when Files.Types.Directory_Item =>
            return Cached_Text ("info.kind.directory");
         when Files.Types.Symlink_Item =>
            return Cached_Text ("info.kind.symlink");
         when Files.Types.Executable_Item =>
            return Cached_Text ("info.kind.executable");
         when Files.Types.Regular_File_Item =>
            declare
               Key : constant String :=
                 Files.File_Types.Label_Key (Files.File_Types.Facts_For (To_String (Item.Filetype)).Label);
            begin
               if Key /= "" then
                  return Cached_Text (Key);
               end if;
            end;

            return Extension_File_Label;
         when Files.Types.Other_Item =>
            return Cached_Text ("info.kind.other");
         when Files.Types.Unknown_Item =>
            return Cached_Text ("info.kind.unknown");
      end case;

   end Filetype_Detail;
