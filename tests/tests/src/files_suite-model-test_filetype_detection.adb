with Ada.Strings.Fixed;
with Files.File_System.Thumbnails;
with Files.Settings.Testing;
with Files.Name_Parts;
with Files.Text_Case;

separate (Files_Suite.Model)
   procedure Test_Filetype_Detection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Directory_Item : constant Files.Items.Directory_Item :=
        Files.File_System.Make_Item (Root, "src", Files.Types.Directory_Item);
      Symlink_Item : constant Files.Items.Directory_Item :=
        Files.File_System.Make_Item (Root, "link.adb", Files.Types.Symlink_Item);
      Executable_Item : constant Files.Items.Directory_Item :=
        Files.File_System.Make_Item (Root, "run", Files.Types.Executable_Item);
      Regular_Item : constant Files.Items.Directory_Item :=
        Files.File_System.Make_Item ("", "loose.txt", Files.Types.Regular_File_Item);
      Ada_Item : Files.Items.Directory_Item;
      Executable_Ada_Item : Files.Items.Directory_Item;
      Symlink_Ada_Item : Files.Items.Directory_Item;
      C1_Break : constant Character := Character'Val (133);
      NBSP : constant String := Files.Application.Window_Policy.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      Line_Separator : constant String :=
        Files.Application.Window_Policy.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
   begin
      Files.Settings.Testing.Add_Extension_Mapping (Settings, "adb", "text/x-ada");
      Files.Settings.Testing.Add_Extension_Mapping (Settings, "profile", "text/x-profile");
      Files.Settings.Testing.Add_Icon_Mapping (Settings, "text/x-ada", "ada");
      Ada_Item := Files.File_System.Make_Item (Root, "main.adb", Files.Types.Regular_File_Item, Settings);
      Executable_Ada_Item := Files.File_System.Make_Item (Root, "tool.adb", Files.Types.Executable_Item, Settings);
      Symlink_Ada_Item := Files.File_System.Make_Item (Root, "link.adb", Files.Types.Symlink_Item, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Directory_Item.Filetype),
         "inode/directory",
         "directory helper item gets directory filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Directory_Item.Icon_Id),
         "folder",
         "directory helper item gets directory icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Symlink_Item.Filetype),
         "inode/symlink",
         "symlink helper item gets symlink filetype before extension mapping");
      Files_Suite.Support.Assert_Equal
        (To_String (Symlink_Item.Icon_Id),
         "link",
         "symlink helper item gets symlink icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Executable_Item.Filetype),
         "application/x-executable",
         "executable helper item gets executable filetype");
      Files_Suite.Support.Assert_Equal
        (To_String (Executable_Item.Icon_Id),
         "executable",
         "executable helper item gets executable icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Executable_Ada_Item.Filetype),
         "application/x-executable",
         "settings-aware executable helper item ignores extension mappings");
      Files_Suite.Support.Assert_Equal
        (To_String (Executable_Ada_Item.Icon_Id),
         "executable",
         "settings-aware executable helper item keeps executable icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Symlink_Ada_Item.Filetype),
         "inode/symlink",
         "settings-aware symlink helper item ignores extension mappings");
      Files_Suite.Support.Assert_Equal
        (To_String (Symlink_Ada_Item.Icon_Id),
         "link",
         "settings-aware symlink helper item keeps symlink icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Regular_Item.Filetype),
         "text/plain",
         "regular helper item uses default extension mapping");
      Files_Suite.Support.Assert_Equal
        (To_String (Regular_Item.Icon_Id),
         "text",
         "regular helper item uses mapped text icon");
      Files_Suite.Support.Assert_Equal
        (To_String (Ada_Item.Filetype),
         "text/x-ada",
         "settings-aware helper item uses custom extension mapping");
      Files_Suite.Support.Assert_Equal
        (To_String (Ada_Item.Icon_Id),
         "ada",
         "settings-aware helper item uses custom icon mapping");
      Files_Suite.Support.Assert_Equal
        (To_String (Regular_Item.Full_Path),
         "loose.txt",
         "helper item with empty parent uses simple path");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Directory_Item, "src"),
         "inode/directory",
         "directory filetype wins before extension mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Executable_Item, "tool.adb"),
         "application/x-executable",
         "executable filetype wins before extension mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Symlink_Item, "link.adb"),
         "inode/symlink",
         "symlink filetype wins before extension mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "main.adb"),
         "text/x-ada",
         "extension mapping is used for regular files");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "MAIN.ADB"),
         "text/x-ada",
         "filetype detection normalizes filename extension case before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "archive.tar.gz"),
         "application/gzip-tar",
         "compound extension mapping wins over final suffix mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("archive.tar.gz"),
         "gz",
         "final extension is extracted");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("MAIN.ADB"),
         "adb",
         "extension extraction normalizes case");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (".profile"),
         "",
         "leading-dot file has no extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("name."),
         "",
         "trailing-dot file has no extension");
      --  One rule (Files.Name_Parts.Extension_Start) for every reader of an
      --  extension: a leading dot is name, unless the badge asks for it.
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (".profile", Dotfiles => True),
         "profile",
         "a dotfile's name is its badge extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (".config.yml", Dotfiles => True),
         "yml",
         "a dotfile with a further dot has that extension, as without Dotfiles");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("Photo.JPG"),
         Files.Text_Case.To_Lower_Ascii (Files.Name_Parts.Extension_Of ("Photo.JPG")),
         "File_Types reads the extension Files.Types finds, lower-cased");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.File_System.Thumbnails.Thumbnail_Path_For (Join (Root, ".png"), Root), "thumb_file_") > 0,
         "a dotfile's thumbnail has no extension, as its filetype has none");
      Assert
        (Ada.Strings.Fixed.Index
           (Files.File_System.Thumbnails.Thumbnail_Path_For (Join (Root, "Shot.PNG"), Root), "thumb_png_") > 0,
         "a thumbnail is named by the lower-cased extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (" main.adb "),
         "adb",
         "extension extraction trims whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (ASCII.LF & "main.adb" & ASCII.LF),
         "adb",
         "extension extraction trims line-feed whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (ASCII.VT & "main.adb" & ASCII.FF),
         "adb",
         "extension extraction trims vertical-tab and form-feed whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (C1_Break & "main.adb" & C1_Break),
         "adb",
         "extension extraction trims C1 line-break whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (NBSP & "main.adb" & NBSP),
         "adb",
         "extension extraction trims UTF-8 NBSP whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of (Line_Separator & "main.adb" & Line_Separator),
         "adb",
         "extension extraction trims UTF-8 line-separator whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("   "), "", "blank filename has no extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("/tmp/dir.with.dots/main.adb"),
         "adb",
         "extension extraction uses the Unix path leaf name");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("C:\tmp\dir.with.dots\main.adb"),
         "adb",
         "extension extraction uses the Windows path leaf name");
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Files_Suite.Support.Assert_Equal
           (Files.File_Types.Normalized_Extension_Of ("report.txt\raw"),
            "txt\raw",
            "a POSIX backslash remains part of the extension-bearing filename");
      end if;
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalized_Extension_Of ("/tmp/dir.with.dots/file"),
         "",
         "extension extraction ignores dotted directory names");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, ".profile"),
         "application/octet-stream",
         "leading-dot file does not match an extension mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "/tmp/dir.with.dots/main.adb"),
         "text/x-ada",
         "filetype detection uses the Unix path leaf name");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "C:\tmp\dir.with.dots\main.adb"),
         "text/x-ada",
         "filetype detection uses the Windows path leaf name");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "/tmp/dir.with.dots/file"),
         "application/octet-stream",
         "filetype detection ignores dotted directory names");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, " main.adb "),
         "text/x-ada",
         "filetype detection trims filename whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Unknown_Item, "mystery.adb"),
         "text/x-ada",
         "unknown item filetype still uses configured extension mappings");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Other_Item, "socket"),
         "application/octet-stream",
         "other item filetype falls back deterministically without mapping");
      Files.Settings.Testing.Add_Extension_Mapping (Settings, "backup.tar.gz", "application/x-backup");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "weekly.backup.tar.gz"),
         "application/x-backup",
         "custom compound extension mapping uses the longest configured suffix");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, ASCII.LF & "main.adb" & ASCII.LF),
         "text/x-ada",
         "filetype detection trims line-feed filename whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, ASCII.VT & "main.adb" & ASCII.FF),
         "text/x-ada",
         "filetype detection trims vertical-tab and form-feed filename whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, C1_Break & "main.adb" & C1_Break),
         "text/x-ada",
         "filetype detection trims C1 line-break filename whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, NBSP & "main.adb" & NBSP),
         "text/x-ada",
         "filetype detection trims UTF-8 NBSP filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            Line_Separator & "main.adb" & Line_Separator) = "text/x-ada",
         "filetype detection trims UTF-8 line-separator filename whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "blob.bin"),
         "application/octet-stream",
         "unknown extension falls back deterministically");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, "inode/symlink"),
         "link",
         "symlink icon mapping is used");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, " inode/symlink "),
         "link",
         "icon classification trims filetype whitespace before mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Regular_File_Item, " text/x-ada "),
         "ada",
         "mapped regular-file icon classification trims filetype whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Regular_File_Item, "application/x-custom"),
         "unknown",
         "unmapped regular-file icon falls back deterministically");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Directory_Item, ""),
         "folder",
         "directory icon falls back by item kind without mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, ""),
         "link",
         "symlink icon falls back by item kind without mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Executable_Item, ""),
         "executable",
         "executable icon falls back by item kind without mapping");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Other_Item, ""),
         "unknown",
         "other item icon falls back deterministically without mapping");
   end Test_Filetype_Detection;
