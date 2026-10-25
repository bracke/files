separate (Files_Suite.Startup)
   procedure Test_Desktop_Packaging_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Files_Suite.Repository.File_Exists ("share/applications/files.desktop"),
         "desktop packaging includes a desktop entry");
      Assert
        (Files_Suite.Repository.File_Exists ("share/icons/hicolor/scalable/apps/files.svg"),
         "desktop packaging includes an application icon");
      Assert
        (Files_Suite.Repository.File_Exists ("share/metainfo/dk.bracke.files.metainfo.xml"),
         "desktop packaging includes AppStream metadata");
      Assert
        (Files_Suite.Repository.File_Exists ("share/files/package.manifest"),
         "desktop packaging includes a release manifest");
      Assert
        (Files_Suite.Repository.File_Exists ("share/doc/files/quick-start.md"),
         "desktop packaging includes a quick-start guide");
      Assert
        (Files_Suite.Repository.File_Contains
           ("share/doc/files/quick-start.md", "`Control+A` selects every visible item."),
         "quick-start guide documents the select-all shortcut");
      Assert
        (Files_Suite.Repository.File_Exists ("share/doc/files/settings-format.md"),
         "desktop packaging includes settings format documentation");
      Assert
        (Files_Suite.Repository.File_Exists ("share/doc/files/platform-support.md"),
         "desktop packaging includes platform support documentation");
      Assert
        (Files_Suite.Repository.File_Contains ("share/doc/files/platform-support.md", "Ada drop event-source"),
         "platform support documentation records drop event-source support");
      Assert
        (Files_Suite.Repository.File_Exists ("share/doc/files/release-notes.md"),
         "desktop packaging includes release notes");
      Assert
        (Files_Suite.Repository.File_Exists ("share/files.catalog"),
         "desktop packaging includes the localization catalog");
      Assert
        (Files_Suite.Repository.File_Exists ("share/files/icons/folder.icon"),
         "desktop packaging includes bundled icon assets");
      Assert
        (Files_Suite.Repository.File_Exists ("share/files/icons/markdown.icon"),
         "desktop packaging includes the complete bundled icon set");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/files.catalog"),
         "release manifest includes localization catalog");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/doc/files/quick-start.md"),
         "release manifest includes quick-start guide");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/doc/files/settings-format.md"),
         "release manifest includes settings format documentation");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/doc/files/platform-support.md"),
         "release manifest includes platform support documentation");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/doc/files/release-notes.md"),
         "release manifest includes release notes");
      Assert
        (Files_Suite.Repository.File_Contains ("share/files/package.manifest", "share/files/icons/markdown.icon"),
         "release manifest includes bundled icon assets");
   end Test_Desktop_Packaging_Contents;
