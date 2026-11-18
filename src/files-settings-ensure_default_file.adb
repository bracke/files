with Files.Diagnostics;
separate (Files.Settings)
   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result
   is
   begin
      if Path = "" then
         return
           (Success   => False,
            Durable   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif not Files.Fs_Primitives.Entry_Is_Absent (Path) then
         --  Seeded only where surely nothing is: a settings file that cannot
         --  be looked at raises here (Kind) and is never replaced by the
         --  defaults.
         if Files.Fs_Primitives.Kind (Path) = Ada.Directories.Ordinary_File then
            return
              (Success   => True,
               Durable   => True,
               Path      => To_Unbounded_String (Path),
               Error_Key => Null_Unbounded_String);
         else
            return
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => To_Unbounded_String ("error.settings.not_file"));
         end if;
      end if;

      return Save_Text (Path, Default_Settings_Text);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Settings");
         return
           (Success   => False,
            Durable   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Ensure_Default_File;
