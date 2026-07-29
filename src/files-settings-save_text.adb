separate (Files.Settings)
   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      File   : Ada.Text_IO.File_Type;
      Parent : constant String := Parent_Directory (Path);
      Temp   : constant String := Path & ".tmp";
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

      --  Write to a sibling temp file and rename it over the target, so a
      --  failure partway through the write (out of space, an I/O error on
      --  removable media, the process killed mid-write) leaves the existing
      --  settings intact rather than truncating them to nothing. On POSIX the
      --  rename atomically replaces; where it will not replace an existing file
      --  (Windows), fall back to remove-then-rename.
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Temp);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);

      begin
         Ada.Directories.Rename (Temp, Path);
      exception
         when others =>
            if Ada.Directories.Exists (Path) then
               Ada.Directories.Delete_File (Path);
            end if;
            Ada.Directories.Rename (Temp, Path);
      end;

      return
        (Success   => True,
         Path      => To_Unbounded_String (Path),
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);

         --  Discard the temp only while the original is still in place; if the
         --  replace got as far as removing the original, the temp is now the
         --  only copy and must be kept.
         begin
            if Ada.Directories.Exists (Temp)
              and then Ada.Directories.Exists (Path)
            then
               Ada.Directories.Delete_File (Temp);
            end if;
         exception
            when others =>
               null;
         end;

         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Save_Text;
