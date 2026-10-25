separate (Files_Suite.Startup)
   procedure Test_Startup_Path_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "dir");
      Second_Dir : constant String := Join (Root, "second");
      Filepath : constant String := Join (Dir, "note.txt");
      Other    : constant String := Join (Dir, "other.txt");
      Args     : Files.Types.String_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Direct   : Files.File_System.Path_Result;
      File     : Files.File_System.Path_Result;
      Current  : Files.File_System.Path_Result;
      Missing  : Files.File_System.Path_Result;
      Empty    : Files.File_System.Path_Result;
      Startup  : Files.Application.Startup_Result;
      Full_Dir : Unbounded_String;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Ada.Directories.Create_Path (Second_Dir);
      Write_File (Filepath);
      Write_File (Other);
      Write_File (Join (Second_Dir, "inside.txt"));
      Full_Dir := To_Unbounded_String (Ada.Directories.Full_Name (Dir));

      Direct := Files.File_System.Normalize_Path (Dir);
      File := Files.File_System.Normalize_Path (Filepath);
      Current := Files.File_System.Normalize_Path (".");
      Missing := Files.File_System.Normalize_Path (Join (Root, "missing"));
      Empty := Files.File_System.Normalize_Path ("");

      Assert (Direct.Status = Files.File_System.Path_Valid, "directory path is valid");
      Files_Suite.Support.Assert_Equal
        (To_String (Direct.Directory_Path),
         Ada.Directories.Full_Name (Dir),
         "directory is normalized");
      Assert (File.Status = Files.File_System.Path_Valid, "file path is valid");
      Files_Suite.Support.Assert_Equal
        (To_String (File.Directory_Path),
         Ada.Directories.Full_Name (Dir),
         "file maps to parent");
      Assert (Current.Status = Files.File_System.Path_Valid, "current-directory path is valid");
      Files_Suite.Support.Assert_Equal
        (To_String (Current.Directory_Path),
         Ada.Directories.Full_Name (Ada.Directories.Current_Directory),
         "current-directory path normalizes to absolute directory");
      Assert (Missing.Status = Files.File_System.Path_Missing, "missing path reports an error");
      Assert (Empty.Status = Files.File_System.Path_Missing, "empty path reports missing");
      Files_Suite.Support.Assert_Equal
        (To_String (Empty.Error_Key),
         "error.path.missing",
         "empty path reports missing-path error");
      declare
         Special_Path : constant String := "/dev/null";
      begin
         if Ada.Directories.Exists (Special_Path)
           and then Ada.Directories.Kind (Special_Path) = Ada.Directories.Special_File
         then
            declare
               Special : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Special_Path);
            begin
               Assert (Special.Status = Files.File_System.Path_Inaccessible, "special path reports inaccessible");
               Files_Suite.Support.Assert_Equal
                 (To_String (Special.Error_Key),
                  "error.path.inaccessible",
                  "special path reports inaccessible error key");

               Args.Clear;
               Args.Append (To_Unbounded_String (Special_Path));
               Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
               Assert (Startup.Windows.Is_Empty, "special startup path opens no window");
               Files_Suite.Support.Assert_Equal
                 (Natural (Startup.Errors.Length),
                  1,
                  "special startup path is reported as diagnostic");
               Files_Suite.Support.Assert_Equal
                 (To_String (Startup.Errors.Element (1).Input_Path),
                  Special_Path,
                  "special startup diagnostic records original path");
               Files_Suite.Support.Assert_Equal
                 (To_String (Startup.Errors.Element (1).Error_Key),
                  "error.path.inaccessible",
                  "special startup diagnostic records inaccessible error key");
            end;
         end if;
      exception
         when others =>
            null;
      end;

      Args.Clear;
      Args.Append (To_Unbounded_String (Dir));
      Args.Append (To_Unbounded_String (Filepath));
      Args.Append (To_Unbounded_String (Other));
      Args.Append (To_Unbounded_String (Second_Dir));
      Args.Append (To_Unbounded_String (Join (Root, "missing")));
      Startup := Files.Application.Resolve_Startup_Paths (Args, Settings);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Windows.Length),
         2,
         "distinct normalized paths produce one window each");
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length),
         1,
         "missing path is reported without a window");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Title),
         To_String (Startup.Windows.Element (1).Path),
         "window title is the normalized current directory path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (1).Path),
         To_String (Full_Dir),
         "startup window records the normalized directory path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Startup.Windows.Element (1).Model),
         To_String (Full_Dir),
         "startup window model uses the normalized directory path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Startup.Windows.Element (1).Model),
         2,
         "startup window model loads direct directory entries");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Windows.Element (2).Path),
         Ada.Directories.Full_Name (Second_Dir),
         "startup opens a separate window for a distinct normalized directory");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Startup.Windows.Element (2).Model),
         1,
         "second startup window model loads its directory entries");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Settings_Path),
         "",
         "path-only startup resolution has no central settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Input_Path),
         Join (Root, "missing"),
         "startup path diagnostic records the original invalid argument");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Errors.Element (1).Error_Key),
         "error.path.missing",
         "startup path diagnostic records the missing-path error key");
   end Test_Startup_Path_Normalization;
