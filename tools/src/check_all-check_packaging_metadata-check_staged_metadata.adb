separate (Check_All.Check_Packaging_Metadata)
   procedure Check_Staged_Metadata is
   begin
      Project_Tools.Files.Delete_Tree (Stage);
      Project_Tools.Files.Copy_Filtered_Tree
        (Source_Dir      => Root & "/share",
         Target_Dir      => Stage & "/share",
         Skip_Entries    => [1 .. 0 => <>],
         Skip_Files      => [1 .. 0 => <>],
         Failure_Message => "could not stage the share tree");
      Check_Staged_Manifest_Entries;
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Stage & "/share/applications/files.desktop"),
          To_Unbounded_String (Stage & "/share/icons/hicolor/scalable/apps/files.svg"),
          To_Unbounded_String (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml"),
          To_Unbounded_String (Stage & "/share/doc/files/quick-start.md"),
          To_Unbounded_String (Stage & "/share/doc/files/settings-format.md"),
          To_Unbounded_String (Stage & "/share/doc/files/platform-support.md"),
          To_Unbounded_String (Stage & "/share/doc/files/release-notes.md"),
          To_Unbounded_String (Stage & "/share/files/package.manifest"),
          To_Unbounded_String (Stage & "/share/files.catalog"),
          To_Unbounded_String (Stage & "/share/files/icons/folder.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/text.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/image.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/executable.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/link.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/unknown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/ada.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/markdown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/folder.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/text.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/image.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/executable.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/link.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/unknown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/ada.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/markdown.icon")],
         "files staged install must preserve desktop metadata and runtime resource paths");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Type=Application",
         "files staged desktop entry must preserve application entry type");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Exec=files %F",
         "files staged desktop entry must preserve path-opening executable contract");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Name=Files",
         "files staged desktop entry must preserve the application name");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Comment=Browse and open local files",
         "files staged desktop entry must preserve the application summary");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Icon=files",
         "files staged desktop entry must preserve the application icon id");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Terminal=false",
         "files staged desktop entry must preserve non-terminal launch behavior");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "MimeType=inode/directory;",
         "files staged desktop entry must preserve directory MIME registration");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Categories=System;FileManager;FileTools;",
         "files staged desktop entry must preserve file-manager categories");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Keywords=file;folder;directory;manager;explorer;",
         "files staged desktop entry must preserve launcher search keywords");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "StartupNotify=true",
         "files staged desktop entry must preserve startup notification metadata");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 64 64"">",
         "files staged application icon must preserve SVG identity");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#2d7dd2""",
         "files staged application icon must preserve the folder body");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#62b7f0""",
         "files staged application icon must preserve the blue folder tab accent");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "stroke=""#b9e2ff""",
         "files staged application icon must preserve blue folder highlight strokes");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<?xml version=""1.0"" encoding=""UTF-8""?>",
         "files staged AppStream metadata must preserve UTF-8 XML declaration");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<component type=""desktop-application"">",
         "files staged AppStream metadata must preserve desktop application component type");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<id>dk.bracke.files</id>",
         "files staged AppStream metadata must preserve the stable application id");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<metadata_license>MIT</metadata_license>",
         "files staged AppStream metadata must preserve the metadata license");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<project_license>MIT OR Apache-2.0 WITH LLVM-exception</project_license>",
         "files staged AppStream metadata must preserve the project license");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<name>Files</name>",
         "files staged AppStream metadata must preserve the application name");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<summary>Browse and open local files</summary>",
         "files staged AppStream metadata must preserve the application summary");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<p>Files is an Ada desktop file explorer for browsing, searching, organizing, and opening local files.</p>",
         "files staged AppStream metadata must preserve the application description");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<launchable type=""desktop-id"">files.desktop</launchable>",
         "files staged AppStream metadata must preserve desktop launchability");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>System</category>",
         "files staged AppStream metadata must preserve system category metadata");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>FileManager</category>",
         "files staged AppStream metadata must preserve file-manager category metadata");
      Project_Tools.Files.Delete_Tree (Stage);
   end Check_Staged_Metadata;
