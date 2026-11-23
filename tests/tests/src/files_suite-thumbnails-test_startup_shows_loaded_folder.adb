with Files_Suite.Support.Models;
with Files.Application.Testing;
with Files.File_System.Trash;
with Files_Suite.Support.Guards;
separate (Files_Suite.Thumbnails)
   procedure Test_Startup_Shows_Loaded_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Photos      : constant String := Join (Root, "startup-photos");
      Trash_Home  : constant String := Join (Root, "startup-xdg-data");
      Arguments   : Files.Types.String_Vectors.Vector;
      Startup     : Files.Application.Startup_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_CACHE_HOME");
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Join (Root, "cache-home"));
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Path (Photos);
      Write_Binary_File
        (Join (Photos, "photo.png"),
         Minimal_Png_RGB
           (2, 2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));

      --  A startup folder is shown the way navigation shows one
      --  (Operations.Start_At_Folder): its new photo is owed to a background
      --  listing, its signature is the watch's, and it is no trash.
      Arguments.Append (To_Unbounded_String (Photos));
      Startup := Files.Application.Testing.Resolve_Startup_Paths (Arguments, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Startup.Windows.Length), 1, "the startup folder opens one window");
      declare
         Model : Files.Model.Window_Model renames Startup.Windows (1).Model;
      begin
         Assert (Files_Suite.Support.Models.Visible_Index_Of (Model, "photo.png") /= 0,
                 "the window shows the folder");
         Assert (Files.Model.Refresh_Is_Owed (Model) and then Files.Model.Owed_Refresh_Force (Model),
                 "a startup folder missing a thumbnail owes the forced background listing that makes it");
         Assert (not Files.File_System.Detect_Directory_Change
                   (Files.Model.Directory_Signature_Of (Model), Files.Model.Current_Path (Model)).Changed,
                 "the startup folder's signature is the one a change check reads, so it is not read again");
         Assert (not Files.Model.Current_Is_Trash (Model), "an ordinary startup folder is no trash");
      end;

      --  Started in the trash, the window knows it is there.
      Ada.Directories.Create_Path (Files.File_System.Trash.Trash_Files_Directory);
      Arguments.Clear;
      Arguments.Append (To_Unbounded_String (Files.File_System.Trash.Trash_Files_Directory));
      Startup := Files.Application.Testing.Resolve_Startup_Paths (Arguments, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Startup.Windows.Length), 1, "the trash opens one window");
      Assert (Files.Model.Current_Is_Trash (Startup.Windows (1).Model),
              "a window started in the trash settles that it is the trash");
      Assert (not Files.Model.Refresh_Is_Owed (Startup.Windows (1).Model),
              "a folder with nothing to make owes no background listing");
   end Test_Startup_Shows_Loaded_Folder;
