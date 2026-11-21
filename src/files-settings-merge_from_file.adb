with Files.Capped_Files;
with Files.Diagnostics;
separate (Files.Settings)
   procedure Merge_From_File
     (Path     : String;
      Settings : in out Settings_Model;
      Merged   : out Boolean;
      Refused  : out Boolean)
   is
      use type Files.Capped_Files.Read_Status;
      use type String_Maps.Map;
      use type Action_Maps.Map;
      use type String_Vectors.Vector;
      use type Path_Label_Vectors.Vector;
      use type Shortcut_Override_Vectors.Vector;
      Status : Files.Capped_Files.Read_Status;
   begin
      Merged := False;
      Refused := False;
      if not Seen_Known or else To_String (Seen_Path) /= Path or else Files.Fs_Primitives.Entry_Is_Absent (Path) then
         return;
      end if;
      declare
         Text : constant String :=
           Files.Capped_Files.Read_Capped (Path, Max_Settings_Text_Bytes, Files.Capped_Files.Follow_Links, Status);
      begin
         if Status /= Files.Capped_Files.Read_Complete or else Text = To_String (Seen_Text) then
            return;
         end if;
         declare
            Theirs : constant Settings_Parse_Result := Parse (Text);
            Before : constant Settings_Parse_Result := Parse (To_String (Seen_Text));
            --  What this process started from: the file as it saw it (a
            --  file it wrote or loaded always parses; failing that, nothing
            --  of Settings counts as unchanged).
            Base   : constant Settings_Model := (if Before.Success then Before.Settings else Default_Settings);
            Mine   : constant Settings_Model := Settings;
            Result : Settings_Model;
         begin
            if not Theirs.Success then
               Files.Diagnostics.Trace ("Files.Settings", "settings_changed_unloadable=" & Path);
               Refused := True;
               return;
            end if;
            Result := Theirs.Settings;
            for Setting in Scalar_Setting loop
               if Scalar_Text (Mine, Setting) /= Scalar_Text (Base, Setting) then
                  declare
                     Error : Unbounded_String;
                  begin
                     --  A value's own text, which Set_Scalar always takes.
                     Set_Scalar (Result, Setting, Scalar_Text (Mine, Setting), Error);
                  end;
               end if;
            end loop;
            if Mine.Extension_Filetypes /= Base.Extension_Filetypes then
               Result.Extension_Filetypes := Mine.Extension_Filetypes;
            end if;
            if Mine.Icon_Mappings /= Base.Icon_Mappings then
               Result.Icon_Mappings := Mine.Icon_Mappings;
            end if;
            if Mine.Open_Actions /= Base.Open_Actions then
               Result.Open_Actions := Mine.Open_Actions;
            end if;
            if Mine.Paths.Favorites /= Base.Paths.Favorites then
               Result.Paths.Favorites := Mine.Paths.Favorites;
            end if;
            if Mine.Paths.Recent /= Base.Paths.Recent then
               Result.Paths.Recent := Mine.Paths.Recent;
            end if;
            if Mine.Paths.Labels /= Base.Paths.Labels then
               Result.Paths.Labels := Mine.Paths.Labels;
            end if;
            if Mine.Shortcut_Overrides /= Base.Shortcut_Overrides then
               Result.Shortcut_Overrides := Mine.Shortcut_Overrides;
            end if;
            Result.Persistence_Refused := Mine.Persistence_Refused;
            Files.Diagnostics.Trace ("Files.Settings", "settings_merged_from_file=" & Path);
            Merged := not Same_Content (Result, Mine);
            Settings := Result;
            --  Taken in: the same change is not taken again.
            Note_Seen (Path, Text);
         end;
      end;
   exception
      when Swallowed : others =>
         --  A file that cannot be compared is written as before.
         Files.Diagnostics.Note (Swallowed, "Files.Settings");
         Merged := False;
         Refused := False;
   end Merge_From_File;
