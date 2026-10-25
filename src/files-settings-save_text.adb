with Files.Diagnostics;
with Files.Io_Errors;
separate (Files.Settings)
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      use type GNAT.OS_Lib.File_Descriptor;
      --  Publishing renames a temporary over the target, which would replace
      --  a symlinked settings file (stow, home-manager, a dotfiles repo) with
      --  a plain file and silently detach it. Write through to the link's
      --  target instead; results still name the path the user configured.
      Target : constant String :=
        (if Hostkit.Fs.Is_Link (Path)
         then GNAT.OS_Lib.Normalize_Pathname (Path, Resolve_Links => True)
         else Path);
      Parent : constant String := Parent_Directory (Target);
      Temp   : Unbounded_String;
      Temp_Identity : Unbounded_String;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Publication : Files.Durable_Writes.Publication_Result :=
        Files.Durable_Writes.Not_Published;

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
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Settings.Save_Text");
      end Remove_Owned_Temp;
   begin
      Files.Io_Errors.Reset;
      if Path = ""
        or else Contains_Nul (Path)
        or else Contains_Nul (Text)
        or else Text'Length > Max_Settings_Text_Bytes
      then
         return
           (Success   => False,
            Durable   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Target)
        and then Ada.Directories.Kind (Target) /= Ada.Directories.Ordinary_File
      then
            return
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      if Parent /= "" then
         if Ada.Directories.Exists (Parent) then
            if Ada.Directories.Kind (Parent) /= Ada.Directories.Directory then
               return
                 (Success   => False,
                  Durable   => False,
                  Path      => To_Unbounded_String (Path),
                  Error_Key => To_Unbounded_String ("error.settings.not_file"));
            end if;
         else
            begin
               Files.Io_Errors.Clear_Os_Error;
               Ada.Directories.Create_Path (Parent);
            exception
               when others =>
                  Files.Io_Errors.Capture;
                  raise;
            end;
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
              Target & ".tmp" & (if Index = 1 then "" else "-" &
                Ada.Strings.Fixed.Trim (Positive'Image (Index), Ada.Strings.Both));
         begin
            Descriptor := GNAT.OS_Lib.Create_New_File (Candidate, GNAT.OS_Lib.Binary);
            if Descriptor /= GNAT.OS_Lib.Invalid_FD then
               Temp := To_Unbounded_String (Candidate);
               Temp_Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               if Length (Temp_Identity) = 0 then
                  raise Ada.Directories.Use_Error;
               end if;
               Files.Private_Directories.Make_File_Private (Descriptor);
               exit;
            end if;
         end;
      end loop;
      if Descriptor = GNAT.OS_Lib.Invalid_FD or else Length (Temp_Identity) = 0 then
         --  errno still holds why the last candidate was refused.
         Files.Io_Errors.Capture;
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
               Files.Io_Errors.Capture;
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
            Files.Io_Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
      end;
      if Files.File_Identities.Token (To_String (Temp)) /= To_String (Temp_Identity) then
         raise Ada.Directories.Use_Error;
      end if;
      Publication := Files.Durable_Writes.Publish (To_String (Temp), Target);
      if not Files.Durable_Writes.Published (Publication) then
         raise Ada.Directories.Use_Error;
      end if;
      Temp := Null_Unbounded_String;
      Temp_Identity := Null_Unbounded_String;

      return
        (Success   => True,
         Durable   => Files.Durable_Writes.Durable (Publication),
         Path      => To_Unbounded_String (Path),
         Error_Key =>
           (if Files.Durable_Writes.Durable (Publication)
            then Null_Unbounded_String
            else To_Unbounded_String ("warning.settings.not_durable")));
   exception
      when others =>
         declare
            --  Why, before the cleanup below can record a cause of its own.
            Key : constant Unbounded_String := Files.Io_Errors.Error_Key ("error.settings.save");
         begin
            if Descriptor /= GNAT.OS_Lib.Invalid_FD then
               GNAT.OS_Lib.Close (Descriptor);
               Descriptor := GNAT.OS_Lib.Invalid_FD;
            end if;
            Remove_Owned_Temp;

            return
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => Key);
         end;
   end Save_Text;
