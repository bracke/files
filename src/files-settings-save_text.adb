separate (Files.Settings)
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      use type GNAT.OS_Lib.File_Descriptor;
      Parent : constant String := Parent_Directory (Path);
      Temp   : Unbounded_String;
      Temp_Identity : Unbounded_String;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;

      procedure Remove_Owned_Temp is
      begin
         if Length (Temp) > 0
           and then Length (Temp_Identity) > 0
           and then Files.File_Identities.Token (To_String (Temp)) = To_String (Temp_Identity)
         then
            if Hostkit.Fs.Is_Link (To_String (Temp)) then
               declare
                  Removed : constant Boolean := Hostkit.Fs.Delete_Link (To_String (Temp));
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            elsif Ada.Directories.Exists (To_String (Temp)) then
               Ada.Directories.Delete_File (To_String (Temp));
            end if;
         end if;
      exception
         when others =>
            null;
      end Remove_Owned_Temp;
   begin
      if Path = "" then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      if Parent /= "" then
         if Ada.Directories.Exists (Parent) then
            if Ada.Directories.Kind (Parent) /= Ada.Directories.Directory then
               return
                 (Success   => False,
                  Path      => To_Unbounded_String (Path),
                  Error_Key => To_Unbounded_String ("error.settings.not_file"));
            end if;
         else
            Ada.Directories.Create_Path (Parent);
         end if;
      end if;

      --  Write to an exclusively-created sibling temp file and atomically
      --  replace the target, so a
      --  failure partway through the write (out of space, an I/O error on
      --  removable media, the process killed mid-write) leaves the existing
      --  settings intact rather than truncating them to nothing. Exclusive
      --  creation also refuses a stale or hostile .tmp symlink instead of
      --  following it and truncating its target.
      for Index in 1 .. 9_999 loop
         declare
            Candidate : constant String :=
              Path & ".tmp" & (if Index = 1 then "" else "-" &
                Ada.Strings.Fixed.Trim (Positive'Image (Index), Ada.Strings.Both));
         begin
            Descriptor := GNAT.OS_Lib.Create_New_File (Candidate, GNAT.OS_Lib.Binary);
            if Descriptor /= GNAT.OS_Lib.Invalid_FD then
               Temp := To_Unbounded_String (Candidate);
               Temp_Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               exit;
            end if;
         end;
      end loop;
      if Descriptor = GNAT.OS_Lib.Invalid_FD or else Length (Temp_Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;

      declare
         Next : Integer := Text'First;
         Written : Integer;
      begin
         while Next <= Text'Last loop
            Written := GNAT.OS_Lib.Write
              (Descriptor, Text (Next)'Address, Text'Last - Next + 1);
            if Written <= 0 then
               raise Ada.Directories.Use_Error;
            end if;
            Next := Next + Written;
         end loop;
      end;
      declare
         Closed : Boolean;
      begin
         GNAT.OS_Lib.Close (Descriptor, Closed);
         Descriptor := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            raise Ada.Directories.Use_Error;
         end if;
      end;
      if Files.File_Identities.Token (To_String (Temp)) /= To_String (Temp_Identity)
        or else not Files.Durable_Writes.Publish (To_String (Temp), Path)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Temp := Null_Unbounded_String;
      Temp_Identity := Null_Unbounded_String;

      return
        (Success   => True,
         Path      => To_Unbounded_String (Path),
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
            Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         Remove_Owned_Temp;

         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Save_Text;
