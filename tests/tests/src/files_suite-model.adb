with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Interfaces.C.Strings;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Features;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Files.Quick_Look;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Files.Type_Ahead;
with Guikit.Input;
with Files.Types;
with Files.UTF8;
with Files.UI;
with Files_Suite.Support;

package body Files_Suite.Model is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_32;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Command_Placement;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Application.Run_Mode;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Guikit.Draw.Accessibility_Role;
   use type Guikit.Draw.Icon_Asset_Color_Role;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Atlas_Texture_Format;
   use type Guikit.Vulkan.Texture_Source;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;
   use Files_Suite.Support;

   type Model_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Model_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Model_Test_Case);

   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Projection_Settings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Metadata_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Detection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Paging_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Type_Ahead_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Input_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Runtime_Sort_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_And_Root_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_And_Bottom_Bar_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Rename_Broadcast (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Temporary_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Content_Prep (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Model_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Group_By_Label_Bands (T : in out AUnit.Test_Cases.Test_Case'Class);
   overriding function Name (T : Model_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files model");
   end Name;

   overriding procedure Register_Tests (T : in out Model_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Sorting'Access, "directory sorting");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Projection_Settings'Access, "directory projection settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Metadata_Permissions'Access, "directory metadata permissions");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Detection'Access, "filetype detection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_View_Mode_State'Access, "view mode transitions");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Selection_Movement'Access, "selection movement and wraparound");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Grid_Paging_Selection'Access, "Home/End/Page grid selection paging and clamping");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Type_Ahead_Selection'Access, "type-ahead selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filtering_Reconciles_Selection'Access, "filtering reconciles selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_History'Access, "path history");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Input_Validation'Access, "path input validation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Runtime_Sort_State'Access, "runtime sort state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_And_Root_Selection'Access, "root selector and root selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_And_Bottom_Bar_Commands'Access, "info pane and bottom bar commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Rename_Mode'Access, "rename mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_Rename_Broadcast'Access, "synchronized multi-rename broadcast");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Temporary_State'Access, "create-file temporary item state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Error_State'Access, "error-state representation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Content_Prep'Access, "quick look content preparation classifies text, image, and info");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Model_State'Access, "quick look model open/close state tracks the selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Group_By_Label_Bands'Access,
         "group-by-label partitions the snapshot into label-band headers with items under the right band");
   end Register_Tests;

   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "sort");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "zdir"));
      Write_File (Join (Dir, "b.txt"));
      Write_File (Join (Dir, "A.txt"));
      Write_File (Join (Dir, "a.txt"));
      Write_File (Join (Root, "not-a-directory.txt"));
      Load := Files.File_System.Load_Directory (Dir, Settings);

      Assert (Load.Success, "directory load succeeds");
      Assert
        (Natural (Load.Items.Length) = 4,
         "all direct children are loaded; count=" & Natural'Image (Natural (Load.Items.Length)));
      Assert (To_String (Load.Items.Element (1).Name) = "A.txt", "directory items sort by name with files");
      Load := Files.File_System.Load_Directory (Dir & "/.", Settings);
      Assert (Load.Success, "non-normal directory path loads");
      Assert (To_String (Load.Items.Element (1).Parent_Path) = To_String (Load.Path), "item parent path is normalized");
      Assert
        (To_String (Load.Items.Element (2).Name) = "a.txt",
         "case-insensitive equal names use deterministic fallback order");
      Assert
        (To_String (Load.Items.Element (3).Name) = "b.txt",
         "fallback name order is deterministic");
      Assert (To_String (Load.Items.Element (4).Name) = "zdir", "directories remain in normal name order");

      Load := Files.File_System.Load_Directory (Join (Root, "missing-directory"), Settings);
      Assert (not Load.Success, "missing directory load reports failure");
      Assert (To_String (Load.Error_Key) = "error.directory.load", "missing directory load reports error key");
      Load := Files.File_System.Load_Directory (Join (Root, "not-a-directory.txt"), Settings);
      Assert (not Load.Success, "file path directory load reports failure");
      Assert (To_String (Load.Error_Key) = "error.directory.load", "file path directory load reports error key");
   end Test_Directory_Sorting;

   procedure Test_Directory_Projection_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "projection");
      Tie_Dir  : constant String := Join (Root, "projection-ties");
      Modified_Dir : constant String := Join (Root, "projection-modified");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "zdir"));
      Write_File (Join (Dir, "c.bin"), "cccc");
      Write_File (Join (Dir, ".secret"));
      Write_File (Join (Dir, ".profile"));
      Write_File (Join (Dir, "afile.txt"), "a");
      Files.Settings.Add_Extension_Mapping (Settings, "profile", "text/x-profile");
      Files.Settings.Add_Extension_Mapping (Settings, "bin", "application/x-bin");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Load.Success, "directory projection loads");
      Assert (Natural (Load.Items.Length) = 3, "hidden files are hidden by default");
      Assert (To_String (Load.Items.Element (1).Name) = "afile.txt", "name ordering can sort files before dirs");
      Assert (To_String (Load.Items.Element (2).Name) = "c.bin", "name sort keeps files in deterministic order");
      Assert (To_String (Load.Items.Element (3).Name) = "zdir", "directory follows file when name sort wins");

      Settings.Sort_Field_Value := Files.Settings.Sort_By_Filetype;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "c.bin", "filetype sort uses configured field");
      Assert (To_String (Load.Items.Element (2).Name) = "zdir", "filetype ties fall back to name order");
      Assert (To_String (Load.Items.Element (3).Name) = "afile.txt", "text file sorts after inode/filetype entries");

      Settings.Sort_Field_Value := Files.Settings.Sort_By_Size;
      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "c.bin", "descending size sort uses metadata");
      Assert (To_String (Load.Items.Element (2).Name) = "afile.txt", "smaller file follows larger file");

      Settings.Show_Hidden_Files := True;
      Settings.Sort_Field_Value := Files.Settings.Sort_By_Name;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Natural (Load.Items.Length) = 5, "show-hidden setting exposes dot files");
      Assert (To_String (Load.Items.Element (1).Name) = ".profile", "hidden file participates in stable sorting");
      Assert (To_String (Load.Items.Element (2).Name) = ".secret", "leading-dot files sort deterministically");
      Assert
        (To_String (Load.Items.Element (1).Filetype) = "application/octet-stream",
         "leading-dot file loaded from disk does not use extension mapping");

      Ada.Directories.Create_Path (Join (Dir, ".vault"));
      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Natural (Load.Items.Length) = 3, "hidden directories are hidden by default");

      Settings.Show_Hidden_Files := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Natural (Load.Items.Length) = 6, "show-hidden setting exposes dot directories");
      Assert (To_String (Load.Items.Element (1).Name) = ".profile", "hidden files sort by name with other items");
      Assert (To_String (Load.Items.Element (2).Name) = ".secret", "hidden files remain in deterministic order");
      Assert (To_String (Load.Items.Element (3).Name) = ".vault", "hidden directories sort by name with files");

      Ada.Directories.Create_Path (Tie_Dir);
      Write_File (Join (Tie_Dir, "B_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "a_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "later.txt"), "larger");

      Settings.Show_Hidden_Files := False;
      Settings.Sort_Field_Value := Files.Settings.Sort_By_Size;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "a_equal.txt", "ascending size ties use name fallback");
      Assert (To_String (Load.Items.Element (2).Name) = "B_equal.txt", "ascending size tie fallback is deterministic");
      Assert (To_String (Load.Items.Element (3).Name) = "later.txt", "ascending size places larger item after ties");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "later.txt", "descending size places larger item first");
      Assert
        (To_String (Load.Items.Element (2).Name) = "a_equal.txt",
         "descending size ties keep deterministic name fallback");
      Assert
        (To_String (Load.Items.Element (3).Name) = "B_equal.txt",
         "descending size tie fallback remains stable");

      Settings.Sort_Field_Value := Files.Settings.Sort_By_Modified;
      Settings.Sort_Ascending := True;
      Ada.Directories.Create_Path (Modified_Dir);
      Write_File (Join (Modified_Dir, "old.txt"), "older");
      Write_File (Join (Modified_Dir, "new.txt"), "newer");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Join (Modified_Dir, "old.txt"),
         GNAT.OS_Lib.GM_Time_Of
           (Year   => 2020,
            Month  => 1,
            Day    => 1,
            Hour   => 0,
            Minute => 0,
            Second => 0));
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Join (Modified_Dir, "new.txt"),
         GNAT.OS_Lib.GM_Time_Of
           (Year   => 2022,
            Month  => 1,
            Day    => 1,
            Hour   => 0,
            Minute => 0,
            Second => 0));
      Load := Files.File_System.Load_Directory (Modified_Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "old.txt", "modified sort orders older item first");
      Assert (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name) = "new.txt",
              "modified sort orders newer item last");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Modified_Dir, Settings);
      Assert (To_String (Load.Items.Element (1).Name) = "new.txt", "descending modified sort orders newer item first");
      Assert (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name) = "old.txt",
              "descending modified sort orders older item last");
   end Test_Directory_Projection_Settings;

   procedure Test_Directory_Metadata_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  The "extra info" is now computed lazily (not stored on load), so tests
      --  compute it on demand via the shared token function.
      function Item_Extra (I : Files.File_System.Directory_Item) return String is
        (Files.File_System.Extra_Info_Token
           (To_String (I.Full_Path), I.Kind, To_String (I.Filetype)));
      Run_Path  : constant String := Join (Root, "run.sh");
      Text_Path : constant String := Join (Root, "plain.txt");
      Long_Text_Path : constant String := Join (Root, "long-line.txt");
      Utf8_Path : constant String := Join (Root, "utf8.txt");
      Binary_Text_Path : constant String := Join (Root, "binary.txt");
      Late_Binary_Text_Path : constant String := Join (Root, "late-binary.txt");
      Split_Utf8_Path : constant String := Join (Root, "split-utf8.txt");
      Overlong_Text_Path : constant String := Join (Root, "overlong.txt");
      Surrogate_Text_Path : constant String := Join (Root, "surrogate.txt");
      Markdown_Path : constant String := Join (Root, "notes.md");
      Png_Path  : constant String := Join (Root, "picture.png");
      Jpeg_Path : constant String := Join (Root, "photo.jpg");
      Pdf_Path  : constant String := Join (Root, "paper.pdf");
      Pdf_Control_Path : constant String := Join (Root, "paper-control.pdf");
      Zip_Path  : constant String := Join (Root, "bundle.zip");
      Split_Zip_Path : constant String := Join (Root, "split.zip");
      Docx_Path : constant String := Join (Root, "report.docx");
      Xlsx_Path : constant String := Join (Root, "sheet.xlsx");
      Mp3_Path  : constant String := Join (Root, "track.mp3");
      Mp4_Path  : constant String := Join (Root, "clip.mp4");
      Tar_Gz_Path : constant String := Join (Root, "archive.tar.gz");
      Ada_Path  : constant String := Join (Root, "unit.adb");
      Json_Path : constant String := Join (Root, "data.json");
      Xml_Path  : constant String := Join (Root, "doc.xml");
      Symlink_Path : constant String := Join (Root, "link-to-plain.adb");
      Executable_Symlink_Path : constant String := Join (Root, "link-to-run.sh");
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Run : Boolean := False;
      Found_Symlink : Boolean := False;
      Found_Executable_Symlink : Boolean := False;
      Symlink_Created : Boolean := False;
      Executable_Symlink_Created : Boolean := False;
      Found_Long_Text : Boolean := False;
      Found_Utf8 : Boolean := False;
      Found_Binary_Text : Boolean := False;
      Found_Late_Binary_Text : Boolean := False;
      Found_Split_Utf8 : Boolean := False;
      Found_Overlong_Text : Boolean := False;
      Found_Surrogate_Text : Boolean := False;
      Found_Markdown : Boolean := False;
      Found_Png : Boolean := False;
      Found_Jpeg : Boolean := False;
      Found_Dir : Boolean := False;
      Found_Pdf : Boolean := False;
      Found_Pdf_Control : Boolean := False;
      Found_Zip : Boolean := False;
      Found_Split_Zip : Boolean := False;
      Found_Docx : Boolean := False;
      Found_Xlsx : Boolean := False;
      Found_Mp3 : Boolean := False;
      Found_Mp4 : Boolean := False;
      Found_Tar_Gz : Boolean := False;
      Found_Ada : Boolean := False;
      Found_Json : Boolean := False;
      Found_Xml : Boolean := False;
      Metadata_Policy : constant Files.File_System.Filetype_Metadata_Policy :=
        Files.File_System.Filetype_Metadata_Policy_Of_Current_Implementation;
   begin
      Assert (Metadata_Policy.Uses_Extension_Mapping, "metadata policy uses extension mappings");
      Assert (not Metadata_Policy.Uses_Mime_Sniffing, "metadata policy does not claim MIME sniffing");
      Assert (Metadata_Policy.Parses_Image_Dimensions, "metadata policy parses image dimensions");
      Assert (Metadata_Policy.Parses_Text_Encoding, "metadata policy parses text encoding");
      Assert (Metadata_Policy.Parses_Archive_Entry_Count, "metadata policy parses archive entry counts");
      Assert (Metadata_Policy.Parses_Pdf_Page_Markers, "metadata policy parses PDF page markers");
      Assert (not Metadata_Policy.Parses_Media_Codecs, "metadata policy does not claim media codecs");
      Assert (Metadata_Policy.Parses_Office_Package_Info, "metadata policy parses Office package info");
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "folder"));
      Write_File (Join (Join (Root, "folder"), "inside.txt"));
      Write_File (Run_Path, "echo run");
      Write_File (Text_Path, "plain");
      Write_File (Long_Text_Path, String'(1 .. 2048 => 'x'));
      Write_Binary_File (Utf8_Path, "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Binary_Text_Path, "bad" & Character'Val (16#C3#));
      Write_Binary_File (Late_Binary_Text_Path, String'(1 .. 4096 => 'x') & Character'Val (0));
      Write_Binary_File
        (Split_Utf8_Path,
         String'(1 .. 4095 => 'x') & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File
        (Overlong_Text_Path,
         "bad" & Character'Val (16#E0#) & Character'Val (16#80#) & Character'Val (16#80#));
      Write_Binary_File
        (Surrogate_Text_Path,
         "bad" & Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Write_File (Markdown_Path, "# Title" & ASCII.LF & "body");
      Write_Binary_File (Png_Path, Minimal_Png_Header (32, 16));
      Write_Binary_File (Jpeg_Path, Minimal_Jpeg_With_Fill (48, 24));
      Write_File
        (Pdf_Path,
         "%PDF-1.7" & ASCII.LF &
         "1 0 obj /Type /Pages endobj" & ASCII.LF &
         "2 0 obj /Type /Page endobj");
      Write_File
        (Pdf_Control_Path,
         "%PDF-1.7" & ASCII.LF &
         "1 0 obj /Type /Page" & ASCII.VT & "endobj" & ASCII.LF &
         "2 0 obj /Type /Page" & ASCII.FF & "endobj");
      Write_Binary_File (Zip_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File
        (Split_Zip_Path,
         String'(1 .. 4094 => 'x') & "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Docx_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Xlsx_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_File (Mp3_Path, "ID3");
      Write_File (Mp4_Path, "....ftyp");
      Write_Binary_File (Tar_Gz_Path, Character'Val (16#1F#) & Character'Val (16#8B#) & "gzip");
      Write_File (Ada_Path, "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Json_Path, "{""ok"":true}");
      Write_File (Xml_Path, "<root/>");
      GNAT.OS_Lib.Set_Executable (Run_Path);
      Symlink_Created := Create_Symlink ("plain.txt", Symlink_Path);
      Executable_Symlink_Created := Create_Symlink ("run.sh", Executable_Symlink_Path);

      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "directory metadata load succeeds");

      for Item of Load.Items loop
         if To_String (Item.Name) = "run.sh" then
            declare
               Permissions : constant String := To_String (Item.Permissions);
            begin
               Found_Run := True;
               Assert (Item.Kind = Files.Types.Executable_Item, "executable metadata affects item kind");
               Assert (Item.Modified_Available, "modified timestamp is available");
               Assert (Item.Size_Available, "file size is available");
               if Item.Creation_Available then
                  Assert
                    (Item.Creation_Time >= Ada.Calendar.Time_Of (1970, 1, 1),
                     "creation timestamp is populated when the filesystem reports it");
               else
                  Assert
                    (Item.Creation_Time = Ada.Calendar.Time_Of (1901, 1, 1),
                     "missing creation timestamp keeps deterministic sentinel");
               end if;
               Assert (Permissions'Length = 3, "permission metadata has stable rwx shape");
               Assert (Permissions (3) = 'x', "executable permission is captured");
            end;
         elsif To_String (Item.Name) = "plain.txt" then
            Assert (To_String (Item.Permissions)'Length = 3, "regular file permissions are captured");
         elsif To_String (Item.Name) = "link-to-plain.adb" then
            Found_Symlink := True;
            Assert (Item.Kind = Files.Types.Symlink_Item, "symlink metadata affects item kind");
            Assert
              (To_String (Item.Filetype) = "inode/symlink",
               "real symlink directory item ignores extension mappings");
            Assert (To_String (Item.Icon_Id) = "link", "real symlink directory item uses link icon");
            Assert
              (Item_Extra (Item) = "symlink.target|plain.txt",
               "real symlink directory item records target metadata");
         elsif To_String (Item.Name) = "link-to-run.sh" then
            Found_Executable_Symlink := True;
            Assert
              (Item.Kind = Files.Types.Symlink_Item,
               "executable symlink metadata keeps symlink kind");
            Assert
              (To_String (Item.Filetype) = "inode/symlink",
               "executable symlink filetype wins before executable metadata");
            Assert
              (Item_Extra (Item) = "symlink.target|run.sh",
               "executable symlink records target metadata");
         elsif To_String (Item.Name) = "long-line.txt" then
            Found_Long_Text := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|ascii",
               "long text lines count as one physical line");
         elsif To_String (Item.Name) = "utf8.txt" then
            Found_Utf8 := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|utf8",
               "UTF-8 text files expose text encoding metadata");
         elsif To_String (Item.Name) = "binary.txt" then
            Found_Binary_Text := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|binary",
               "invalid text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "late-binary.txt" then
            Found_Late_Binary_Text := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|binary",
               "text encoding metadata scans beyond the first read buffer");
         elsif To_String (Item.Name) = "split-utf8.txt" then
            Found_Split_Utf8 := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|utf8",
               "text encoding metadata accepts UTF-8 split across read buffers");
         elsif To_String (Item.Name) = "overlong.txt" then
            Found_Overlong_Text := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|binary",
               "overlong UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "surrogate.txt" then
            Found_Surrogate_Text := True;
            Assert
              (Item_Extra (Item) = "text.lines_encoding|1|binary",
               "surrogate UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "notes.md" then
            Found_Markdown := True;
            Assert
              (Item_Extra (Item) = "markdown.lines_encoding|2|ascii",
               "Markdown files expose markdown line and encoding metadata");
         elsif To_String (Item.Name) = "picture.png" then
            Found_Png := True;
            Assert
              (Item_Extra (Item) = "image.dimensions|32x16",
               "PNG dimensions are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "photo.jpg" then
            Found_Jpeg := True;
            Assert
              (Item_Extra (Item) = "image.dimensions|48x24",
               "JPEG dimensions tolerate fill bytes before frame markers");
         elsif To_String (Item.Name) = "folder" then
            Found_Dir := True;
            Assert
              (Item_Extra (Item) = "directory.count|1",
               "directory item counts are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "paper.pdf" then
            Found_Pdf := True;
            Assert (To_String (Item.Filetype) = "application/pdf", "PDF extension maps to filetype");
            Assert
              (Item_Extra (Item) = "document.pdf.pages|1",
               "PDF files expose page marker metadata");
         elsif To_String (Item.Name) = "paper-control.pdf" then
            Found_Pdf_Control := True;
            Assert
              (Item_Extra (Item) = "document.pdf.pages|2",
               "PDF page markers accept vertical tab and form feed separators");
         elsif To_String (Item.Name) = "bundle.zip" then
            Found_Zip := True;
            Assert (To_String (Item.Filetype) = "application/zip", "ZIP extension maps to filetype");
            Assert
              (Item_Extra (Item) = "archive.zip.entries|1",
               "ZIP files expose entry-count metadata");
         elsif To_String (Item.Name) = "split.zip" then
            Found_Split_Zip := True;
            Assert
              (Item_Extra (Item) = "archive.zip.entries|1",
               "ZIP entry counting detects signatures split across read buffers");
         elsif To_String (Item.Name) = "report.docx" then
            Found_Docx := True;
            Assert
              (To_String (Item.Filetype) =
               "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
               "DOCX extension maps to filetype");
            Assert
              (Item_Extra (Item) = "office.docx.entries|1",
               "DOCX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "sheet.xlsx" then
            Found_Xlsx := True;
            Assert
              (To_String (Item.Filetype) =
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
               "XLSX extension maps to filetype");
            Assert
              (Item_Extra (Item) = "office.xlsx.entries|1",
               "XLSX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "track.mp3" then
            Found_Mp3 := True;
            Assert (To_String (Item.Filetype) = "audio/mpeg", "MP3 extension maps to filetype");
            Assert
              (Item_Extra (Item) = "media.kind|audio",
               "MP3 files expose audio metadata");
         elsif To_String (Item.Name) = "clip.mp4" then
            Found_Mp4 := True;
            Assert (To_String (Item.Filetype) = "video/mp4", "MP4 extension maps to filetype");
            Assert
              (Item_Extra (Item) = "media.kind|video",
               "MP4 files expose video metadata");
         elsif To_String (Item.Name) = "archive.tar.gz" then
            Found_Tar_Gz := True;
            Assert (To_String (Item.Filetype) = "application/gzip-tar", "compound extension maps to filetype");
            Assert
              (Item_Extra (Item) = "archive.format|gzip",
               "compound gzip-tar archive files expose gzip format metadata");
         elsif To_String (Item.Name) = "unit.adb" then
            Found_Ada := True;
            Assert (To_String (Item.Filetype) = "text/x-ada", "Ada body extension maps to filetype");
            Assert
              (Item_Extra (Item) = "source.ada.lines_encoding|4|ascii",
               "Ada source files expose source metadata");
         elsif To_String (Item.Name) = "data.json" then
            Found_Json := True;
            Assert (To_String (Item.Filetype) = "application/json", "JSON extension maps to filetype");
            Assert
              (Item_Extra (Item) = "source.json.lines_encoding|1|ascii",
               "JSON files expose source metadata");
         elsif To_String (Item.Name) = "doc.xml" then
            Found_Xml := True;
            Assert (To_String (Item.Filetype) = "application/xml", "XML extension maps to filetype");
            Assert
              (Item_Extra (Item) = "source.xml.lines_encoding|1|ascii",
               "XML files expose source metadata");
         end if;
      end loop;

      Assert (Found_Run, "executable item was loaded");
      if Symlink_Created then
         Assert (Found_Symlink, "symlink item was loaded");
      end if;
      if Executable_Symlink_Created then
         Assert (Found_Executable_Symlink, "executable symlink item was loaded");
      end if;
      Assert (Found_Long_Text, "long text line item was loaded");
      Assert (Found_Utf8, "UTF-8 text item was loaded");
      Assert (Found_Binary_Text, "binary text item was loaded");
      Assert (Found_Late_Binary_Text, "late binary text item was loaded");
      Assert (Found_Split_Utf8, "split UTF-8 text item was loaded");
      Assert (Found_Overlong_Text, "overlong UTF-8 text item was loaded");
      Assert (Found_Surrogate_Text, "surrogate UTF-8 text item was loaded");
      Assert (Found_Markdown, "Markdown item was loaded");
      Assert (Found_Png, "PNG item was loaded");
      Assert (Found_Jpeg, "JPEG item was loaded");
      Assert (Found_Dir, "directory item was loaded");
      Assert (Found_Pdf, "PDF item was loaded");
      Assert (Found_Pdf_Control, "PDF control-whitespace item was loaded");
      Assert (Found_Zip, "ZIP item was loaded");
      Assert (Found_Split_Zip, "split ZIP item was loaded");
      Assert (Found_Docx, "DOCX item was loaded");
      Assert (Found_Xlsx, "XLSX item was loaded");
      Assert (Found_Mp3, "MP3 item was loaded");
      Assert (Found_Mp4, "MP4 item was loaded");
      Assert (Found_Tar_Gz, "compound archive item was loaded");
      Assert (Found_Ada, "Ada item was loaded");
      Assert (Found_Json, "JSON item was loaded");
      Assert (Found_Xml, "XML item was loaded");
   end Test_Directory_Metadata_Permissions;

   procedure Test_Filetype_Detection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Directory_Item : constant Files.File_System.Directory_Item :=
        Files.File_System.Make_Item (Root, "src", Files.Types.Directory_Item);
      Symlink_Item : constant Files.File_System.Directory_Item :=
        Files.File_System.Make_Item (Root, "link.adb", Files.Types.Symlink_Item);
      Executable_Item : constant Files.File_System.Directory_Item :=
        Files.File_System.Make_Item (Root, "run", Files.Types.Executable_Item);
      Regular_Item : constant Files.File_System.Directory_Item :=
        Files.File_System.Make_Item ("", "loose.txt", Files.Types.Regular_File_Item);
      Ada_Item : Files.File_System.Directory_Item;
      Executable_Ada_Item : Files.File_System.Directory_Item;
      Symlink_Ada_Item : Files.File_System.Directory_Item;
      C1_Break : constant Character := Character'Val (133);
      NBSP : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      Line_Separator : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#2028#));
   begin
      Files.Settings.Add_Extension_Mapping (Settings, "adb", "text/x-ada");
      Files.Settings.Add_Extension_Mapping (Settings, "profile", "text/x-profile");
      Files.Settings.Add_Icon_Mapping (Settings, "text/x-ada", "ada");
      Ada_Item := Files.File_System.Make_Item (Root, "main.adb", Files.Types.Regular_File_Item, Settings);
      Executable_Ada_Item := Files.File_System.Make_Item (Root, "tool.adb", Files.Types.Executable_Item, Settings);
      Symlink_Ada_Item := Files.File_System.Make_Item (Root, "link.adb", Files.Types.Symlink_Item, Settings);
      Assert
        (To_String (Directory_Item.Filetype) = "inode/directory",
         "directory helper item gets directory filetype");
      Assert (To_String (Directory_Item.Icon_Id) = "folder", "directory helper item gets directory icon");
      Assert
        (To_String (Symlink_Item.Filetype) = "inode/symlink",
         "symlink helper item gets symlink filetype before extension mapping");
      Assert (To_String (Symlink_Item.Icon_Id) = "link", "symlink helper item gets symlink icon");
      Assert
        (To_String (Executable_Item.Filetype) = "application/x-executable",
         "executable helper item gets executable filetype");
      Assert (To_String (Executable_Item.Icon_Id) = "executable", "executable helper item gets executable icon");
      Assert
        (To_String (Executable_Ada_Item.Filetype) = "application/x-executable",
         "settings-aware executable helper item ignores extension mappings");
      Assert
        (To_String (Executable_Ada_Item.Icon_Id) = "executable",
         "settings-aware executable helper item keeps executable icon");
      Assert
        (To_String (Symlink_Ada_Item.Filetype) = "inode/symlink",
         "settings-aware symlink helper item ignores extension mappings");
      Assert
        (To_String (Symlink_Ada_Item.Icon_Id) = "link",
         "settings-aware symlink helper item keeps symlink icon");
      Assert
        (To_String (Regular_Item.Filetype) = "text/plain",
         "regular helper item uses default extension mapping");
      Assert (To_String (Regular_Item.Icon_Id) = "text", "regular helper item uses mapped text icon");
      Assert
        (To_String (Ada_Item.Filetype) = "text/x-ada",
         "settings-aware helper item uses custom extension mapping");
      Assert (To_String (Ada_Item.Icon_Id) = "ada", "settings-aware helper item uses custom icon mapping");
      Assert
        (To_String (Regular_Item.Full_Path) = "loose.txt",
         "helper item with empty parent uses simple path");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Directory_Item, "src") = "inode/directory",
         "directory filetype wins before extension mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Executable_Item, "tool.adb") =
           "application/x-executable",
         "executable filetype wins before extension mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Symlink_Item, "link.adb") = "inode/symlink",
         "symlink filetype wins before extension mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "main.adb") = "text/x-ada",
         "extension mapping is used for regular files");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "MAIN.ADB") = "text/x-ada",
         "filetype detection normalizes filename extension case before mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "archive.tar.gz") =
           "application/gzip-tar",
         "compound extension mapping wins over final suffix mapping");
      Assert (Files.File_Types.Extension_Of ("archive.tar.gz") = "gz", "final extension is extracted");
      Assert (Files.File_Types.Extension_Of ("MAIN.ADB") = "adb", "extension extraction normalizes case");
      Assert (Files.File_Types.Extension_Of (".profile") = "", "leading-dot file has no extension");
      Assert (Files.File_Types.Extension_Of ("name.") = "", "trailing-dot file has no extension");
      Assert (Files.File_Types.Extension_Of (" main.adb ") = "adb", "extension extraction trims whitespace");
      Assert
        (Files.File_Types.Extension_Of (ASCII.LF & "main.adb" & ASCII.LF) = "adb",
         "extension extraction trims line-feed whitespace");
      Assert
        (Files.File_Types.Extension_Of (ASCII.VT & "main.adb" & ASCII.FF) = "adb",
         "extension extraction trims vertical-tab and form-feed whitespace");
      Assert
        (Files.File_Types.Extension_Of (C1_Break & "main.adb" & C1_Break) = "adb",
         "extension extraction trims C1 line-break whitespace");
      Assert
        (Files.File_Types.Extension_Of (NBSP & "main.adb" & NBSP) = "adb",
         "extension extraction trims UTF-8 NBSP whitespace");
      Assert
        (Files.File_Types.Extension_Of (Line_Separator & "main.adb" & Line_Separator) = "adb",
         "extension extraction trims UTF-8 line-separator whitespace");
      Assert (Files.File_Types.Extension_Of ("   ") = "", "blank filename has no extension");
      Assert
        (Files.File_Types.Extension_Of ("/tmp/dir.with.dots/main.adb") = "adb",
         "extension extraction uses the Unix path leaf name");
      Assert
        (Files.File_Types.Extension_Of ("C:\tmp\dir.with.dots\main.adb") = "adb",
         "extension extraction uses the Windows path leaf name");
      Assert
        (Files.File_Types.Extension_Of ("/tmp/dir.with.dots/file") = "",
         "extension extraction ignores dotted directory names");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, ".profile") =
         "application/octet-stream",
         "leading-dot file does not match an extension mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            "/tmp/dir.with.dots/main.adb") = "text/x-ada",
         "filetype detection uses the Unix path leaf name");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            "C:\tmp\dir.with.dots\main.adb") = "text/x-ada",
         "filetype detection uses the Windows path leaf name");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            "/tmp/dir.with.dots/file") = "application/octet-stream",
         "filetype detection ignores dotted directory names");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, " main.adb ") = "text/x-ada",
         "filetype detection trims filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Unknown_Item, "mystery.adb") = "text/x-ada",
         "unknown item filetype still uses configured extension mappings");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Other_Item, "socket") = "application/octet-stream",
         "other item filetype falls back deterministically without mapping");
      Files.Settings.Add_Extension_Mapping (Settings, "backup.tar.gz", "application/x-backup");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "weekly.backup.tar.gz") =
           "application/x-backup",
         "custom compound extension mapping uses the longest configured suffix");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            ASCII.LF & "main.adb" & ASCII.LF) = "text/x-ada",
         "filetype detection trims line-feed filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            ASCII.VT & "main.adb" & ASCII.FF) = "text/x-ada",
         "filetype detection trims vertical-tab and form-feed filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            C1_Break & "main.adb" & C1_Break) = "text/x-ada",
         "filetype detection trims C1 line-break filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            NBSP & "main.adb" & NBSP) = "text/x-ada",
         "filetype detection trims UTF-8 NBSP filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype
           (Settings,
            Files.Types.Regular_File_Item,
            Line_Separator & "main.adb" & Line_Separator) = "text/x-ada",
         "filetype detection trims UTF-8 line-separator filename whitespace before mapping");
      Assert
        (Files.File_Types.Detect_Filetype (Settings, Files.Types.Regular_File_Item, "blob.bin") =
           "application/octet-stream",
         "unknown extension falls back deterministically");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, "inode/symlink") = "link",
         "symlink icon mapping is used");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, " inode/symlink ") = "link",
         "icon classification trims filetype whitespace before mapping");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Regular_File_Item, " text/x-ada ") = "ada",
         "mapped regular-file icon classification trims filetype whitespace");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Regular_File_Item, "application/x-custom") =
           "unknown",
         "unmapped regular-file icon falls back deterministically");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Directory_Item, "") = "folder",
         "directory icon falls back by item kind without mapping");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Symlink_Item, "") = "link",
         "symlink icon falls back by item kind without mapping");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Executable_Item, "") = "executable",
         "executable icon falls back by item kind without mapping");
      Assert
        (Files.File_Types.Icon_Id_For (Settings, Files.Types.Other_Item, "") = "unknown",
         "other item icon falls back deterministically without mapping");
   end Test_Filetype_Detection;

   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Large_Icons, "large icons can be selected");
      Files.Commands.Execute (Files.Commands.Select_Details_Command, Model);
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "details command selects details");
      Files.Commands.Execute (Files.Commands.Select_Small_Icons_Command, Model);
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons, "small command clears prior mode");
   end Test_View_Mode_State;

   procedure Test_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result     : Files.Controller.Controller_Result;
      Ctrl       : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Shift      : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl_Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Shift (Guikit.Input.Shift_Key) := True;
      Ctrl_Shift (Guikit.Input.Control_Key) := True;
      Ctrl_Shift (Guikit.Input.Shift_Key) := True;
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Assert (Files.Model.Selected_Index (Model) = 1, "first movement selects first visible item");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Left);
      Assert (Files.Model.Selected_Index (Model) = 3, "left from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Assert (Files.Model.Selected_Index (Model) = 1, "right from last wraps to first");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Up);
      Assert (Files.Model.Selected_Index (Model) = 3, "up from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Assert (Files.Model.Selected_Index (Model) = 1, "right from last wraps to first after up wrap");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Assert (Files.Model.Selected_Index (Model) = 2, "down advances selection");
      declare
         Grid_Items : Files.File_System.Item_Vectors.Vector := Sample_Items;
         Grid_Model : Files.Model.Window_Model;
      begin
         Grid_Items.Append
           (Files.File_System.Make_Item (Root, "Kappa.txt", Files.Types.Regular_File_Item, "text/plain"));
         Grid_Items.Append
           (Files.File_System.Make_Item (Root, "Lambda.txt", Files.Types.Regular_File_Item, "text/plain"));
         Files.Model.Initialize
           (Grid_Model,
            Directory_Path    => Root,
            Items             => Grid_Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         Files.Model.Set_Selection_Grid_Columns (Grid_Model, 2);
         Assert (Files.Model.Selection_Grid_Columns (Grid_Model) = 2, "model records rendered grid columns");
         Files.Model.Select_Visible (Grid_Model, 1);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Assert (Files.Model.Selected_Index (Grid_Model) = 3, "down moves to same column in next grid row");
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Up);
         Assert (Files.Model.Selected_Index (Grid_Model) = 1, "up moves to same column in previous grid row");
         Files.Model.Select_Visible (Grid_Model, 5);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Assert (Files.Model.Selected_Index (Grid_Model) = 1, "down from last grid item wraps to first");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Assert (Files.Model.Selected_Count (Model) = 2, "toggle adds a second deterministic selection");
      Assert (Files.Model.Is_Selected (Model, 1), "first toggled item is selected");
      Assert (Files.Model.Is_Selected (Model, 2), "primary item remains selected");
      declare
         Selected_Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      begin
         Assert (Natural (Selected_Items.Length) = 2, "selected items API returns all selected items");
         Assert (To_String (Selected_Items.Element (1).Name) = "Alpha.txt", "selected items use item order");
         Assert (To_String (Selected_Items.Element (2).Name) = "Beta.txt", "selected items include primary item");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Selected_Count (Model) = 1, "toggle removes selected item");
      Assert (Files.Model.Selected_Index (Model) = 1, "primary selection falls back to remaining selected item");
      Files.Model.Clear_Selection (Model);
      Assert (Files.Model.Selected_Count (Model) = 0, "clear selection empties deterministic selection set");
      Files.Model.Select_Visible (Model, 2);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "controller arrow moves selection");
      Assert (Files.Model.Selected_Index (Model) = 3, "controller down advances selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "shift-down expands selection");
      Assert (Files.Model.Selected_Index (Model) = 2, "shift-down moves primary selection to target item");
      Assert (Files.Model.Selected_Count (Model) = 2, "shift-down keeps anchor and target selected");
      Assert (Files.Model.Is_Selected (Model, 1), "shift-down keeps anchor item selected");
      Assert (Files.Model.Is_Selected (Model, 2), "shift-down selects target item");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "second shift-down expands selection");
      Assert (Files.Model.Selected_Index (Model) = 3, "second shift-down moves primary selection to next item");
      Assert (Files.Model.Selected_Count (Model) = 3, "second shift-down preserves range anchor");
      Assert (Files.Model.Is_Selected (Model, 1), "second shift-down keeps original anchor selected");
      Assert (Files.Model.Is_Selected (Model, 3), "second shift-down selects new target item");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Modifiers => Ctrl);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "control-click toggles selection");
      Assert (Files.Model.Selected_Count (Model) = 2, "control-click adds to selection");
      Assert (Files.Model.Is_Selected (Model, 1), "control-click selects clicked item");
      Assert (Files.Model.Is_Selected (Model, 3), "control-click preserves existing selection");
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Ctrl);
      Assert (Files.Model.Selected_Count (Model) = 1, "second control-click removes selected item");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Assert (Files.Model.Selected_Count (Model) = 3, "range selection selects every visible item");
      Assert (Files.Model.Is_Selected (Model, 1), "range selection includes anchor");
      Assert (Files.Model.Is_Selected (Model, 2), "range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "range selection includes target");
      Files.Model.Select_Visible_Range (Model, 3, 1);
      Assert (Files.Model.Selected_Count (Model) = 3, "reverse range selection selects every visible item");
      Assert (Files.Model.Selected_Index (Model) = 1, "reverse range selection makes target primary");
      Assert (Files.Model.Is_Selected (Model, 1), "reverse range selection includes target");
      Assert (Files.Model.Is_Selected (Model, 2), "reverse range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "reverse range selection includes anchor");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 3, "select-all selects every visible loaded item");
      Assert (Files.Model.Selected_Index (Model) = 1, "select-all keeps first visible item primary");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 1, "select-all respects visible filter projection");
      Assert (Files.Model.Selected_Name (Model) = "Alpha.txt", "filtered select-all selects visible item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl);
      Assert (Result.Command = Files.Commands.Select_All_Command, "Control+A routes select-all command");
      Assert (Files.Model.Selected_Count (Model) = 3, "Control+A selects all visible loaded items");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_Visible (Model, 1);
      Assert (Files.Model.Selected_Count (Model) = 1, "invert test starts with a single selection");
      Files.Model.Invert_Selection (Model);
      Assert (Files.Model.Selected_Count (Model) = 2, "invert selects the previously unselected visible items");
      Assert (not Files.Model.Is_Selected (Model, 1), "invert unselects the previously selected item");
      Assert (Files.Model.Is_Selected (Model, 2), "invert selects a previously unselected item");
      Assert (Files.Model.Is_Selected (Model, 3), "invert selects the remaining unselected item");
      Files.Model.Invert_Selection (Model);
      Assert (Files.Model.Selected_Count (Model) = 1, "second invert restores the original selection count");
      Assert (Files.Model.Is_Selected (Model, 1), "second invert restores the original selected item");
      Assert (not Files.Model.Is_Selected (Model, 2), "second invert clears the intermediate selection");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Clear_Selection (Model);
      Files.Model.Invert_Selection (Model);
      Assert (Files.Model.Selected_Count (Model) = 1, "invert only touches visible filtered items");
      Assert (Files.Model.Selected_Name (Model) = "Alpha.txt", "invert selects the visible filtered item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_I, Ctrl);
      Assert (Result.Command = Files.Commands.Invert_Selection_Command, "Control+I routes invert-selection command");
      Files.Model.Select_All_Visible (Model);
      Assert (Files.Model.Selected_Count (Model) = 3, "deselect test starts from a full selection");
      Files.Model.Deselect_All (Model);
      Assert (Files.Model.Selected_Count (Model) = 0, "deselect all clears the selection");
      Files.Model.Select_All_Visible (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl_Shift);
      Assert (Result.Command = Files.Commands.Deselect_All_Command, "Control+Shift+A routes deselect-all command");
      Assert (Files.Model.Selected_Count (Model) = 0, "Control+Shift+A clears the selection");
      Files.Model.Select_Visible (Model, 1);
      declare
         Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Shift (Guikit.Input.Shift_Key) := True;
         Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Shift);
      end;
      Assert (Files.Model.Selected_Count (Model) = 3, "shift-click selects a deterministic visible range");
      Assert (Files.Model.Selected_Index (Model) = 3, "shift-click makes the clicked item primary");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Focus_Path_Input (Model);
      declare
         Before_Focused_Key : constant Natural := Files.Model.Selected_Index (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
         Assert (Result.Status = Files.Controller.Controller_Ignored, "focused input suppresses arrow selection");
         Assert
           (Files.Model.Selected_Index (Model) = Before_Focused_Key,
            "focused input keeps selection unchanged");
      end;
   end Test_Selection_Movement;

   procedure Test_Grid_Paging_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Paging_Model (Count : Natural) return Files.Model.Window_Model is
         Items : Files.File_System.Item_Vectors.Vector;
         Built : Files.Model.Window_Model;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.File_System.Make_Item
                 (Root,
                  "Item" & Ada.Strings.Fixed.Trim (Integer'Image (Index), Ada.Strings.Both) & ".txt",
                  Files.Types.Regular_File_Item,
                  "text/plain"));
         end loop;
         Files.Model.Initialize
           (Built,
            Directory_Path    => Root,
            Items             => Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         return Built;
      end Paging_Model;

      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Paging_Model (25);
      Home_Dir : constant String := Files.Model.Current_Path (Model);
      Result   : Files.Controller.Controller_Result;
   begin
      Assert (Files.Model.Visible_Count (Model) = 25, "paging model exposes all 25 visible items");

      --  Direct model primitives: first / last selection.
      Files.Model.Select_Last_Visible (Model);
      Assert (Files.Model.Selected_Index (Model) = 25, "Select_Last_Visible selects the last visible item");
      Files.Model.Select_First_Visible (Model);
      Assert (Files.Model.Selected_Index (Model) = 1, "Select_First_Visible selects the first visible item");

      --  Single-column paging moves by Page_Rows items and clamps at the edges.
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Assert (Files.Model.Selected_Index (Model) = 11, "PageDown advances the selection by one page (10 rows)");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Assert (Files.Model.Selected_Index (Model) = 21, "a second PageDown advances another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Assert (Files.Model.Selected_Index (Model) = 25, "PageDown clamps at the last item");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Assert (Files.Model.Selected_Index (Model) = 25, "PageDown on the last item stays put");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Assert (Files.Model.Selected_Index (Model) = 15, "PageUp retreats the selection by one page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Assert (Files.Model.Selected_Index (Model) = 5, "a second PageUp retreats another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Assert (Files.Model.Selected_Index (Model) = 1, "PageUp clamps at the first item");

      --  Grid stride: with 3 columns a page spans Page_Rows * columns items.
      Files.Model.Set_Selection_Grid_Columns (Model, 3);
      Files.Model.Select_First_Visible (Model);
      Files.Model.Move_Selection_By_Page (Model, 2, Down => True);
      Assert (Files.Model.Selected_Index (Model) = 7, "grid paging moves Page_Rows * columns items (2*3)");

      --  Empty model: paging clears rather than crashing.
      declare
         Empty : Files.Model.Window_Model := Paging_Model (0);
      begin
         Files.Model.Select_First_Visible (Empty);
         Assert (Files.Model.Selected_Index (Empty) = 0, "first-visible on an empty grid selects nothing");
         Files.Model.Move_Selection_By_Page (Empty, 10, Down => True);
         Assert (Files.Model.Selected_Index (Empty) = 0, "paging an empty grid selects nothing");
      end;

      --  Through the real controller key seam: plain Home/End move the grid
      --  selection and never navigate (Alt+Home stays the navigate-home key).
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "plain End moves the grid selection");
      Assert (Files.Model.Selected_Index (Model) = 25, "plain End selects the last visible item");
      Assert (Files.Model.Current_Path (Model) = Home_Dir, "plain End does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "plain Home moves the grid selection");
      Assert (Files.Model.Selected_Index (Model) = 1, "plain Home selects the first visible item");
      Assert (Files.Model.Current_Path (Model) = Home_Dir, "plain Home does not navigate home (that stays Alt+Home)");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "plain Home on the first item is ignored");

      --  Alt+Home remains the navigate-home shortcut, distinct from plain Home.
      Assert
        (Files.Commands.Find_By_Shortcut
           (Guikit.Input.Key_Home, [Guikit.Input.Alt_Key => True, others => False])
           = Files.Commands.Navigate_Home_Command,
         "Alt+Home is still bound to navigate-home");
   end Test_Grid_Paging_Selection;

   procedure Test_Type_Ahead_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Six-item projection with several names sharing a "d" prefix so the
      --  refine and repeated-letter cycling behaviours are observable.
      function Grid_Items return Files.File_System.Item_Vectors.Vector is
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append (Files.File_System.Make_Item (Root, "delta", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "Doc", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "dune", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "date", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "eagle", Files.Types.Regular_File_Item, "text/plain"));
         return Items;
      end Grid_Items;

      function New_Grid_Model return Files.Model.Window_Model is
         Model : Files.Model.Window_Model;
      begin
         Files.Model.Initialize
           (Model,
            Directory_Path    => Root,
            Items             => Grid_Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         return Model;
      end New_Grid_Model;

      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := New_Grid_Model;
      Result   : Files.Controller.Controller_Result;

      procedure Feed (Text : String) is
      begin
         Result := Files.Controller.Append_Focused_Text (Model, Text);
      end Feed;
   begin
      --  Pure matcher: first item starting with the prefix, case-insensitive.
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "do", 1) = 2,
         "matcher returns the first item starting with the prefix");
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "DO", 1) = 2,
         "matcher is case-insensitive");
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "z", 1) = 0,
         "matcher returns zero when nothing matches");
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "", 1) = 0,
         "matcher returns zero for an empty prefix");
      --  Start-index respected: "d" items sit at 1, 3, 4; scanning from 3 finds 3.
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 3) = 3,
         "matcher honours the start index inclusively");
      Assert
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 5) = 1,
         "matcher wraps around past the end of the projection");

      --  Through the seam with the grid focused (Focus_None): a bare printable
      --  character selects the first matching item.
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "fresh grid model starts unfocused");
      Feed ("d");
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "type-ahead reports a moved selection");
      Assert (Files.Model.Selected_Index (Model) = 1, "typing d selects the first d-item (delta)");

      --  A longer prefix refines to the matching item.
      Feed ("u");
      Assert (Files.Model.Selected_Index (Model) = 3, "refining to du selects dune");
      Assert (Files.Model.Type_Ahead_Buffer (Model) = "du", "buffer accumulates the refined prefix");

      --  A non-matching character leaves the selection where it was.
      Feed ("z");
      Assert (Files.Model.Selected_Index (Model) = 3, "a non-matching character keeps the current selection");

      --  Repeated single letter cycles through every item starting with it.
      Model := New_Grid_Model;
      Feed ("d");
      Assert (Files.Model.Selected_Index (Model) = 1, "first d selects delta");
      Feed ("d");
      Assert (Files.Model.Selected_Index (Model) = 2, "second d cycles to Doc");
      Feed ("d");
      Assert (Files.Model.Selected_Index (Model) = 3, "third d cycles to dune");
      Feed ("d");
      Assert (Files.Model.Selected_Index (Model) = 4, "fourth d cycles to date");
      Feed ("d");
      Assert (Files.Model.Selected_Index (Model) = 1, "fifth d wraps back to delta");

      --  Reset trigger (arrow key): a fresh keystroke starts a new prefix rather
      --  than extending the stale one.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Assert (Files.Model.Selected_Index (Model) = 3, "du selects dune before the reset");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Assert (Files.Model.Type_Ahead_Buffer (Model) = "", "an arrow key clears the type-ahead buffer");
      Assert (Files.Model.Selected_Index (Model) = 4, "arrow key moves selection to date");
      Feed ("d");
      Assert
        (Files.Model.Selected_Index (Model) = 1,
         "a keystroke after the reset starts a fresh single-letter cycle (delta)");

      --  Reset trigger (focus change): focusing a text field clears the buffer,
      --  and returning to the grid begins a fresh prefix.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Assert (Files.Model.Selected_Index (Model) = 3, "du selects dune before the focus change");
      Files.Model.Focus_Path_Input (Model);
      Assert (Files.Model.Type_Ahead_Buffer (Model) = "", "focusing a text field clears the type-ahead buffer");

      --  Typing into the focused text field edits the field and never moves the
      --  grid selection (the path input, unlike the filter, does not reproject).
      declare
         Before        : constant Natural := Files.Model.Selected_Index (Model);
         Before_Length : constant Natural := Files.Model.Path_Input_Text (Model)'Length;
      begin
         Feed ("x");
         Assert
           (Files.Model.Path_Input_Text (Model)'Length = Before_Length + 1,
            "typed text lands in the focused path input");
         Assert (Files.Model.Type_Ahead_Buffer (Model) = "", "typing into a text field never feeds type-ahead");
         Assert
           (Files.Model.Selected_Index (Model) = Before,
            "typing into a text field does not jump the grid selection");
      end;

      --  Back on the grid, a fresh keystroke starts a new prefix.
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "cancelling returns focus to the grid");
      Feed ("d");
      Assert (Files.Model.Type_Ahead_Buffer (Model) = "d", "a keystroke after the focus reset starts a fresh prefix");
   end Test_Type_Ahead_Selection;

   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model        : Files.Model.Window_Model := Sample_Model;
      Missing_Item : Files.File_System.Directory_Item;
      Result       : Files.Controller.Controller_Result;
   begin
      Missing_Item := Files.Model.Visible_Item (Model, 99);
      Assert (To_String (Missing_Item.Name) = "", "invalid visible item index returns empty item");
      Assert (Missing_Item.Kind = Files.Types.Unknown_Item, "invalid visible item index returns unknown kind");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Set_Filter (Model, "alp");
      Assert (Files.Model.Visible_Count (Model) = 1, "filter matches item names case-insensitively");
      Assert (Files.Model.Selected_Index (Model) = 1, "filtered-out selection moves to first visible item");
      Assert (Files.Model.Selected_Name (Model) = "Alpha.txt", "selection points to visible item");
      Assert (Files.Model.Is_Selected (Model, 1), "selected visible item is reported selected");
      Assert (not Files.Model.Is_Selected (Model, 2), "out-of-range visible item is not selected");
      declare
         Unicode_Items : Files.File_System.Item_Vectors.Vector := Sample_Items;
         Unicode_Model : Files.Model.Window_Model;
         Upper_Name    : constant String := Byte (16#C3#) & Byte (16#89#) & "t"
           & Byte (16#C3#) & Byte (16#A9#) & ".txt";
         Lower_Query   : constant String := Byte (16#C3#) & Byte (16#A9#) & "t"
           & Byte (16#C3#) & Byte (16#A9#);
      begin
         Unicode_Items.Append
           (Files.File_System.Make_Item (Root, Upper_Name, Files.Types.Regular_File_Item, "text/plain"));
         Files.Model.Initialize (Unicode_Model, Root, Unicode_Items, Root, Files.Types.Small_Icons);
         Files.Model.Set_Filter (Unicode_Model, Lower_Query);
         Assert
           (Files.Model.Visible_Count (Unicode_Model) = 1,
            "filter matches UTF-8 Latin-1 item names case-insensitively");
         Assert
           (Files.Model.Selected_Name (Unicode_Model) = Upper_Name,
            "UTF-8 Latin-1 filter selects the matching visible item");
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single visible item movement is ignored");
      Assert (Files.Model.Selected_Index (Model) = 1, "single visible item movement keeps selection");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Visible_Selection (Model, 3);
      Assert (Files.Model.Selected_Count (Model) = 3, "filter reconciliation starts from multi-selection");
      Files.Model.Set_Filter (Model, "beta");
      Assert (Files.Model.Visible_Count (Model) = 1, "multi-selection filter leaves one visible item");
      Assert
        (Files.Model.Selected_Count (Model) = 1,
         "filter reconciliation drops invisible multi-selected items");
      Assert
        (Files.Model.Selected_Name (Model) = "Beta.txt",
         "filter reconciliation keeps visible multi-selected item primary");
      Files.Model.Set_Filter (Model, "zzz");
      Assert (Files.Model.Visible_Count (Model) = 0, "unmatched filter hides all items");
      Assert (Files.Model.Selected_Count (Model) = 0, "selection becomes empty when no items are visible");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Assert (Files.Model.Selected_Count (Model) = 0, "moving selection with no visible items stays empty");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty visible selection movement is ignored");
   end Test_Filtering_Reconciles_Selection;

   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Items : constant Files.File_System.Item_Vectors.Vector := Sample_Items;
   begin
      Files.Model.Go_Back (Model);
      Assert (Files.Model.Current_Path (Model) = Root, "empty back history leaves path unchanged");
      Files.Model.Go_Forward (Model);
      Assert (Files.Model.Current_Path (Model) = Root, "empty forward history leaves path unchanged");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Selected_Count (Model) = 2, "history test starts with multi-selection");
      Files.Model.Navigate_To (Model, Root, Items);
      Assert (not Files.Model.Can_Go_Back (Model), "same-path navigation does not push history");
      Assert (Files.Model.Selected_Count (Model) = 0, "same-path navigation clears multi-selection state");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/second", Items);
      Assert (Files.Model.Selected_Count (Model) = 0, "navigation clears multi-selection state");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/third", Items);
      Assert (Files.Model.Selected_Count (Model) = 0, "second navigation clears multi-selection state");
      Assert (Files.Model.Can_Go_Back (Model), "back is enabled after navigation");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Path_Input_Text (Model, "/tmp/bad-history-path");
      Files.Model.Go_Back (Model);
      Assert (Files.Model.Current_Path (Model) = "/tmp/files_aunit/second", "back restores previous path");
      Assert (Files.Model.Selected_Count (Model) = 0, "back clears multi-selection state");
      Assert (Files.Model.Path_Input_Text (Model) = "/tmp/files_aunit/second", "back restores path input text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "back clears path validation state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "back closes command palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "back clears focus");
      Assert (Files.Model.Can_Go_Forward (Model), "forward is enabled after back");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/branch", Items);
      Assert (not Files.Model.Can_Go_Forward (Model), "new navigation after back clears forward history");
      Files.Model.Go_Back (Model);
      Assert (Files.Model.Current_Path (Model) = "/tmp/files_aunit/second", "back reaches branch origin");
      Files.Model.Begin_Create_File (Model, "forward-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Go_Forward (Model);
      Assert (Files.Model.Current_Path (Model) = "/tmp/files_aunit/branch", "forward reaches branch path");
      Assert (Files.Model.Selected_Count (Model) = 0, "forward clears multi-selection state");
      Assert (Files.Model.Path_Input_Text (Model) = "/tmp/files_aunit/branch", "forward restores path input text");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "forward closes command palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "forward clears focus");
      Files.Model.Go_Forward (Model);
      Assert (Files.Model.Current_Path (Model) = "/tmp/files_aunit/branch", "forward is exhausted after branch path");
      Files.Model.Go_Home (Model);
      Assert (Files.Model.Current_Path (Model) = "/home/test", "home navigates to model home path");
   end Test_Path_History;

   procedure Test_Path_Input_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model   : Files.Model.Window_Model := Sample_Model;
      Empty   : Files.File_System.Item_Vectors.Vector;
      Invalid : constant Files.File_System.Path_Result :=
        (Status         => Files.File_System.Path_Missing,
         Directory_Path => Null_Unbounded_String,
         Error_Key      => To_Unbounded_String ("error.path.missing"));
      Valid   : constant Files.File_System.Path_Result :=
        (Status         => Files.File_System.Path_Valid,
         Directory_Path => To_Unbounded_String ("/tmp/files_aunit/valid"),
         Error_Key      => Null_Unbounded_String);
   begin
      Files.Model.Focus_Path_Input (Model);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "path input receives focus directly");
      Assert (Files.Model.Path_Input_Text (Model) = Root, "path input focus restores current path text");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Assert (not Files.Model.Path_Input_Is_Valid (Model), "invalid input sets validation state");
      Assert (Files.Model.Path_Input_Error_Key (Model) = "error.path.missing", "invalid input records error key");
      Assert (Files.Model.Current_Path (Model) = Root, "invalid input does not change current path");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "invalid path input keeps focus");
      Files.Model.Focus_Filter_Input (Model);
      Files.Model.Focus_Path_Input (Model);
      Assert (Files.Model.Path_Input_Text (Model) = Root, "refocus restores current path after invalid input");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "refocus clears stale path validation state");
      Assert (Files.Model.Path_Input_Error_Key (Model) = "", "refocus clears stale path validation error");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Assert (Files.Model.Path_Input_Text (Model) = Root, "escape restores current path text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "escape clears path validation state");
      Assert (Files.Model.Path_Input_Error_Key (Model) = "", "escape clears path validation error");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "escape clears path input focus");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Focus_Path_Input (Model);
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "path input focus closes command palette");
      Files.Model.Set_Path_Input_Text (Model, "/tmp/files_aunit/valid");
      Files.Model.Commit_Path_Input (Model, Valid, Empty);
      Assert (Files.Model.Path_Input_Is_Valid (Model), "valid input clears validation state");
      Assert (Files.Model.Path_Input_Error_Key (Model) = "", "valid input clears validation error key");
      Assert (Files.Model.Current_Path (Model) = "/tmp/files_aunit/valid", "valid input changes path");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "valid path input clears focus");
   end Test_Path_Input_Validation;

   procedure Test_Runtime_Sort_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Controller.Controller_Result;

      function Item
        (Name     : String;
         Filetype : String;
         Size     : Long_Long_Integer;
         Created  : Ada.Calendar.Time;
         Changed  : Ada.Calendar.Time)
         return Files.File_System.Directory_Item
      is
         Value : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item (Root, Name, Files.Types.Regular_File_Item, Filetype);
      begin
         Value.Size_Available := True;
         Value.Size := Size;
         Value.Creation_Available := True;
         Value.Creation_Time := Created;
         Value.Modified_Available := True;
         Value.Modified_Time := Changed;
         return Value;
      end Item;

      function Snapshot_Name (Index : Positive) return String is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         return To_String (Snapshot.Items.Element (Index).Name);
      end Snapshot_Name;
   begin
      Items.Append
        (Item
           ("bravo.txt",
            "text/plain",
            20,
            Ada.Calendar.Time_Of (2024, 1, 2),
            Ada.Calendar.Time_Of (2024, 1, 5)));
      Items.Append
        (Item
           ("alpha.md",
            "text/markdown",
            30,
            Ada.Calendar.Time_Of (2024, 1, 3),
            Ada.Calendar.Time_Of (2024, 1, 4)));
      Items.Append
        (Item
           ("charlie.bin",
            "application/octet-stream",
            10,
            Ada.Calendar.Time_Of (2024, 1, 1),
            Ada.Calendar.Time_Of (2024, 1, 6)));
      Items.Append
        (Files.File_System.Make_Item
           (Root,
            "zulu",
            Files.Types.Directory_Item,
            "inode/directory"));
      Files.Model.Initialize (Model, Root, Items, Root);

      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Name, "default runtime sort field is name");
      Assert (Files.Model.Sort_Is_Ascending (Model), "default runtime sort direction is ascending");
      Assert (Snapshot_Name (1) = "alpha.md", "default snapshot sorts by name ascending");
      Assert (Snapshot_Name (4) = "zulu", "default snapshot does not group directories before files");

      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Toggle_Sort_Menu_Command, "sort menu command is routed");
      Assert (Files.Model.Sort_Menu_Is_Open (Model), "sort menu opens");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Sort_By_Size_Command, "sort-by-size command is routed");
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Size, "sort-by-size selects size field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "new sort field starts ascending");
      Assert (not Files.Model.Sort_Menu_Is_Open (Model), "selecting a sort field closes the menu");
      Assert (Snapshot_Name (1) = "charlie.bin", "size ascending sorts smallest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Assert (not Files.Model.Sort_Is_Ascending (Model), "selecting same sort field toggles descending");
      Assert (Snapshot_Name (1) = "alpha.md", "size descending sorts largest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Type_Command, Model, Settings);
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Type, "sort-by-type selects type field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "different sort field resets to ascending");
      Assert (Snapshot_Name (1) = "charlie.bin", "type ascending sorts by filetype token");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Created_Command, Model, Settings);
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Created, "sort-by-created selects creation field");
      Assert (Snapshot_Name (1) = "charlie.bin", "created ascending sorts oldest creation time first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Changed_Command, Model, Settings);
      Assert (Files.Model.Sort_Field_Of (Model) = Files.Model.Sort_Changed, "sort-by-changed selects modified field");
      Assert (Snapshot_Name (1) = "alpha.md", "changed ascending sorts oldest modified time first");
   end Test_Runtime_Sort_State;

   procedure Test_Root_Selector_And_Root_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Roots_B  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Root_Status : Files.File_System.Root_Discovery_Diagnostics;
      Volume_Caps : constant Files.File_System.Root_Volume_Capabilities :=
        Files.File_System.Root_Volume_Capabilities_Of_Current_Environment;
      Edge_Profile : constant Files.File_System.Filesystem_Edge_Case_Profile :=
        Files.File_System.Filesystem_Edge_Case_Profile_Of_Current_Environment;
      Linux_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Linux);
      Current_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.Platform.Current_API_Profile;
      Windows_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Windows);
      Macos_Profile : constant Files.File_System.Native_Platform_API_Profile :=
        Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Macos);
      Had_Home       : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_User_Profile : constant Boolean := Ada.Environment_Variables.Exists ("USERPROFILE");
      Had_Home_Drive : constant Boolean := Ada.Environment_Variables.Exists ("HOMEDRIVE");
      Had_Home_Path  : constant Boolean := Ada.Environment_Variables.Exists ("HOMEPATH");
      Old_Home       : Unbounded_String;
      Old_User_Profile : Unbounded_String;
      Old_Home_Drive : Unbounded_String;
      Old_Home_Path  : Unbounded_String;

      function Repository_File_Contains
        (Path    : String;
         Pattern : String)
         return Boolean is
      begin
         return
           (Project_Tools.Files.File_Exists (Path)
            and then Project_Tools.Files.File_Contains (Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../" & Path)
            and then Project_Tools.Files.File_Contains ("../" & Path, Pattern))
           or else
           (Project_Tools.Files.File_Exists ("../../" & Path)
           and then Project_Tools.Files.File_Contains ("../../" & Path, Pattern));
      end Repository_File_Contains;

      function Starts_With
        (Text   : String;
         Prefix : String)
         return Boolean is
      begin
         return Text'Length >= Prefix'Length
           and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Is_User_Visible_Mount_Point (Path : String) return Boolean is
      begin
         return Path = "/"
           or else Path = "/mnt"
           or else Starts_With (Path, "/mnt/")
           or else Path = "/media"
           or else Starts_With (Path, "/media/")
           or else Path = "/run/media"
           or else Starts_With (Path, "/run/media/")
           or else Path = "/Volumes"
           or else Starts_With (Path, "/Volumes/")
           or else Path = "/System/Volumes"
           or else Starts_With (Path, "/System/Volumes/");
      end Is_User_Visible_Mount_Point;

      procedure Restore_Root_Environment is
      begin
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;

         if Had_User_Profile then
            Ada.Environment_Variables.Set ("USERPROFILE", To_String (Old_User_Profile));
         else
            Ada.Environment_Variables.Clear ("USERPROFILE");
         end if;

         if Had_Home_Drive then
            Ada.Environment_Variables.Set ("HOMEDRIVE", To_String (Old_Home_Drive));
         else
            Ada.Environment_Variables.Clear ("HOMEDRIVE");
         end if;

         if Had_Home_Path then
            Ada.Environment_Variables.Set ("HOMEPATH", To_String (Old_Home_Path));
         else
            Ada.Environment_Variables.Clear ("HOMEPATH");
         end if;
      end Restore_Root_Environment;

   begin
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_User_Profile then
         Old_User_Profile := To_Unbounded_String (Ada.Environment_Variables.Value ("USERPROFILE"));
      end if;
      if Had_Home_Drive then
         Old_Home_Drive := To_Unbounded_String (Ada.Environment_Variables.Value ("HOMEDRIVE"));
      end if;
      if Had_Home_Path then
         Old_Home_Path := To_Unbounded_String (Ada.Environment_Variables.Value ("HOMEPATH"));
      end if;

      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Files.Model.Set_Error (Model, "error.path.missing");
      Roots_A := Files.File_System.Available_Roots;
      Roots_B := Files.File_System.Available_Roots;
      Entries := Files.File_System.Available_Root_Entries;
      Root_Status := Files.File_System.Root_Discovery_Status;
      Assert (not Roots_A.Is_Empty, "available roots is never empty");
      Assert (Natural (Entries.Length) = Natural (Roots_A.Length), "root metadata count matches root paths");
      Assert (Root_Status.Root_Count = Natural (Entries.Length), "root diagnostics count discovered roots");
      Assert (Root_Status.Ready_Count = Natural (Entries.Length), "root diagnostics count ready roots");
      Assert (Root_Status.Duplicate_Paths_Removed, "root diagnostics expose duplicate-removal policy");
      Assert (Root_Status.Deterministic_Order, "root diagnostics expose deterministic ordering policy");
      Assert
        (not Volume_Caps.Labels_From_Platform_Api,
         "root volume capabilities do not claim platform labels yet");
      Assert (Volume_Caps.Readiness_From_Platform_Api, "root volume capabilities expose readiness checks");
      Assert
        (Volume_Caps.Capacity_From_Platform_Api = Volume_Caps.Capacity_Bytes_Known,
         "root volume capacity capability matches capacity-byte availability");
      Assert
        (Volume_Caps.Native_Binding_Status = Files.File_System.Native_API_Binding_Available,
         "current target exposes native volume binding status");
      Assert
        (To_String (Volume_Caps.Binding_Unit) = "Files.File_System",
         "root volume capabilities expose binding unit");
      Assert
        (Edge_Profile.Permission_Errors_Recoverable,
         "filesystem edge-case profile records recoverable permission errors");
      Assert (Edge_Profile.Symlink_Items_Represented, "filesystem edge-case profile records symlink items");
      Assert
        (Edge_Profile.Special_File_Items_Represented,
         "filesystem edge-case profile records special file items");
      Assert
        (Edge_Profile.Cross_Device_Rename_Recoverable,
         "filesystem edge-case profile records recoverable cross-device rename failures");
      Assert (Edge_Profile.Trash_Preflight, "filesystem edge-case profile records trash preflight");
      Assert
        (Edge_Profile.Metadata_Partial_Items,
         "filesystem edge-case profile records partial metadata items");
      Assert
        (Edge_Profile.Removable_Root_Metadata,
         "filesystem edge-case profile records removable root metadata");
      Assert
        (Edge_Profile.Native_Root_Volume_Details,
         "filesystem edge-case profile records native root volume details");
      Assert
        (Linux_Profile.Adapter = Files.File_System.Native_Adapter_Linux,
         "Linux native profile identifies adapter");
      Assert (Linux_Profile.Current_Target, "Linux native profile marks current target");
      Assert
        (Linux_Profile.Volume_Binding_Status = Volume_Caps.Native_Binding_Status,
         "Linux native profile follows volume capability binding status");
      Assert
        (To_String (Linux_Profile.Volume_Binding_Unit) = "Files.File_System.Root_Volume_Details_For",
         "Linux native profile records volume binding unit");
      Assert
        (Current_Profile.Adapter = Linux_Profile.Adapter,
         "platform current API profile follows the host adapter");
      Assert
        (Current_Profile.Volume_Binding_Status = Linux_Profile.Volume_Binding_Status,
         "platform current API profile follows host volume status");
      Assert
        (To_String (Current_Profile.Volume_Binding_Unit) = To_String (Linux_Profile.Volume_Binding_Unit),
         "platform current API profile exposes host binding unit");
      Assert
        (Windows_Profile.Trash_Binding_Status = Files.File_System.Native_API_Not_Target,
         "Windows native profile is not active on this target");
      Assert
        (To_String (Windows_Profile.Trash_Binding_Unit) = "Files.Platform.Windows.Trash",
         "Windows native profile records trash binding unit");
      Assert
        (To_String (Windows_Profile.Volume_API_Name) = "GetVolumeInformationW+GetDiskFreeSpaceExW",
         "Windows native profile records volume APIs");
      Assert
        (Macos_Profile.Volume_Binding_Status = Files.File_System.Native_API_Not_Target,
         "macOS native profile is not active on this target");
      Assert
        (To_String (Macos_Profile.Required_Framework) = "Foundation",
         "macOS native profile records required framework");
      Assert
        (Repository_File_Contains ("files.gpr", "src/platform/windows"),
         "project file selects Windows platform bodies for Windows targets");
      Assert
        (Repository_File_Contains ("files.gpr", "src/platform/macos"),
         "project file selects macOS platform bodies for macOS targets");
      Assert
        (Repository_File_Contains
           ("src/platform/windows/files-platform-windows-trash.adb",
            "External_Name => ""SHFileOperationW"""),
         "Windows trash binding body imports the native recycle-bin API");
      Assert
        (Repository_File_Contains
           ("src/platform/windows/files-platform-windows-trash.adb",
            "UTF_Encoding.Wide_Strings"),
         "Windows trash binding builds a UTF-16 (Wide_String) path, not 32-bit");
      Assert
        (Repository_File_Contains
           ("src/platform/windows/files-platform-windows-volumes.adb",
            "External_Name => ""GetVolumeInformationW"""),
         "Windows volume binding body imports volume-label API");
      Assert
        (Repository_File_Contains
           ("src/platform/windows/files-platform-windows-volumes.adb",
            "External_Name => ""GetDiskFreeSpaceExW"""),
         "Windows volume binding body imports volume-capacity API");
      Assert
        (Repository_File_Contains
           ("src/platform/macos/files-platform-macos-trash.adb",
            "External_Name => ""FSMoveObjectToTrashSync"""),
         "macOS trash binding body imports native trash API");
      Assert
        (Repository_File_Contains
           ("src/platform/macos/files-platform-macos-volumes.adb",
            "External_Name => ""statfs"""),
         "macOS volume binding body imports statfs");
      Assert
        (To_String (Volume_Caps.Native_Api_Name) = "none"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "sysfs",
         "root volume capabilities name adapter");
      Assert
        (Volume_Caps.Source_Device_Available = Volume_Caps.Filesystem_Type_Available,
         "root volume source-device availability follows mount metadata availability");
      Assert
        (Volume_Caps.Mount_Options_Available = Volume_Caps.Filesystem_Type_Available,
         "root volume mount-options availability follows mount metadata availability");
      Assert
        (Volume_Caps.Network_Metadata_Available = Volume_Caps.Filesystem_Type_Available,
         "root volume network metadata availability follows mount metadata availability");
      Assert
        (Volume_Caps.Free_Bytes_Known = Volume_Caps.Capacity_Bytes_Known,
         "root volume free-byte availability follows capacity availability");
      Assert
        (Volume_Caps.Inode_Count_Known = Volume_Caps.Capacity_Bytes_Known,
         "root volume inode availability follows statvfs availability");
      Assert
        (Volume_Caps.Read_Only_Available = Volume_Caps.Capacity_Bytes_Known,
         "root volume read-only availability follows statvfs availability");
      Assert
        (Volume_Caps.Name_Max_Available = Volume_Caps.Capacity_Bytes_Known,
         "root volume name-limit availability follows statvfs availability");
      Assert (not Volume_Caps.Eject_Available, "root volume capabilities do not claim eject support");
      Assert
        (Repository_File_Contains ("src/files-file_system.adb", "function Is_Mount_Container")
         and then Repository_File_Contains ("src/files-file_system.adb", "return not Is_Mount_Container"),
         "root discovery excludes mount container rows");
      Assert (Natural (Roots_A.Length) = Natural (Roots_B.Length), "available roots count is deterministic");
      for Index in 1 .. Natural (Roots_A.Length) loop
         declare
            Detail : constant Files.File_System.Root_Volume_Details :=
              Files.File_System.Root_Volume_Details_For (Entries.Element (Index));
         begin
            Assert
              (To_String (Detail.Path) = To_String (Entries.Element (Index).Path),
               "root volume details preserve root path");
            Assert
              (To_String (Detail.Native_Api_Name) = "none"
               or else To_String (Detail.Native_Api_Name) = "proc.mounts"
               or else To_String (Detail.Native_Api_Name) = "proc.mounts+sysfs"
               or else To_String (Detail.Native_Api_Name) = "statvfs"
               or else To_String (Detail.Native_Api_Name) = "statvfs+proc.mounts"
               or else To_String (Detail.Native_Api_Name) = "statvfs+proc.mounts+sysfs"
               or else To_String (Detail.Native_Api_Name) = "sysfs",
               "root volume details name adapter");
            if To_String (Detail.Filesystem_Type) /= "" then
               Assert (To_String (Detail.Source_Device) /= "", "root volume details include mount source");
               Assert (To_String (Detail.Mount_Options) /= "", "root volume details include mount options");
            end if;
            Assert (Detail.Capacity_Known = Detail.Free_Known, "root volume size flags are consistent");
            if Detail.Capacity_Known then
               Assert (Detail.Capacity_Bytes > 0, "known root volume capacity is positive");
               Assert (Detail.Free_Bytes >= 0, "known root volume free space is non-negative");
               Assert (Detail.Free_Bytes <= Detail.Capacity_Bytes, "known root volume free space fits capacity");
               Assert (Detail.Read_Only_Known, "known root volume capacity includes read-only metadata");
               Assert (Detail.Name_Max_Known, "known root volume capacity includes filename limit metadata");
               Assert (Detail.Name_Max > 0, "known root volume filename limit is positive");
            end if;
            if Detail.Inode_Count_Known then
               Assert (Detail.Inode_Count > 0, "known root volume inode count is positive");
               Assert (Detail.Free_Inode_Known, "known root volume inode count includes free inode count");
               Assert
                 (Detail.Free_Inode_Count <= Detail.Inode_Count,
                  "known root volume free inode count fits inode count");
            end if;
            Assert
              (Detail.Uses_Platform_Detail =
               (Detail.Capacity_Known
                or else Detail.Inode_Count_Known
                or else Detail.Read_Only_Known
                or else Detail.Name_Max_Known
                or else Detail.Removable_Known
                or else To_String (Detail.Filesystem_Type) /= ""),
               "root volume details platform flag follows filesystem type availability");
         end;
         Assert (To_String (Roots_A.Element (Index)) /= "", "available root path is non-empty");
         Assert
           (To_String (Entries.Element (Index).Path) = To_String (Roots_A.Element (Index)),
            "root metadata path matches path projection");
         Assert (To_String (Entries.Element (Index).Label) /= "", "root metadata label is non-empty");
         Assert (To_String (Entries.Element (Index).Volume_Name) /= "", "root metadata volume name is non-empty");
         Assert (Entries.Element (Index).Ready = Files.File_System.Root_Ready, "root metadata marks roots ready");
         case Entries.Element (Index).Kind is
            when Files.File_System.Root_Filesystem
               | Files.File_System.Root_Home
               | Files.File_System.Root_Current
               | Files.File_System.Root_Mount
               | Files.File_System.Root_User_Mount
               | Files.File_System.Root_Network_Mount
               | Files.File_System.Root_Windows_Drive
               | Files.File_System.Root_Favorite =>
               null;
         end case;
         if Entries.Element (Index).Kind = Files.File_System.Root_Mount then
            Assert
              (Is_User_Visible_Mount_Point (To_String (Entries.Element (Index).Path)),
               "root selector excludes system implementation mounts");
            Assert
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|tmpfs") = 0,
               "root selector excludes tmpfs mounts from proc metadata");
            Assert
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|proc") = 0,
               "root selector excludes proc mounts from proc metadata");
            Assert
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|sysfs") = 0,
               "root selector excludes sysfs mounts from proc metadata");
            Assert
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|squashfs") = 0,
               "root selector excludes snap package mounts from proc metadata");
         end if;
         Assert (Ada.Directories.Exists (To_String (Roots_A.Element (Index))), "available root path exists");
         Assert
           (Ada.Directories.Kind (To_String (Roots_A.Element (Index))) = Ada.Directories.Directory,
            "available root path is a directory");
         Assert
           (To_String (Roots_A.Element (Index)) = To_String (Roots_B.Element (Index)),
            "available roots preserve deterministic order");
         for Other in Index + 1 .. Natural (Roots_A.Length) loop
            Assert
              (To_String (Roots_A.Element (Index)) /= To_String (Roots_A.Element (Other)),
               "available roots do not contain duplicates");
         end loop;
      end loop;
      declare
         Drive_Profile_Path : constant String := Join (Root, "drive-profile-root");
         Found_Drive_Profile : Boolean := False;
      begin
         Ada.Directories.Create_Path (Drive_Profile_Path);
         Ada.Environment_Variables.Set ("HOMEDRIVE", Root);
         Ada.Environment_Variables.Set ("HOMEPATH", "/drive-profile-root");
         Entries := Files.File_System.Available_Root_Entries;
         for Root_Entry_Value of Entries loop
            if To_String (Root_Entry_Value.Path) = Ada.Directories.Full_Name (Drive_Profile_Path)
              and then Root_Entry_Value.Kind = Files.File_System.Root_User_Mount
            then
               Found_Drive_Profile := True;
            end if;
         end loop;
         Assert
           (Found_Drive_Profile,
            "available roots include HOMEDRIVE and HOMEPATH profile directory");
         Restore_Root_Environment;
      exception
         when others =>
         Restore_Root_Environment;
         raise;
      end;
      declare
         Shared_Profile_Path : constant String := Join (Root, "shared-profile-root");
         Shared_Profile_Full : Unbounded_String;
         Shared_Profile_Count : Natural := 0;
      begin
         Ada.Directories.Create_Path (Shared_Profile_Path);
         Shared_Profile_Full := To_Unbounded_String (Ada.Directories.Full_Name (Shared_Profile_Path));
         Ada.Environment_Variables.Set ("HOME", Shared_Profile_Path);
         Ada.Environment_Variables.Set ("USERPROFILE", To_String (Shared_Profile_Full));
         Entries := Files.File_System.Available_Root_Entries;
         for Root_Entry_Value of Entries loop
            if To_String (Root_Entry_Value.Path) = To_String (Shared_Profile_Full) then
               Shared_Profile_Count := Shared_Profile_Count + 1;
            end if;
         end loop;
         Assert
           (Shared_Profile_Count = 1,
            "available roots collapse duplicate HOME and USERPROFILE directories");
         Restore_Root_Environment;
      exception
         when others =>
            Restore_Root_Environment;
            raise;
      end;
      declare
         Bad_Root : constant Files.File_System.Root_Entry :=
           (Path        => To_Unbounded_String (Root & "/bad" & Character'Val (0) & "root"),
            Label       => To_Unbounded_String ("bad"),
            Kind        => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("bad"),
            Ready       => Files.File_System.Root_Inaccessible,
            Removable   => False);
         Bad_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Bad_Root);
      begin
         Assert
           (To_String (Bad_Detail.Native_Api_Name) = "none",
            "malformed root volume detail skips platform adapter");
         Assert
           (not Bad_Detail.Uses_Platform_Detail,
            "malformed root volume detail has no platform metadata");
      end;

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "drive selector command is routed");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector opens root selector");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "root selector opening closes settings pane");
      Assert (Files.Model.Root_Count (Model) >= 1, "root selector contains at least one root");
      Assert (Files.Model.Root_Selected_Index (Model) = 1, "root selector selects the first root by default");
      Assert (Files.Model.Root_Path (Model, 1) /= "", "root selector exposes a root path");
      Assert (Files.Model.Root_Path (Model, 99) = "", "invalid root selector index returns empty path");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Root_Selector_Open, "snapshot captures root selector visibility");
      Assert (not Snapshot.Settings_Pane_Open, "snapshot exposes root selector as exclusive settings modal");
      Assert (Snapshot.Root_Selected_Index = 1, "snapshot captures selected root selector row");
      Assert
        (Natural (Snapshot.Root_Paths.Length) = Files.Model.Root_Count (Model),
         "snapshot captures root selector paths");
      Assert
        (Natural (Snapshot.Root_Labels.Length) = Files.Model.Root_Count (Model),
         "snapshot captures root selector labels");
      Assert (To_String (Snapshot.Root_Labels.Element (1)) /= "", "root selector label is non-empty");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.mount.prefix") & "example-mount" &
         Files.Localization.Text ("root.mount.suffix"),
         "root selector renders localized root kind prefix");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount|ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.mount.prefix") & "example-mount" &
         Files.Localization.Text ("root.detail.prefix") & "ext4" &
         Files.Localization.Text ("root.detail.suffix") &
         Files.Localization.Text ("root.mount.suffix"),
         "root selector renders localized platform detail suffix");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/run/user/1000/gvfs/smb-share:server=nas,share=docs"),
            Label => To_Unbounded_String ("root.network_mount|nas-docs|cifs"),
            Kind  => Files.File_System.Root_Network_Mount,
            Volume_Name => To_Unbounded_String ("nas-docs"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      declare
         Network_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Entries.Element (1));
      begin
         Assert (Network_Detail.Network_Mount, "network root detail marks remote mounts");
         Assert
           (To_String (Network_Detail.Remote_Protocol) = "smb",
            "network root detail derives SMB protocol from GVFS path");
         Assert (Network_Detail.Offline_Possible, "network root detail marks offline risk");
         Assert (Network_Detail.Auth_May_Be_Required, "network root detail marks authentication risk");
         Assert (Network_Detail.Latency_Sensitive, "network root detail marks latency risk");
         Assert
           (Network_Detail.Special_Error_Recovery,
            "network root detail marks special recovery policy");
      end;
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.network_mount.prefix") & "nas-docs" &
         Files.Localization.Text ("root.detail.prefix") & "cifs" &
         Files.Localization.Text ("root.detail.suffix") &
         Files.Localization.Text ("root.network_mount.suffix"),
         "root selector renders localized network root labels");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path        => To_Unbounded_String ("/tmp/local-root"),
            Label       => To_Unbounded_String ("root.mount|local-root|ext4"),
            Kind        => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("local-root"),
            Ready       => Files.File_System.Root_Ready,
            Removable   => False));
      declare
         Local_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Entries.Element (1));
      begin
         Assert (not Local_Detail.Network_Mount, "local root detail does not claim network status");
         Assert
           (To_String (Local_Detail.Remote_Protocol) = "",
            "local root detail has no remote protocol");
         Assert (not Local_Detail.Offline_Possible, "local root detail has no offline network risk");
         Assert
           (not Local_Detail.Auth_May_Be_Required,
            "local root detail has no network authentication risk");
         Assert (not Local_Detail.Latency_Sensitive, "local root detail has no network latency risk");
         Assert
           (not Local_Detail.Special_Error_Recovery,
            "local root detail has no network recovery policy");
      end;
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount|ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Eject_Selected_Root_Command, Model),
         "eject command is enabled for removable roots");
      Result := Files.Controller.Execute_Command (Files.Commands.Eject_Selected_Root_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Eject_Selected_Root_Command, "eject command reports command");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Failed,
         "eject command reports unavailable native operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.root.eject_unavailable",
         "eject command reports localized unavailable error");
      Assert
        (To_String (Result.Operation.Path) = "/tmp/example-mount",
         "eject command reports selected root path");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String (Target),
            Label => To_Unbounded_String ("root.mount|selected-root"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("selected-root"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Eject_Selected_Root_Command, Model),
         "eject command is disabled for non-removable roots");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Selected_Root_Command, Model, Settings);
      Assert
        (Result.Command = Files.Commands.Open_Selected_Root_Command,
         "root-open command reports root activation command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "root-open command navigates");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target), "root-open loads selected root");
      Files.Model.Navigate_To (Model, Root, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens before direct root selector call");
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "direct root selector call opens root selector");
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "metadata root selector overload closes settings pane");
      Files.Model.Toggle_Settings_Pane (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane reopens before string root selector call");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "string root selector overload opens root selector");
      Assert
        (not Files.Model.Settings_Pane_Is_Open (Model),
         "string root selector overload closes settings pane");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "second drive selector click is routed");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "second drive selector click closes root selector");
      Assert (Files.Model.Current_Path (Model) = Root, "second drive selector click does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after toggle close");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "Escape routes root selector close");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "root selector Escape reports successful state-only close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "Escape closes root selector");
      Assert (Files.Model.Root_Count (Model) = 0, "Escape clears closed root selector entries");
      Assert (Files.Model.Current_Path (Model) = Root, "root selector Escape does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Close_Command_Palette_Command, Model, Settings);
      Assert
        (Result.Command = Files.Commands.Close_Command_Palette_Command,
         "close command routes root selector close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "close command closes root selector");
      Assert (Files.Model.Root_Count (Model) = 0, "close command clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after close command");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks path focus command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked path focus keeps root selector open");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "blocked path focus leaves focus clear");
      Files.Model.Close_Root_Selector (Model);
      Assert (Files.Model.Root_Count (Model) = 0, "direct close clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after blocked path focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "palette command is routed");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens from toolbar state");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette opening preserves root selector");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "same palette search cursor click is ignored");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette search focus preserves root selector");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "Escape closes palette after selector handoff");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "Escape leaves root selector open after palette closes");
      Files.Model.Close_Root_Selector (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files.Controller.Replace_Focused_Text (Model, "view.details");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector opens from palette state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "drive selector closes command palette");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "drive selector clears palette focus");
      Files.Model.Close_Root_Selector (Model);

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after palette Escape");
      Files.Model.Begin_Create_File (Model, "root-pending.txt");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);

      Result := Files.Controller.Select_Root (Model, Settings, Join (Root, "missing-root"));
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "invalid root selection executes command");
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "invalid root selection reports drive command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Failed, "invalid root selection fails as data");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.path.missing",
         "invalid root selection reports path diagnostic");
      Assert (Files.Model.Current_Path (Model) = Root, "invalid root selection does not navigate");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "invalid root selection keeps selector open");
      Assert (Files.Model.Last_Error_Key (Model) = "error.path.missing", "invalid root selection records error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid root selection preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid root selection preserves rename state");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 0);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "outside root row click is ignored");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "outside root row click keeps selector open");

      Result := Files.Controller.Select_Root (Model, Settings, Target);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "root selection executes command");
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "root selection reports drive command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "root selection navigates");
      Assert
        (To_String (Result.Operation.Path) = Ada.Directories.Full_Name (Target),
         "root selection operation carries normalized path");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target), "selected root is loaded");
      Assert (Files.Model.Last_Error_Key (Model) = "", "root selection clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "root selection clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "root selection clears rename state");
      Assert (Files.Model.Item_Count (Model) = 1, "selected root directory items are loaded");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "root selection closes selector");
      Assert (Files.Model.Can_Go_Back (Model), "root selection updates back history");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "closed root selector row click is ignored");
      Assert
        (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target),
         "closed root selector row click does not navigate");

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.Types.String_Vectors.Empty_Vector);
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "empty root selector stays closed");
      Assert (Files.Model.Root_Selected_Index (Model) = 0, "empty root selector has no selected row");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "empty root selector does not create an invisible modal command blocker");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single root selector movement is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector Home at first row is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "single root selector End is ignored");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Assert (Files.Model.Root_Selected_Index (Model) = 1, "non-empty root selector selects first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "Down moves root selector row");
      Assert (Files.Model.Root_Selected_Index (Model) = 2, "Down selects next root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Assert (Files.Model.Root_Selected_Index (Model) = 1, "Up selects previous root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Assert (Files.Model.Root_Selected_Index (Model) = 3, "Up wraps root selector to last row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Assert (Files.Model.Root_Selected_Index (Model) = 1, "Home selects first root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Assert (Files.Model.Root_Selected_Index (Model) = 3, "End selects last root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "Right wraps root selector to first row");
      Assert (Files.Model.Root_Selected_Index (Model) = 1, "Right from last root row wraps to first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "Left wraps root selector to last row");
      Assert (Files.Model.Root_Selected_Index (Model) = 3, "Left from first root row wraps to last row");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks background delete key");
      Assert (Files.Model.Selected_Count (Model) = 1, "blocked root selector delete keeps selection");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked root selector delete keeps selector open");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks background text focus");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "blocked text focus leaves focus clear");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks background wheel scroll");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "blocked root selector scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Auto,
           Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks targeted auto scroll");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "blocked root auto scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Main_View,
           Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks targeted main scroll");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert (Result.Command = Files.Commands.Open_Command_Palette_Command, "root selector allows palette shortcut");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens over root selector from shortcut");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette shortcut keeps root selector available");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Assert
        (Result.Status = Files.Controller.Controller_Ignored,
         "same palette search cursor click is ignored over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks direct path focus command");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "blocked direct path focus leaves focus clear");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks direct delete command");
      Assert (Files.Model.Selected_Count (Model) = 1, "blocked direct delete keeps selection");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.path.missing",
         "modal command block does not replace existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "root selector blocks direct settings command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked direct settings keeps root selector open");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "blocked direct settings leaves settings pane closed");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.path.missing",
         "root selector settings block preserves existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Assert
        (Result.Command = Files.Commands.Open_Command_Palette_Command,
         "root selector allows direct palette command");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "direct palette command opens over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Select_Drive_Command, "root selector allows drive toggle command");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "drive toggle closes root selector");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Set_Root_Selected_Index (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (Result.Command = Files.Commands.Open_Selected_Root_Command, "Return activates selected root row");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "Return root activation navigates");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target), "Return loads selected root");

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Target));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/root-click-edit");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Assert
        (Result.Command = Files.Commands.Open_Selected_Root_Command,
         "root row click reports root activation command");
      Assert (Result.Operation.Status = Files.Operations.Operation_Navigated, "root row click navigates");
      Assert (Files.Model.Current_Path (Model) = Ada.Directories.Full_Name (Target), "root row click loads root");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "root row click clears path input focus");
      Assert
        (Files.Model.Path_Input_Text (Model) = Ada.Directories.Full_Name (Target),
         "root row click replaces edited path text");
   end Test_Root_Selector_And_Root_Selection;

   procedure Test_Info_And_Bottom_Bar_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;

      --  The info pane can always be toggled, even with nothing selected.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Assert
        (Result.Command = Files.Commands.Toggle_Info_Pane_Command,
         "Control+4 routes info-pane command with no selection");
      Assert
        (Result.Status = Files.Controller.Controller_Command_Executed,
         "Control+4 toggles the info pane with no selection");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane opens without a selection");
      --  Close it again, then reopen with a selection so the rest of the
      --  scenario starts from an open, selection-backed info pane.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second Control+4 closes the info pane");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Assert (Result.Command = Files.Commands.Toggle_Info_Pane_Command, "Control+4 routes info-pane command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane toggles open");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "info pane opens unscrolled");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "PageUp at top of info pane is ignored");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, -1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "negative info scroll at top is ignored");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "PageDown pages info pane");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 10, "PageDown scrolls info pane by page");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'Last);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "large info scroll is handled");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = Natural'Last, "large info scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'First);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "large negative info scroll is handled");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "large negative info scroll clamps to top");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 10, "info pane scroll resumes after saturation");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "PageUp pages info pane");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "PageUp scrolls info pane back to top");

      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 3, "info pane can scroll before selection changes");
      Files.Model.Select_Visible (Model, 2);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "single selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "toggle selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "range selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Clear_Selection (Model);
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "clear selection resets info pane scroll");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over info pane");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "wheel scrolls the open settings pane");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "settings wheel scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "auto scroll reaches the settings pane");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "settings auto scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, 10);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks targeted info scroll");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "blocked targeted scroll leaves info pane still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks background PageDown");
      Assert (Files.Model.Info_Pane_Scroll_Lines (Model) = 0, "blocked PageDown leaves info pane still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after scroll block checks");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_2, Ctrl);
      Assert (Result.Command = Files.Commands.Select_Large_Icons_Command, "Control+2 routes large-icons command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Large_Icons, "large mode shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_3, Ctrl);
      Assert (Result.Command = Files.Commands.Select_Details_Command, "Control+3 routes details command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "details shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_1, Ctrl);
      Assert (Result.Command = Files.Commands.Select_Small_Icons_Command, "Control+1 routes small-icons command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Small_Icons, "small mode shortcut works");

      --  The info pane can always be toggled, even with no selection: the click
      --  now closes the currently open pane rather than being ignored.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert
        (Result.Command = Files.Commands.Toggle_Info_Pane_Command,
         "info-pane click routes command with no selection");
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "info-pane click closes the pane with no selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Toggle_Info_Pane_Command, "enabled info-pane click routes command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info-pane click toggles open");
      --  Restore the closed state expected by the following main-view scroll
      --  checks.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second info-pane click closes the pane again");

      --  Over the file grid (info pane closed) plain Page Up / Page Down now
      --  page the SELECTION rather than scrolling the main view. The main view
      --  still scrolls through the wheel / targeted-scroll seam below.
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "grid PageUp on the first item is ignored");
      Assert (Files.Model.Selected_Index (Model) = 1, "grid PageUp keeps the first item selected");

      Result := Files.Controller.Handle_Scroll (Model, Lines => -1);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "negative main scroll at top is ignored");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "grid PageDown pages the selection");
      Assert
        (Files.Model.Selected_Index (Model) = Files.Model.Visible_Count (Model),
         "grid PageDown moves the selection a full page down to the last item");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "grid PageDown on the last item is ignored");
      Assert
        (Files.Model.Selected_Index (Model) = Files.Model.Visible_Count (Model),
         "grid PageDown keeps the last item selected");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Assert (Result.Status = Files.Controller.Controller_Selection_Moved, "grid PageUp pages the selection back");
      Assert (Files.Model.Selected_Index (Model) = 1, "grid PageUp returns the selection to the first item");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'Last);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "large main scroll is handled");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = Natural'Last, "large main scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'First);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "large negative main scroll is handled");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "large negative main scroll clamps to top");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over main view");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "wheel scrolls the open settings pane");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "settings wheel scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Assert (Result.Status = Files.Controller.Controller_Command_Executed, "auto scroll reaches the settings pane");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "settings auto scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, 10);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks targeted main scroll");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "blocked targeted scroll leaves main view still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "settings pane blocks main PageDown");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "blocked PageDown leaves main view still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before command click checks");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.Select_Details_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Select_Details_Command, "details click routes command");
      Assert (Files.Model.View_Mode_Of (Model) = Files.Types.Details, "details click changes view mode");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.No_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "empty command click is ignored");
      Assert (Result.Command = Files.Commands.No_Command, "empty command click reports no command");
   end Test_Info_And_Bottom_Bar_Commands;

   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
      Policy   : constant Files.Model.Rename_Policy := Files.Model.Rename_Behavior;
   begin
      Assert (not Policy.Single_Item_Only, "rename policy is no longer single-item only");
      Assert (Policy.Synchronized_Multi, "rename policy claims synchronized multi-rename");
      Assert (not Policy.Atomic_Multi_Rename, "rename policy does not claim atomic multi-rename");
      Assert (not Policy.Requires_One_Selection, "rename policy does not require exactly one selected item");
      Assert (not Files.Model.Rename_Is_Enabled (Model), "rename disabled with no selection");
      Files.Model.Select_Visible (Model, 2);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "direct rename enters rename mode");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "direct rename closes stale root selector");
      Assert (Files.Model.Root_Count (Model) = 0, "direct rename clears stale root selector entries");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "direct rename closes stale command palette");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "direct rename can be cancelled after overlay cleanup");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Resume_Rename (Model, "renamed.txt");
      Assert (Files.Model.Rename_Is_Active (Model), "resume rename enters rename mode");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "resume rename closes stale root selector");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "resume rename closes stale command palette");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "resume rename state can be cancelled");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Assert (Files.Model.Rename_Is_Enabled (Model), "rename enabled with multi-selection");
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "multi-selection rename enters rename mode");
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "multi-selection rename opens one field per item");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "toggling rename again cancels multi rename");
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (Files.Model.Rename_Is_Active (Model), "rename command enters rename mode");
      Assert (Files.Model.Rename_Text (Model) = "Beta.txt", "rename text is selected file name");
      Files.Model.Select_Visible (Model, 1);
      Assert (not Files.Model.Rename_Is_Active (Model), "selection change cancels stale rename mode");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "selection change clears stale rename focus");

      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Assert
        (Files.Model.Rename_Is_Active (Model),
         "extending the selection keeps the still-selected rename field active");

      Files.Model.Select_Visible (Model, 3);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Model.Set_Filter (Model, "Alpha");
      Assert (not Files.Model.Rename_Is_Active (Model), "filter hiding rename target cancels rename mode");
      Assert (Files.Model.Selected_Name (Model) = "Alpha.txt", "filter reconciliation selects visible item");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 while renaming cancels rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "F2 routes rename through controller");
      Assert (Files.Model.Rename_Is_Active (Model), "controller F2 enters rename mode");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "Escape routes context cancel");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "rename Escape reports successful state-only cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels focused rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered again");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "path focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "path focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "Escape clears focused path input");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels rename state after path focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered after path focus Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Filter_Input_Command, Model, Settings);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Filter_Input, "focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "moving focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "first Escape clears focused filter input");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels pending rename state after focus moved");
   end Test_Rename_Mode;

   procedure Test_Multi_Rename_Broadcast (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;

      function RValue (Visible_Index : Positive) return String is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return To_String (Value);
      end RValue;

      function RCursor (Visible_Index : Positive) return Natural is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return Cursor;
      end RCursor;

      function RActive (Visible_Index : Positive) return Boolean is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return Active;
      end RActive;

      Changed : Boolean;
   begin
      --  Select Alpha.txt (visible 1) and Beta.txt (visible 2) and enter the
      --  synchronized multi-rename.
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "multi-rename activates for two selected items");
      Assert (Files.Model.Rename_Field_Count (Model) = 2, "multi-rename opens one field per selected item");

      Assert (RActive (1) and then RActive (2), "both selected rows carry an active rename field");
      Assert (not RActive (3), "an unselected row carries no rename field");
      Assert (RValue (1) = "Alpha.txt" and then RValue (2) = "Beta.txt", "fields pre-fill each item name");
      Assert (RCursor (1) = 5 and then RCursor (2) = 4, "initial carets sit before each extension");

      --  A typed character inserts at every caret, each caret advancing.
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "X");
      Assert (Changed, "insert reports a change across the fields");
      Assert
        (RValue (1) = "AlphaX.txt" and then RValue (2) = "BetaX.txt",
         "insert broadcasts to every field's caret");
      Assert (RCursor (1) = 6 and then RCursor (2) = 5, "each caret advances past the inserted text");

      --  Backspace deletes at every caret.
      Changed := Files.Model.Rename_Delete_Backward (Model);
      Assert (Changed, "backspace reports a change across the fields");
      Assert
        (RValue (1) = "Alpha.txt" and then RValue (2) = "Beta.txt",
         "backspace broadcasts to every field's caret");
      Assert (RCursor (1) = 5 and then RCursor (2) = 4, "each caret retreats after backspace");

      --  A per-field click moves only that field's caret.
      Files.Model.Set_Rename_Caret (Model, Visible_Index => 1, Position => 0);
      Assert (RCursor (1) = 0, "a click moves the clicked field's caret");
      Assert (RCursor (2) = 4, "a click leaves the other field's caret untouched");

      --  A keyboard arrow moves every caret together.
      Changed := Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right);
      Assert (Changed, "arrow reports a change across the fields");
      Assert (RCursor (1) = 1 and then RCursor (2) = 5, "a keyboard arrow moves every caret together");
   end Test_Multi_Rename_Broadcast;

   procedure Test_Create_File_Temporary_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
      Operation : Files.Operations.Operation_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 2.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Begin_Create_File (Model, "draft.txt");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "direct create adds temporary item");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "direct create closes stale root selector");
      Assert (Files.Model.Root_Count (Model) = 0, "direct create clears stale root selector entries");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "direct create closes stale command palette");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Scroll_Main_View (Model, 4);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert (Result.Command = Files.Commands.Create_File_Command, "create command routes through controller");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "create command reports successful temporary-item operation");
      Assert (Files.Model.Last_Error_Key (Model) = "", "create command clears stale error state");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "create command adds temporary item");
      Assert (Files.Model.Temporary_Item_Name (Model) = "untitled 3.txt", "temporary item name is deterministic");
      Assert (Files.Model.Main_View_Scroll_Lines (Model) = 0, "create command scrolls temporary item into view");
      Assert (Files.Model.Rename_Is_Active (Model), "create command starts rename mode");
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input, "create command focuses rename input");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Create_File_Command, Model),
         "create command is disabled while a temporary item exists");
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert (Result.Status = Files.Controller.Controller_Ignored, "second create command is ignored");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Disabled,
         "second create command reports disabled operation");
      Assert
        (To_String (Result.Operation.Error_Key) = "error.create.pending",
         "second create command reports pending-create error");
      Assert (Files.Model.Last_Error_Key (Model) = "error.create.pending", "second create records error");
      Assert (Files.Model.Temporary_Item_Name (Model) = "untitled 3.txt", "ignored create keeps pending name");
      Files.Model.Cancel_Create_File (Model);
      Ada.Directories.Delete_File (Join (Root, "untitled 2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert (Files.Model.Temporary_Item_Name (Model) = "untitled 2.txt", "create command uses first name gap");
      Assert (Files.Model.Visible_Count (Model) = 1, "temporary item appears despite active filter");
      Assert
        (To_String (Files.Model.Visible_Item (Model, 1).Name) = "untitled 2.txt",
         "temporary item is the visible item while pending");
      Assert (Files.Model.Selected_Index (Model) = 1, "create command selects temporary item");
      Assert (Files.Model.Selected_Count (Model) = 1, "temporary item counts as a selected visible item");
      Assert (Files.Model.Selected_Name (Model) = "untitled 2.txt", "temporary selection exposes pending name");
      Assert (Files.Model.Selected_Item_Is_Temporary (Model), "model identifies selected temporary item");
      Assert (not Files.Model.Rename_Is_Enabled (Model), "temporary item is not a real rename target");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
         "active temporary rename can still be cancelled through the command");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
         "selected temporary item does not enable delete");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
         "selected temporary item does not enable open");
      Operation := Files.Operations.Open_Selected (Model, Settings);
      Assert (Operation.Status = Files.Operations.Operation_Disabled, "temporary item cannot be opened directly");
      Assert (Files.Model.Last_Error_Key (Model) = "error.selection.empty", "temporary open records disabled state");
      Operation := Files.Operations.Delete_Selected (Model, Settings);
      Assert (Operation.Status = Files.Operations.Operation_Disabled, "temporary item cannot be deleted directly");
      Assert (Files.Model.Last_Error_Key (Model) = "error.selection.empty", "temporary delete records disabled state");
      Operation := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Operation.Status = Files.Operations.Operation_Disabled, "temporary item cannot be renamed directly");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.disabled", "temporary rename records disabled state");

      declare
         Mixed_Model : Files.Model.Window_Model := Sample_Model;
         Mixed_Items : Files.File_System.Item_Vectors.Vector;
      begin
         Files.Model.Begin_Create_File (Mixed_Model, "pending.txt");
         Files.Model.Select_Visible_Range
           (Mixed_Model,
            Anchor_Index => Positive (Files.Model.Visible_Count (Mixed_Model)),
            Target_Index => 1);
         Mixed_Items := Files.Model.Selected_Items (Mixed_Model);
         Assert
           (Files.Model.Selected_Count (Mixed_Model) = 4,
            "mixed selection includes real items and temporary item");
         Assert
           (Natural (Mixed_Items.Length) = 3,
            "selected items excludes the transient create-file item");
         Assert
           (Files.Model.Selection_Includes_Temporary (Mixed_Model),
            "model identifies temporary item inside mixed selection");
         Assert
           (not Files.Model.Selected_Item_Is_Temporary (Mixed_Model),
            "primary selected item need not be temporary in a mixed selection");
         Assert
           (not Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Mixed_Model),
            "mixed temporary selection does not enable delete");
         Assert
           (not Files.Commands.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Mixed_Model),
            "mixed temporary selection does not enable open");
         Operation := Files.Operations.Open_Selected (Mixed_Model, Settings);
         Assert (Operation.Status = Files.Operations.Operation_Disabled, "mixed temporary selection cannot open");
         Assert
           (Files.Model.Last_Error_Key (Mixed_Model) = "error.selection.empty",
            "mixed temporary open records disabled state");
         Operation := Files.Operations.Delete_Selected (Mixed_Model, Settings);
         Assert (Operation.Status = Files.Operations.Operation_Disabled, "mixed temporary selection cannot delete");
         Assert
           (Files.Model.Last_Error_Key (Mixed_Model) = "error.selection.empty",
            "mixed temporary delete records disabled state");
      end;

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Result.Command = Files.Commands.Rename_Selected_Items_Command, "F2 routes temporary rename cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "F2 cancels pending temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 clears temporary rename state");
      Assert (Files.Model.Selected_Count (Model) = 0, "F2 clears temporary selection");
      Assert (Files.Model.Visible_Count (Model) = 0, "F2 removes temporary item from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 2.txt")), "F2 does not create a file");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Result.Command = Files.Commands.Create_File_Command, "Control+N routes create-file command");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N adds temporary item");
      Files.Model.Cancel_Create_File (Model);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "direct create cancel clears rename focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N can add temporary item after direct cancel");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_Path_Input, "path focus can move away from create");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Files.Model.Focus (Model) = Files.Types.Focus_None, "Escape clears path focus during create");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item after path focus");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears create rename after path focus");
      Assert (Files.Model.Visible_Count (Model) = 0, "path-focus Escape removes temporary item from projection");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Result.Command = Files.Commands.Close_Command_Palette_Command, "Escape routes context cancel");
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "create Escape reports successful state-only cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears temporary rename state");
      Assert (Files.Model.Selected_Count (Model) = 0, "Escape clears temporary selection");
      Assert (Files.Model.Visible_Count (Model) = 0, "cancelled temporary item disappears from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 3.txt")), "Escape does not create a file");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "temporary-row item click reports successful context cancel");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "temporary-row item click cancels pending create");
      Assert
        (Files.Model.Selected_Count (Model) = 0,
         "temporary-row item click does not leave a zero selection");
      Assert
        (Files.Model.Visible_Count (Model) = 0,
         "temporary-row item click removes the only visible row");

      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 3.txt"));
      Write_File (Join (Root, "name-parent.txt"));
      Assert
        (Files.File_System.Next_Untitled_Name (Join (Root, "name-parent.txt")) = "untitled.txt",
         "untitled name generation falls back deterministically for non-directory probes");
      Assert
        (Files.File_System.Next_Untitled_Name (Root) = "untitled 2.txt",
         "untitled name generation skips directory collisions");
      Files.Model.Initialize (Model, Root, Items, Root);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert (Files.Model.Temporary_Item_Name (Model) = "untitled 2.txt", "create uses first available suffix");
      Files.Model.Cancel_Create_File (Model);
      declare
         function Suffix_Text (Value : Natural) return String is
            Image : constant String := Natural'Image (Value);
         begin
            if Image'Length > 0 and then Image (Image'First) = ' ' then
               return Image (Image'First + 1 .. Image'Last);
            end if;

            return Image;
         end Suffix_Text;
      begin
         for Index in 2 .. 10 loop
            Write_File (Join (Root, "untitled " & Suffix_Text (Index) & ".txt"));
         end loop;
      end;
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Assert
        (Files.Model.Temporary_Item_Name (Model) = "untitled 11.txt",
         "create uses explicit spaced suffix text after single digits");
   end Test_Create_File_Temporary_State;

   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Operations.Operation_Result;
      Item     : Files.File_System.Directory_Item;
   begin
      Item := Files.Model.Selected_Item (Model);
      Assert (To_String (Item.Name) = "", "empty selection returns an empty selected item");
      Assert (To_String (Item.Full_Path) = "", "empty selection selected item has empty path");
      Assert (Item.Kind = Files.Types.Unknown_Item, "empty selection selected item has unknown kind");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "empty selection is not temporary");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "empty open is represented as disabled");
      Assert (To_String (Result.Path) = "", "disabled empty open has no target path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.selection.empty", "empty open records an error");
      Result := Files.Operations.Navigate_Back (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "empty back history is disabled");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.history.back_unavailable",
         "empty back history records an error");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "create commit without temporary item is disabled");
      Assert (To_String (Result.Path) = "", "disabled create commit has no target path");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.create.no_temporary_item",
         "missing temporary item records an error");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Disabled, "rename commit outside rename mode is disabled");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.disabled", "disabled rename records an error");

      Files.Model.Select_Visible (Model, 1);
      Result := Files.Operations.Delete_Selected (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "trash failure is represented as data");
      Assert (To_String (Result.Path) = Join (Root, "Alpha.txt"), "trash failure reports selected path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.trash.failed", "trash failure is recorded as data");
   end Test_Error_State;

   procedure Test_Quick_Look_Content_Prep (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;

      function Many_Lines (Count : Positive) return String is
         Buffer : Unbounded_String;
      begin
         for I in 1 .. Count loop
            Append (Buffer, "line" & ASCII.LF);
         end loop;
         return To_String (Buffer);
      end Many_Lines;
   begin
      --  A short text file yields Text content with the leading lines.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "notes.txt", Filetype => "text/plain", Icon_Id => "text",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 12,
              Is_Image => False, Image_Path => "/tmp/notes.txt",
              Raw_Bytes => "alpha" & ASCII.LF & "beta" & ASCII.LF & "gamma");
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "a text file yields Text content");
         Assert (Natural (Content.Text_Lines.Length) = 3, "all three short lines are carried");
         Assert (To_String (Content.Text_Lines.First_Element) = "alpha", "the first line is preserved");
         Assert (not Content.Text_Truncated, "a short file is not truncated");
      end;

      --  An oversize text file is capped to Max_Preview_Lines and flagged.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "big.log", Filetype => "text/plain", Icon_Id => "text",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 9_999,
              Is_Image => False, Image_Path => "/tmp/big.log",
              Raw_Bytes => Many_Lines (Files.Quick_Look.Max_Preview_Lines + 25));
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "an oversize text file is still Text content");
         Assert
           (Natural (Content.Text_Lines.Length) <= Files.Quick_Look.Max_Preview_Lines,
            "the preview caps the number of lines");
         Assert (Content.Text_Truncated, "an oversize file is flagged truncated");
      end;

      --  A binary file (embedded NUL) falls back to the info card.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "app.bin", Filetype => "application/octet-stream", Icon_Id => "binary",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 64,
              Is_Image => False, Image_Path => "/tmp/app.bin",
              Raw_Bytes => "MZ" & ASCII.NUL & "payload");
      begin
         Assert (Content.Kind = Files.Quick_Look.Info_Content, "a binary file falls back to Info content");
      end;

      --  An image item yields Image content carrying its source path.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "photo.png", Filetype => "image/png", Icon_Id => "image",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 2048,
              Is_Image => True, Image_Path => "/tmp/photo.png", Raw_Bytes => "");
      begin
         Assert (Content.Kind = Files.Quick_Look.Image_Content, "an image item yields Image content");
         Assert (To_String (Content.Image_Path) = "/tmp/photo.png", "image content carries the source path");
      end;

      --  A directory yields the metadata info card with name and type.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "Documents", Filetype => "inode/directory", Icon_Id => "folder",
              Kind => Files.Types.Directory_Item, Size_Available => False, Size => 0,
              Is_Image => False, Image_Path => "/tmp/Documents", Raw_Bytes => "");
      begin
         Assert (Content.Kind = Files.Quick_Look.Info_Content, "a directory yields Info content");
         Assert (To_String (Content.Name) = "Documents", "info content carries the item name");
         Assert (To_String (Content.Filetype) = "inode/directory", "info content carries the item type");
      end;
   end Test_Quick_Look_Content_Prep;

   procedure Test_Quick_Look_Model_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;
      Model : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
   begin
      Files_Suite.Support.Select_Name (Model, "Alpha.txt");
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "quick look starts closed");

      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "toggling with a single selection opens quick look");
      Assert
        (Files.Model.Quick_Look_Path (Model) = To_String (Files.Model.Selected_Item (Model).Full_Path),
         "quick look records the previewed item path");
      Assert
        (Files.Model.Quick_Look_Content_Of (Model).Kind = Files.Quick_Look.Info_Content,
         "the pure toggle prepares metadata-only info content");

      Files.Model.Toggle_Quick_Look (Model);
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "toggling again closes quick look");

      --  Reopen, then a selection change closes the now-stale preview.
      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "quick look reopens for the current selection");
      Files_Suite.Support.Select_Name (Model, "Beta.txt");
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "changing the selection closes quick look");
   end Test_Quick_Look_Model_State;

   procedure Test_Group_By_Label_Bands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Header_Count : Natural := 0;
      Alpha_Pos    : Natural := 0;
      Beta_Pos     : Natural := 0;
      Gamma_Pos    : Natural := 0;
      Header_Before_Alpha : Boolean := False;
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Settings.Group_By := Files.Types.Group_By_Label;
      --  Alpha -> Red (band 1), Gamma -> Blue (band 5), Beta stays unlabeled
      --  (band 8, drawn last).
      Files.Settings.Set_Label (Settings, Join (Root, "Alpha.txt"), Files.Types.Red);
      Files.Settings.Set_Label (Settings, Join (Root, "Gamma.md"), Files.Types.Blue);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Prev_Was_Header : Boolean := False;
         Position : Natural := 0;
      begin
         for Item of Snapshot.Items loop
            Position := Position + 1;
            if Item.Is_Group_Header then
               Header_Count := Header_Count + 1;
               Assert (Item.Visible_Index = 0, "a label band header is non-selectable");
               Prev_Was_Header := True;
            else
               declare
                  Name : constant String := To_String (Item.Name);
               begin
                  if Name = "Alpha.txt" then
                     Alpha_Pos := Position;
                     Header_Before_Alpha := Header_Before_Alpha or else Prev_Was_Header;
                  elsif Name = "Beta.txt" then
                     Beta_Pos := Position;
                  elsif Name = "Gamma.md" then
                     Gamma_Pos := Position;
                  end if;
               end;
               Prev_Was_Header := False;
            end if;
         end loop;

         --  Three occupied bands (Red, Blue, Unlabeled) each emit one header.
         Assert (Header_Count = 3, "three occupied label bands emit three headers");
         Assert (Header_Before_Alpha, "the first labeled item sits under a band header");
         --  Band order: Red (Alpha) before Blue (Gamma) before Unlabeled (Beta).
         Assert (Alpha_Pos > 0 and then Gamma_Pos > 0 and then Beta_Pos > 0,
                 "every real item is placed under a band");
         Assert (Alpha_Pos < Gamma_Pos, "the red band precedes the blue band");
         Assert (Gamma_Pos < Beta_Pos, "the blue band precedes the unlabeled band");
      end;
   end Test_Group_By_Label_Bands;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Model_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Model;
