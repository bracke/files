separate (Files.File_System)
function Original_Path (Trashed_Path : String) return String is
   --  Reverse of Move_To_Trash's Trash_Info_Path_Value percent-encoder.
   function Url_Decode (Value : String) return String is
      Result : Unbounded_String;
      Index  : Natural := Value'First;

      function Hex_Value (Item : Character) return Integer is
      begin
         case Item is
            when '0' .. '9' =>
               return Character'Pos (Item) - Character'Pos ('0');
            when 'A' .. 'F' =>
               return Character'Pos (Item) - Character'Pos ('A') + 10;
            when 'a' .. 'f' =>
               return Character'Pos (Item) - Character'Pos ('a') + 10;
            when others =>
               return -1;
         end case;
      end Hex_Value;
   begin
      while Index <= Value'Last loop
         if Value (Index) = '%' and then Index + 2 <= Value'Last then
            declare
               High : constant Integer := Hex_Value (Value (Index + 1));
               Low  : constant Integer := Hex_Value (Value (Index + 2));
            begin
               if High >= 0 and then Low >= 0 then
                  Append (Result, Character'Val (High * 16 + Low));
                  Index := Index + 3;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         else
            Append (Result, Value (Index));
            Index := Index + 1;
         end if;
      end loop;

      return To_String (Result);
   end Url_Decode;

   --  Read and URL-decode the Path= value from a trashinfo sidecar.
   function Read_Original_Path (Info_File_Path : String) return String is
      Result : Unbounded_String;
      Max_Trash_Info_Bytes : constant Natural := 1024 * 1024;
      Max_Trash_Info_Line  : constant Natural := 64 * 1024;
      Read_Succeeded : Boolean;
   begin
      if Hostkit.Fs.Is_Link (Info_File_Path)
        or else not Ada.Directories.Exists (Info_File_Path)
        or else Ada.Directories.Kind (Info_File_Path) /= Ada.Directories.Ordinary_File
      then
         return "";
      end if;
      declare
         Content : constant String := Read_Preview_Text
           (Info_File_Path, Max_Trash_Info_Bytes + 1, Read_Succeeded);
         Cursor  : Positive := 1;
         Last    : Natural;
      begin
         if not Read_Succeeded
           or else Content'Length > Max_Trash_Info_Bytes
         then
            return "";
         end if;
         while Cursor <= Content'Length loop
            Last := Cursor;
            while Last <= Content'Length
              and then Content (Last) /= ASCII.LF
              and then Content (Last) /= ASCII.CR
            loop
               Last := Last + 1;
            end loop;
            declare
               Line : constant String :=
                 (if Last = Cursor then ""
                  else Content (Cursor .. Last - 1));
            begin
               if Line'Length > Max_Trash_Info_Line then
                  return "";
               elsif Line'Length >= 5
                 and then Line (Line'First .. Line'First + 4) = "Path="
               then
                  declare
                     Decoded : constant String :=
                       Url_Decode (Line (Line'First + 5 .. Line'Last));
                  begin
                     if not Valid_Original_Path (Decoded) then
                        return "";
                     end if;
                     Result := To_Unbounded_String (Decoded);
                  end;
                  exit;
               end if;
            end;
            if Last <= Content'Length then
               declare
                  First_Mark : constant Character := Content (Last);
               begin
                  Last := Last + 1;
                  if First_Mark = ASCII.CR
                    and then Last <= Content'Length
                    and then Content (Last) = ASCII.LF
                  then
                     Last := Last + 1;
                  end if;
               end;
            end if;
            Cursor := Last;
         end loop;
      end;
      return To_String (Result);
   exception
      when others =>
         return "";
   end Read_Original_Path;

   Base : constant String := Trash_Base_Path;
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
begin
   if Base = "" or else Backend not in Trash_Xdg_Data_Home | Trash_Home_Data then
      return "";
   elsif not Is_Trash_Payload (Trashed_Path, Trash_Files_Directory) then
      return "";
   end if;
   return Read_Original_Path
     (Join_Path (Join_Path (Base, "info"), Ada.Directories.Simple_Name (Trashed_Path) & ".trashinfo"));
exception
   when others => return "";
end Original_Path;
