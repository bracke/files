separate (Check_All.Check_Packaging_Metadata)
   procedure Check_Source_Metadata is
   begin
      Require_Present
        ([To_Unbounded_String (Root & "/share/applications/files.desktop"),
          To_Unbounded_String (Root & "/share/icons/hicolor/scalable/apps/files.svg"),
          To_Unbounded_String (Root & "/share/metainfo/dk.bracke.files.metainfo.xml"),
          To_Unbounded_String (Root & "/share/doc/files/quick-start.md"),
          To_Unbounded_String (Root & "/share/doc/files/settings-format.md"),
          To_Unbounded_String (Root & "/share/doc/files/platform-support.md"),
          To_Unbounded_String (Root & "/share/doc/files/release-notes.md"),
          To_Unbounded_String (Root & "/share/files/package.manifest")],
         "files desktop packaging metadata must be present");
      Require_In_Text
        (Root & "/files.gpr",
         "for Artifacts (""."") use (""share"");",
         "files install artifacts must include the share resource tree");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Type=Application",
         "files desktop entry must declare an application entry type");
      Require_In_Text
        (Root & "/share/doc/files/quick-start.md",
         "`Control+A` selects every visible item.",
         "quick-start guide must document the select-all shortcut");
      Require_In_Text
        (Root & "/share/doc/files/platform-support.md",
         "Ada drop event-source",
         "platform support documentation must record drop event-source support");
      Require_In_Text
        (Root & "/share/doc/files/platform-support.md",
         "native AT-SPI, UI Automation",
         "platform support documentation must record native accessibility provider support");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "MimeType=inode/directory;",
         "files desktop entry must register directory opening");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Name=Files",
         "files desktop entry must keep the packaged application name");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Comment=Browse and open local files",
         "files desktop entry must keep the packaged application summary");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Exec=files %F",
         "files desktop entry must pass file paths to the executable");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Icon=files",
         "files desktop entry must use the installed application icon");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Terminal=false",
         "files desktop entry must not launch in a terminal");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Categories=System;FileManager;FileTools;",
         "files desktop entry must expose file-manager categories");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "Keywords=file;folder;directory;manager;explorer;",
         "files desktop entry must expose launcher search keywords");
      Require_In_Text
        (Root & "/share/applications/files.desktop",
         "StartupNotify=true",
         "files desktop entry must request startup notification");
      Require_In_Text
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 64 64"">",
         "files application icon must be a scalable SVG with the expected viewbox");
      Require_In_Text
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#2d7dd2""",
         "files application icon must retain the blue folder body");
      Require_In_Text
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#62b7f0""",
         "files application icon must retain the blue folder tab accent");
      Require_In_Text
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "stroke=""#b9e2ff""",
         "files application icon must retain visible blue folder highlight strokes");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<?xml version=""1.0"" encoding=""UTF-8""?>",
         "files AppStream metadata must declare UTF-8 XML");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<component type=""desktop-application"">",
         "files AppStream metadata must declare a desktop application component");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<launchable type=""desktop-id"">files.desktop</launchable>",
         "files AppStream metadata must reference the desktop entry");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<id>dk.bracke.files</id>",
         "files AppStream metadata must keep the stable application id");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<metadata_license>MIT</metadata_license>",
         "files AppStream metadata must declare the metadata license");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<project_license>MIT OR Apache-2.0 WITH LLVM-exception</project_license>",
         "files AppStream metadata must declare the project license");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<name>Files</name>",
         "files AppStream metadata must match the desktop application name");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<summary>Browse and open local files</summary>",
         "files AppStream metadata must match the desktop application summary");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<p>Files is an Ada desktop file explorer for browsing, searching, organizing, and opening local files.</p>",
         "files AppStream metadata must describe the packaged application");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>System</category>",
         "files AppStream metadata must expose the System category");
      Require_In_Text
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>FileManager</category>",
         "files AppStream metadata must expose the FileManager category");
      Require_Manifest_Entry
        ("bin/files",
         "files package manifest must include the executable");
      Require_Manifest_Entry
        ("share/applications/files.desktop",
         "files package manifest must include the desktop entry");
      Require_Manifest_Entry
        ("share/icons/hicolor/scalable/apps/files.svg",
         "files package manifest must include the application icon");
      Require_Manifest_Entry
        ("share/metainfo/dk.bracke.files.metainfo.xml",
         "files package manifest must include AppStream metadata");
      Require_Manifest_Entry
        ("share/doc/files/quick-start.md",
         "files package manifest must include quick-start documentation");
      Require_Manifest_Entry
        ("share/doc/files/settings-format.md",
         "files package manifest must include settings format documentation");
      Require_Manifest_Entry
        ("share/doc/files/platform-support.md",
         "files package manifest must include platform support documentation");
      Require_Manifest_Entry
        ("share/doc/files/release-notes.md",
         "files package manifest must include release notes");
      Require_Manifest_Entry
        ("share/files/package.manifest",
         "files package manifest must include the release manifest");
      Require_Manifest_Entry
        ("share/files.catalog",
         "files package manifest must include the localization catalog");
      Require_Manifest_Entry
        ("share/files/icons/folder.icon",
         "files package manifest must include bundled folder icon");
      Require_Manifest_Entry
        ("share/files/icons/text.icon",
         "files package manifest must include bundled text icon");
      Require_Manifest_Entry
        ("share/files/icons/image.icon",
         "files package manifest must include bundled image icon");
      Require_Manifest_Entry
        ("share/files/icons/executable.icon",
         "files package manifest must include bundled executable icon");
      Require_Manifest_Entry
        ("share/files/icons/link.icon",
         "files package manifest must include bundled link icon");
      Require_Manifest_Entry
        ("share/files/icons/unknown.icon",
         "files package manifest must include bundled unknown icon");
      Require_Manifest_Entry
        ("share/files/icons/ada.icon",
         "files package manifest must include bundled Ada icon");
      Require_Manifest_Entry
        ("share/files/icons/markdown.icon",
         "files package manifest must include bundled Markdown icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/folder.icon",
         "files package manifest must include high-contrast folder icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/text.icon",
         "files package manifest must include high-contrast text icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/image.icon",
         "files package manifest must include high-contrast image icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/executable.icon",
         "files package manifest must include high-contrast executable icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/link.icon",
         "files package manifest must include high-contrast link icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/unknown.icon",
         "files package manifest must include high-contrast unknown icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/ada.icon",
         "files package manifest must include high-contrast Ada icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/markdown.icon",
         "files package manifest must include high-contrast Markdown icon");
   end Check_Source_Metadata;
