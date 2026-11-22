with Files.File_System.Trash.Info_Codec;
with Files.Name_Parts;

separate (Files.File_System.Trash)
function Original_Path (Trashed_Path : String) return String is
   --  Read and URL-decode the Path= value from a trashinfo sidecar.
   function Read_Original_Path (Info_File_Path : String) return String is
      Result : Unbounded_String;
      Max_Trash_Info_Bytes : constant Natural := 1024 * 1024;
      Max_Trash_Info_Line  : constant Natural := 64 * 1024;
      Read_Succeeded : Boolean;
   begin
      --  refusal-safe: an info file not seen gives no original path, and
      --  a restore without one is refused.
      if Hostkit.Fs.Is_Link (Info_File_Path)
        --  refusal-safe: as above.
        or else not Files.IO.Fs_Primitives.Exists (Info_File_Path)
        or else Files.IO.Fs_Primitives.Kind (Info_File_Path) /= Ada.Directories.Ordinary_File
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
                       Files.File_System.Trash.Info_Codec.Decode (Line (Line'First + 5 .. Line'Last));
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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
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
      Real_Top : constant String := Hostkit.Fs.Canonical_Path (Top);
      Current  : Unbounded_String := To_Unbounded_String (Files.IO.Fs_Primitives.Parent_Directory (Candidate));
   begin
      if Real_Top = "" then
         return False;
      end if;
      loop
         --  refusal-safe: a refusal is told apart just below.
         if Files.IO.Fs_Primitives.Entry_Exists (To_String (Current)) then
            declare
               Real : constant String := Hostkit.Fs.Canonical_Path (To_String (Current));
            begin
               return Real /= "" and then Path_Is_Within (Real, Real_Top);
            end;
         elsif not Files.IO.Fs_Primitives.Entry_Is_Absent (To_String (Current)) then
            --  One that cannot be looked at may be the link off the volume:
            --  not passed over to an ancestor that would vouch for it.
            return False;
         end if;
         declare
            Up : constant String := Files.IO.Fs_Primitives.Parent_Directory (To_String (Current));
         begin
            exit when Up = To_String (Current);
            Current := To_Unbounded_String (Up);
         end;
      end loop;
      return False;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Stays_On_Volume;

   --  The home trash or the volume trash that holds it.
   Base : constant String := Trash_Base_Of (Trashed_Path);
begin
   --  A Recycle Bin item's $I record says where it came from.
   if Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin then
      declare
         Item : Hostkit.Trash.Recycle_Bin_Entry;
      begin
         if Hostkit.Trash.Entry_Of (Trashed_Path, Item) and then Valid_Original_Path (To_String (Item.Original_Path))
         then
            return To_String (Item.Original_Path);
         end if;
         return "";
      end;
   elsif Base = "" then
      return "";
   end if;
   declare
      Recorded : constant String := Read_Original_Path
        (Trash_Info_Path (Base, Files.Name_Parts.Leaf_Of (Trashed_Path)));
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
            else Hostkit.Fs.Join (Top, Recorded));
      begin
         if Candidate = "" or else not Stays_On_Volume (Candidate, Top) then
            return "";
         end if;
         return Candidate;
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Original_Path;
