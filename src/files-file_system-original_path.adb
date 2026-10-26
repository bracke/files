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
                     --  Relative is resolved, and checked, by the caller.
                     if Decoded = "" or else (for some Item of Decoded => Item = ASCII.NUL) then
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

   --  Whether Value climbs out of where it is resolved (a ".." part).
   function Climbs (Value : String) return Boolean is
     (Value = ".." or else Ada.Strings.Fixed.Index (Value, "../") = Value'First
      or else Ada.Strings.Fixed.Index (Value, "/../") > 0
      or else (Value'Length >= 3 and then Value (Value'Last - 2 .. Value'Last) = "/.."));

   --  Whether Candidate, with every link on the way resolved, is still on the
   --  volume: a folder on a crafted stick that links to ~/.ssh must not let a
   --  restore publish there. Its nearest existing ancestor is resolved and
   --  must be Top itself or below it.
   function Stays_On_Volume (Candidate, Top : String) return Boolean is
      Real_Top : constant String := Hostkit.Fs.Real_Path (Top);
      Current  : Unbounded_String := To_Unbounded_String (Ada.Directories.Containing_Directory (Candidate));
   begin
      if Real_Top = "" then
         return False;
      end if;
      loop
         if Ada.Directories.Exists (To_String (Current)) or else Hostkit.Fs.Is_Link (To_String (Current)) then
            declare
               Real : constant String := Hostkit.Fs.Real_Path (To_String (Current));
            begin
               return Real /= "" and then (Real = Real_Top or else Relative_To_Top (Real, Real_Top) /= "");
            end;
         end if;
         declare
            Up : constant String := Ada.Directories.Containing_Directory (To_String (Current));
         begin
            exit when Up = To_String (Current);
            Current := To_Unbounded_String (Up);
         end;
      end loop;
      return False;
   exception
      when others => return False;
   end Stays_On_Volume;

   --  The home trash or the volume trash that holds it.
   Base : constant String := Trash_Base_Of (Trashed_Path);
begin
   if Base = "" then
      return "";
   end if;
   declare
      Recorded : constant String := Read_Original_Path
        (Join_Path (Join_Path (Base, "info"), Ada.Directories.Simple_Name (Trashed_Path) & ".trashinfo"));
   begin
      if Recorded = "" then
         return "";
      elsif Base = Trash_Base_Path then
         --  The home trash records absolute paths.
         return (if Valid_Original_Path (Recorded) then Recorded else "");
      end if;
      --  A volume trash records paths relative to the volume's top (as gio
      --  and KIO write them, and as Move_To_Trash does), so they survive the
      --  volume being mounted elsewhere. An absolute one must stay on the
      --  volume: a crafted stick must not pick where a restore lands.
      declare
         Top       : constant String := Volume_Trash_Top (Base);
         Candidate : constant String :=
           (if Climbs (Recorded) then ""
            elsif GNAT.OS_Lib.Is_Absolute_Path (Recorded)
            then (if Relative_To_Top (Recorded, Top) /= "" then Recorded else "")
            else Join_Path (Top, Recorded));
      begin
         if Candidate = "" or else not Stays_On_Volume (Candidate, Top) then
            return "";
         end if;
         return Candidate;
      end;
   end;
exception
   when others => return "";
end Original_Path;
