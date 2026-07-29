separate (Files.File_System)
   function Restore_From_Trash
     (Trashed_Path : String)
      return Mutation_Result
   is
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
         File   : Ada.Text_IO.File_Type;
         Result : Unbounded_String;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Info_File_Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               if Line'Length >= 5
                 and then Line (Line'First .. Line'First + 4) = "Path="
               then
                  Result := To_Unbounded_String (Url_Decode (Line (Line'First + 5 .. Line'Last)));
                  exit;
               end if;
            end;
         end loop;
         Safe_Close (File);
         return To_String (Result);
      exception
         when others =>
            Safe_Close (File);
            return "";
      end Read_Original_Path;

      Backend   : constant Trash_Backend := Trash_Backend_For_Base;
      Base      : constant String := Trash_Base_Path;
   begin
      if Base = ""
        or else Backend not in Trash_Xdg_Data_Home | Trash_Home_Data
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;

      declare
         Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
         Info_Path : constant String :=
           Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
         Original  : Unbounded_String;
         Parent    : Unbounded_String;
      begin
         if not Ada.Directories.Exists (Info_Path) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
         end if;

         Original := To_Unbounded_String (Read_Original_Path (Info_Path));
         if Length (Original) = 0 then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end if;

         Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (To_String (Original)));
         if To_String (Parent) = ""
           or else not Ada.Directories.Exists (To_String (Parent))
           or else Ada.Directories.Kind (To_String (Parent)) /= Ada.Directories.Directory
         then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
         end if;

         if Ada.Directories.Exists (To_String (Original)) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
         end if;

         begin
            Ada.Directories.Rename (Trashed_Path, To_String (Original));
         exception
            when others =>
               --  Cross-device (EXDEV): rename cannot move across filesystems,
               --  so fall back to copy-then-delete just like Move_To_Trash.
               begin
                  Copy_Tree (Trashed_Path, To_String (Original));
               exception
                  when others =>
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
               end;
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
               begin
                  if not Removed.Success then
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
                  end if;
               end;
         end;

         begin
            if Ada.Directories.Exists (Info_Path) then
               Ada.Directories.Delete_File (Info_Path);
            end if;
         exception
            when others =>
               null;
         end;

         return (Success => True, Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore_From_Trash;
