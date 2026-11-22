separate (Check_All)
   procedure Check_Rendering_Architecture is
      Rendering_Body : constant String := Root & "/src/files-rendering.adb";
      Rendering_Spec : constant String := Root & "/src/files-rendering.ads";
      Hit_Body       : constant String := Root & "/src/files-rendering-hit.adb";
      Hit_Spec       : constant String := Root & "/src/files-rendering-hit.ads";
      Layouts_Spec   : constant String := Root & "/src/files-rendering-layouts.ads";
      Layouts_Body   : constant String := Root & "/src/files-rendering-layouts.adb";
      Geometry_Spec  : constant String := Root & "/src/files-rendering-geometry.ads";
      Geometry_Body  : constant String := Root & "/src/files-rendering-geometry.adb";
      Labels_Spec    : constant String := Root & "/src/files-rendering-labels.ads";
      Labels_Body    : constant String := Root & "/src/files-rendering-labels.adb";
      Text_Spec      : constant String := Root & "/src/files-rendering-text.ads";
      Text_Body      : constant String := Root & "/src/files-rendering-text.adb";
      Fonts_Body     : constant String := Root & "/src/files-fonts.adb";
      Fonts_Spec     : constant String := Root & "/src/files-fonts.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Windows_Body   : constant String := Root & "/src/files-application-windows.adb";
      Tests          : constant String := Combined_Suite;

      procedure Check_Rendering_Unit
        (Path  : String;
         Label : String) is separate;
   begin
      --  Rendering reads the file system's types and two capability queries;
      --  every call that lists, writes or validates is someone else's.
      Require_Only_Names_From
        ("files-rendering",
         "Files.File_System",
         [To_Unbounded_String ("Directory_Item"),
          To_Unbounded_String ("Item_Vectors"),
          To_Unbounded_String ("Permissions"),
          To_Unbounded_String ("Drop_Move"),
          To_Unbounded_String ("Drop_Import_Mode"),
          To_Unbounded_String ("Directory_Size_Result")],
         "rendering must not list, write or validate files");
      --  Of the paths the settings keep, only what they say: no favorite,
      --  recent or label is changed while a frame is drawn.
      Require_Only_Names_From
        ("files-rendering",
         "Files.Settings.Path_References",
         [To_Unbounded_String ("Index_Paths"),
          To_Unbounded_String ("Path_Index"),
          To_Unbounded_String ("Is_Favorite"),
          To_Unbounded_String ("Label_Of"),
          To_Unbounded_String ("Recent_Paths")],
         "rendering must not change favorites, recents or labels");
      --  Of permissions and ownership, only whether the host supports them.
      Require_Only_Names_From
        ("files-rendering",
         "Files.File_System.Permissions",
         [To_Unbounded_String ("Supports_Permissions"),
          To_Unbounded_String ("Supports_Ownership")],
         "rendering must not change permissions or ownership");
      Check_Rendering_Unit (Rendering_Spec, "rendering spec");
      Check_Rendering_Unit (Rendering_Body, "rendering body");
      Check_Rendering_Unit (Hit_Spec, "hit-testing spec");
      Check_Rendering_Unit (Layouts_Spec, "layouts spec");
      Check_Rendering_Unit (Layouts_Body, "layouts body");
      Check_Rendering_Unit (Geometry_Spec, "rendering geometry spec");
      Check_Rendering_Unit (Geometry_Body, "rendering geometry body");
      Check_Rendering_Unit (Labels_Spec, "rendering labels spec");
      Check_Rendering_Unit (Labels_Body, "rendering labels body");
      Check_Rendering_Unit (Text_Spec, "text rendering spec");
      Check_Rendering_Unit (Text_Body, "text rendering body");

      --  Lock the Files.* import boundary of the rendering layer through the
      --  shared helper. The allow-lists are the units each source actually
      --  imports today, so the operations, controller, and application-startup
      --  units (and any other new Files.* dependency) are rejected.
      Require_Only_Allowed_With_Clauses
        (Rendering_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Breadcrumbs"),
          To_Unbounded_String ("Files.Commands"),
          To_Unbounded_String ("Files.Folder_Tree"),
          To_Unbounded_String ("Files.File_Types"),
          To_Unbounded_String ("Files.Icon_Themes"),
          To_Unbounded_String ("Files.Model"),
          To_Unbounded_String ("Files.Preference_Types"),
          To_Unbounded_String ("Files.Quick_Look"),
          To_Unbounded_String ("Files.Settings"),
          To_Unbounded_String ("Files.Types"),
          To_Unbounded_String ("Files.UI_Types")]);
      Require_Only_Allowed_With_Clauses
        (Rendering_Body,
         "Files.",
         [To_Unbounded_String ("Files.Application.Accessibility"),
          To_Unbounded_String ("Files.Overlays.Command_Palette"),
          To_Unbounded_String ("Files.Rendering.Display_Text"),
          To_Unbounded_String ("Files.File_System"),
          To_Unbounded_String ("Files.File_Types"),
          To_Unbounded_String ("Files.Fonts"),
          To_Unbounded_String ("Files.Localization"),
          To_Unbounded_String ("Files.Rendering.Geometry"),
          To_Unbounded_String ("Files.Rendering.Labels"),
          To_Unbounded_String ("Files.Rendering.Layouts")]);
      --  Hit-testing stays pure geometry: it may import only the rendering
      --  layer's own geometry (the body is also covered above as a
      --  files-rendering-* source).
      Require_Only_Allowed_With_Clauses
        (Hit_Body,
         "Files.",
         --  The view mode and detail columns it tests against: value types;
         --  and which rows a context menu has, which its hit test walks.
         [To_Unbounded_String ("Files.Commands.Context_Menus"),
          To_Unbounded_String ("Files.Preference_Types"),
          To_Unbounded_String ("Files.Rendering.Geometry")]);
      --  The layouts and the text read no model and no files: snapshots in,
      --  geometry or glyphs out.
      Require_Only_Allowed_With_Clauses
        (Layouts_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Commands"),
          To_Unbounded_String ("Files.Preference_Types"),
          To_Unbounded_String ("Files.Types"),
          To_Unbounded_String ("Files.UI_Types")]);
      Require_Only_Allowed_With_Clauses
        (Text_Spec,
         "Files.",
         No_Units);

      --  A subunit inherits its parent's context and may add with clauses
      --  of its own, which the two lists above would not see. Every
      --  files-rendering-* body is held to the union of the two, plus the
      --  units the snapshot and frame subunits import for themselves.
      declare
         Stateful_Overlay_Units : constant Project_Tools.Ada_Source.String_List :=
           [To_Unbounded_String ("Guikit.Command_Palette"),
            To_Unbounded_String ("Guikit.Settings_Panel")];
         Family_Allowed : constant Project_Tools.Ada_Source.String_List :=
           [To_Unbounded_String ("Files.Application.Accessibility"),
            To_Unbounded_String ("Files.Breadcrumbs"),
            To_Unbounded_String ("Files.Overlays.Command_Palette"),
            To_Unbounded_String ("Files.Commands"),
            To_Unbounded_String ("Files.Commands.Context_Menus"),
            To_Unbounded_String ("Files.Commands.Status"),
            To_Unbounded_String ("Files.Extension_Labels"),
            To_Unbounded_String ("Files.Extra_Info"),
            To_Unbounded_String ("Files.File_System"),
            To_Unbounded_String ("Files.File_System.Permissions"),
            --  The filesystem layer's value types alone (volume space, the
            --  account kind), no I/O.
            To_Unbounded_String ("Files.File_System_Types"),
            To_Unbounded_String ("Files.File_Types"),
            To_Unbounded_String ("Files.Folder_Tree"),
            To_Unbounded_String ("Files.Icon_Themes"),
            To_Unbounded_String ("Files.Fonts"),
            To_Unbounded_String ("Files.Grouping"),
            To_Unbounded_String ("Files.Items"),
            To_Unbounded_String ("Files.Localization"),
            To_Unbounded_String ("Files.Model"),
            To_Unbounded_String ("Files.Model.Clipboard"),
            To_Unbounded_String ("Files.Model.Context_Menu"),
            To_Unbounded_String ("Files.Model.Creation"),
            To_Unbounded_String ("Files.Model.Filtering"),
            To_Unbounded_String ("Files.Model.Folder_Sizes"),
            To_Unbounded_String ("Files.Model.Info_Pane"),
            --  The foreground progress the info pane and dialog show, read.
            To_Unbounded_String ("Files.Model.Jobs"),
            To_Unbounded_String ("Files.Model.Label_Picker"),
            To_Unbounded_String ("Files.Model.Ownership_Input"),
            To_Unbounded_String ("Files.Model.Pasting"),
            To_Unbounded_String ("Files.Model.Quick_Look"),
            To_Unbounded_String ("Files.Model.Recent"),
            To_Unbounded_String ("Files.Model.Rename"),
            To_Unbounded_String ("Files.Model.Root_Selector"),
            To_Unbounded_String ("Files.Model.Selection"),
            To_Unbounded_String ("Files.Model.Sort_Menu"),
            To_Unbounded_String ("Files.Model.Status_Samples"),
            To_Unbounded_String ("Files.Model.Tree_Panel"),
            To_Unbounded_String ("Files.Preference_Types"),
            To_Unbounded_String ("Files.Quick_Look"),
            To_Unbounded_String ("Files.Rendering.Display_Text"),
            To_Unbounded_String ("Files.Rendering.Geometry"),
            To_Unbounded_String ("Files.Rendering.Labels"),
            To_Unbounded_String ("Files.Rendering.Layouts"),
            To_Unbounded_String ("Files.Rendering.Layouts.Details"),
            To_Unbounded_String ("Files.Rendering.Layouts.Menus"),
            To_Unbounded_String ("Files.Rendering.Layouts.Tree"),
            To_Unbounded_String ("Files.Root_Labels"),
            To_Unbounded_String ("Files.Settings"),
            To_Unbounded_String ("Files.Settings.Path_References"),
            --  Text helpers (a leaf name's parts, case folding), no I/O.
            To_Unbounded_String ("Files.Name_Parts"),
            To_Unbounded_String ("Files.Text_Basics"),
            To_Unbounded_String ("Files.Text_Case"),
            To_Unbounded_String ("Files.Timing"),
            To_Unbounded_String ("Files.Types"),
            To_Unbounded_String ("Files.UI_Types")];
      begin
         for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-rendering-*.adb", Generated_Directories) loop
            Require_Only_Allowed_With_Clauses (To_String (Item), "Files.", Family_Allowed);
            --  The stateful overlays render at the window layer (CLAUDE.md):
            --  their state cannot pass through the immutable snapshot.
            for Unit of Stateful_Overlay_Units loop
               Require_Only_Allowed_With_Clauses (To_String (Item), To_String (Unit), No_Units);
            end loop;
            for Unit of Filesystem_Units loop
               Require_Only_Allowed_With_Clauses (To_String (Item), To_String (Unit), No_Units);
            end loop;
         end loop;
         --  The parent's own spec and body too: the text checks above match
         --  one spelling of a with clause, this one parses them.
         for Suffix in 1 .. 2 loop
            for Unit of Filesystem_Units loop
               Require_Only_Allowed_With_Clauses
                 (Root & "/src/files-rendering.ad" & (if Suffix = 1 then "s" else "b"), To_String (Unit), No_Units);
            end loop;
            for Unit of Stateful_Overlay_Units loop
               Require_Only_Allowed_With_Clauses
                 (Root & "/src/files-rendering.ad" & (if Suffix = 1 then "s" else "b"), To_String (Unit), No_Units);
            end loop;
         end loop;
      end;

      Require_Not_Contains_In_Unit
        (Fonts_Body,
         "or else Has_Suffix (Lower, "".ttc"")",
         "font discovery must not select TTC collections that the text renderer cannot initialize");
      Require_Not_Contains_In_Unit
        (Fonts_Body,
         "Textrender.Reset",
         "font discovery must not reset process-global text renderer state");
      Require_Not_Contains_In_Unit
        (Fonts_Body,
         "Textrender.Load_Font",
         "font discovery must not load fonts through the live text renderer");
      Require_Not_Contains_In_Unit
        (Fonts_Body,
         "Textrender.Get_Glyph",
         "font discovery must not probe glyphs through the live text renderer");
      Require_Not_Contains_In_Unit
        (Fonts_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "font discovery must not keep a local required zero-width glyph classifier");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count > 0",
         "live rendering must not reload fonts during every frame with missing glyphs");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "/usr/share/fonts",
         "rendering body must not hard-code system font paths");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "Add_Border (X, Y, Draw_Size, Draw_Size, Border_Color);",
         "main-section icon assets must not draw an extra outer square border");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "procedure Add_Pixel_Icon",
         "toolbar icon rendering must not use enlarged 7x7 pixel glyphs");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "Item_State_Inset",
         "main-view hover and selection blocks must include the item padding area");
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "Prefix & ""...""",
         "rendering fitted text must not append three ASCII dots");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "text glyph rendering must not keep a local required zero-width glyph classifier");
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "procedure Decode_Next_Codepoint" & ASCII.LF
         & "           (Content   : String;",
         "text glyph rendering must not keep a local UTF-8 decoder");

      --  The biggest bodies may shrink but not grow (CLAUDE.md: keep
      --  files-rendering.adb from regrowing): a new large subprogram goes
      --  into a subunit of its own. Lower a ceiling when a file shrinks.
      declare
         procedure Require_At_Most (Name : String; Lines : Positive) is
            Text  : constant String := To_String (Project_Tools.Text.Read_Text_File (Root & "/src/" & Name));
            Count : constant Natural := Ada.Strings.Fixed.Count (Text, [1 => ASCII.LF]);
         begin
            if Count > Lines then
               Report (Name & " has" & Count'Image & " lines, over its ceiling of" & Lines'Image
                  & ": move the new code into a subunit");
            end if;
         end Require_At_Most;
      begin
         Require_At_Most ("files-rendering.adb", 133);
         Require_At_Most ("files-rendering-layouts.adb", 407);
         Require_At_Most ("files-rendering-geometry.adb", 584);
         Require_At_Most ("files-rendering-build_frame_commands.adb", 671);
         Require_At_Most ("files-application-windows.adb", 1_000);
      end;
   end Check_Rendering_Architecture;
