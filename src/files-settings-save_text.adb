with Files.Diagnostics;
with Files.Io_Errors;
separate (Files.Settings)
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      --  Publishing renames a temporary over the target, which would replace
      --  a symlinked settings file (stow, home-manager, a dotfiles repo) with
      --  a plain file and silently detach it. Write through to the link's
      --  target instead; results still name the path the user configured.
      --  Hostkit resolves it: GNAT's Normalize_Pathname follows no link on
      --  Windows, and the save replaced the link there. A dangling link has
      --  no final path; the lexical resolution names where it points.
      function Link_Target return String is
         Resolved : constant String := Hostkit.Fs.Real_Path (Path);
      begin
         return (if Resolved /= "" then Resolved else Files.Fs_Primitives.Full_Name (Path));
      end Link_Target;

      Target : constant String := (if Hostkit.Fs.Is_Link (Path) then Link_Target else Path);
      Parent : constant String := Parent_Directory (Target);
      Temp   : Unbounded_String;
      Temp_Identity : Unbounded_String;
      Publication : Files.Durable_Writes.Publication_Result :=
        Files.Durable_Writes.Not_Published;

      --  The settings text, as the bytes it is.
      procedure Write_Text (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Write (Stream, Text);
      end Write_Text;
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
      --  refusal-safe: a save replaces the file whatever is there; a target
      --  not seen only skips this guard, and the publish beside it is then
      --  refused in the same folder.
      elsif Files.Fs_Primitives.Exists (Target)
        and then Files.Fs_Primitives.Kind (Target) /= Ada.Directories.Ordinary_File
      then
            return
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      if Parent /= "" then
         --  refusal-safe: a folder not seen is made, which fails or finds it.
         if Files.Fs_Primitives.Exists (Parent) then
            if Files.Fs_Primitives.Kind (Parent) /= Ada.Directories.Directory then
               return
                 (Success   => False,
                  Durable   => False,
                  Path      => To_Unbounded_String (Path),
                  Error_Key => To_Unbounded_String ("error.settings.not_file"));
            end if;
         else
            begin
               Files.Io_Errors.Clear_Os_Error;
               Files.Fs_Primitives.Create_Path (Parent);
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
      Files.Durable_Writes.Write_Private_Temporary (Target, Write_Text'Access, Temp, Temp_Identity);
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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Settings");
         declare
            --  Why, before the cleanup below can record a cause of its own.
            Key : constant Unbounded_String := Files.Io_Errors.Error_Key ("error.settings.save");
         begin
            Files.Durable_Writes.Remove_Owned (To_String (Temp), To_String (Temp_Identity));

            return
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => Key);
         end;
   end Save_Text;
