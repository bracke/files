with Ada.Calendar;
with Files.Grouping;
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
with Ada.Text_IO;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with Textrender.Fonts;
with Hostkit.Host;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Bounded_Text_IO;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
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
with Files_Suite.Repository;
with Files_Suite.Support;

package body Files_Suite.Model is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Host.Kind;
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
   use type Files.Model.Undo_Entry;
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
   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Restore_Admission (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Projection_Settings (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Executable_And_Symlink_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Encoding_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Document_Media_And_Source_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Detection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Paging_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Type_Ahead_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Input_Validation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Runtime_Sort_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Volume_Capabilities_And_Platform_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Discovery_Environment_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Open_And_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Volume_Details_By_Mount_Kind (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Eject_And_Open (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Settings_Exclusivity_And_Close (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selection_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Keyboard_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Blocks_Background_Input (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Row_Activation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bounded_Host_Text_Records (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Toggle_And_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Scroll_Resets_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_View_Mode_And_Bottom_Bar_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grid_Page_Keys_Page_The_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Main_View_Scroll_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Rename_Broadcast (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Command_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Temporary_Item_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Mixed_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Untitled_Name_Generation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Content_Prep (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Model_State (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Group_By_Label_Bands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Grouping_Band_Edges (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Snapshot_Labels_And_Favorites_At_Scale (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Snapshot_Owner_Names_From_Model (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_Accent_Folding_Sort'Access, "accented names sort next to their base letter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Bounds'Access, "undo and back-navigation history are bounded over a long session");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Restore_Admission'Access,
         "restored history filters malformed actions while retaining retryable snapshots");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Projection_Settings'Access, "directory projection settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Metadata_Policy'Access,
         "filetype metadata policy names what the current implementation parses");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Executable_And_Symlink_Metadata'Access, "directory metadata permissions for executables and symlinks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Encoding_Metadata'Access, "directory metadata reports text line counts and encodings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Document_Media_And_Source_Metadata'Access,
         "directory metadata for images, documents, archives, media and source files");
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
        (T, Test_Root_Discovery'Access, "root discovery is deterministic, duplicate-free and describes each root");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Volume_Capabilities_And_Platform_Profiles'Access,
         "root volume capabilities and native platform API profiles");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Discovery_Environment_Profiles'Access,
         "root discovery honours HOMEDRIVE/HOMEPATH and collapses HOME/USERPROFILE");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Open_And_Snapshot'Access,
         "drive command opens the root selector and the snapshot renders localized labels");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Volume_Details_By_Mount_Kind'Access,
         "root volume details classify malformed, network and local roots");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Eject_And_Open'Access, "root selector eject and open-selected-root commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Settings_Exclusivity_And_Close'Access,
         "root selector excludes settings and closes by toggle, Escape and close command");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selection_Navigation'Access,
         "root selection navigates, reports invalid roots and clears pending edits");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Keyboard_Navigation'Access, "root selector keyboard navigation wraps and clamps");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Blocks_Background_Input'Access,
         "root selector blocks background input but allows palette and drive toggle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Row_Activation'Access, "root selector Return and row click activate a root");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bounded_Host_Text_Records'Access,
         "bounded host text input rejects an oversized physical record atomically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Toggle_And_Scroll'Access, "info pane toggles and pages, saturating and clamping its scroll");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Scroll_Resets_And_Settings_Block'Access,
         "info pane scroll resets on selection changes and is blocked by settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_View_Mode_And_Bottom_Bar_Clicks'Access, "view mode shortcuts and bottom bar command clicks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Grid_Page_Keys_Page_The_Selection'Access, "grid PageUp/PageDown page the selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Main_View_Scroll_And_Settings_Block'Access,
         "main view scroll saturates and is blocked by the settings pane");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Rename_Mode'Access, "rename mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_Rename_Broadcast'Access, "synchronized multi-rename broadcast");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Command_State'Access,
         "create-file command adds one temporary item and closes stale overlays");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Temporary_Item_Guards'Access,
         "pending temporary item is visible and selected but not openable, deletable or renamable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Mixed_Selection'Access, "mixed selection with a temporary item disables open and delete");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Cancellation'Access,
         "F2, Escape and item click cancel a pending create without writing a file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Untitled_Name_Generation'Access, "untitled name generation skips existing entries and gaps");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Error_State'Access, "error-state representation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Content_Prep'Access, "quick look content preparation classifies text, image, and info");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Model_State'Access, "quick look model open/close state tracks the selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Group_By_Label_Bands'Access,
         "group-by-label partitions the snapshot into label-band headers with items under the right band");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Grouping_Band_Edges'Access,
         "type, modified and size grouping put each edge value in its band");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Snapshot_Labels_And_Favorites_At_Scale'Access,
         "a snapshot of many items marks exactly the stored favorites and labels, matched as the settings match them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Snapshot_Owner_Names_From_Model'Access,
         "the info pane shows the owner names sampled into the model, and none before they are sampled");
   end Register_Tests;

   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "sort");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Case_Sensitive : Boolean;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "zdir"));
      Write_File (Join (Dir, "b.txt"));
      Write_File (Join (Dir, "A.txt"));

      --  "A.txt" and "a.txt" are the same file on a case-insensitive filesystem,
      --  which macOS uses by default. The tie-break between names that differ
      --  only by case is exactly what the second half of this test pins down --
      --  and it cannot be staged where the two cannot coexist, so say so rather
      --  than assert against a fixture that was never built.
      Case_Sensitive := not Case_Insensitive_Filesystem;

      if Case_Sensitive then
         Write_File (Join (Dir, "a.txt"));
      end if;

      Write_File (Join (Root, "not-a-directory.txt"));
      Load := Files.File_System.Load_Directory (Dir, Settings);

      Assert (Load.Success, "directory load succeeds");
      Files_Suite.Support.Assert_Equal
        (Natural (Load.Items.Length),
         (if Case_Sensitive then 4 else 3),
         "all direct children are loaded; count=" & Natural'Image (Natural (Load.Items.Length)));
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "A.txt",
         "directory items sort by name with files");
      Load := Files.File_System.Load_Directory (Dir & "/.", Settings);
      Assert (Load.Success, "non-normal directory path loads");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Parent_Path),
         To_String (Load.Path),
         "item parent path is normalized");

      if Case_Sensitive then
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (2).Name),
            "a.txt",
            "case-insensitive equal names use deterministic fallback order");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (3).Name),
            "b.txt",
            "fallback name order is deterministic");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (4).Name),
            "zdir",
            "directories remain in normal name order");
      else
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (2).Name),
            "b.txt",
            "fallback name order is deterministic");
         Files_Suite.Support.Assert_Equal
           (To_String (Load.Items.Element (3).Name),
            "zdir",
            "directories remain in normal name order");
      end if;

      Load := Files.File_System.Load_Directory (Join (Root, "missing-directory"), Settings);
      Assert (not Load.Success, "missing directory load reports failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Error_Key),
         "error.directory.load",
         "missing directory load reports error key");
      Load := Files.File_System.Load_Directory (Join (Root, "not-a-directory.txt"), Settings);
      Assert (not Load.Success, "file path directory load reports failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Error_Key),
         "error.directory.load",
         "file path directory load reports error key");
   end Test_Directory_Sorting;

   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function F (S : String) return String renames Files.Types.Fold_For_Sort;

      --  UTF-8 bytes, spelt out so the test does not depend on how the source
      --  encoding treats a literal. C3 84 = U+00C4 A-umlaut, C3 9F = sharp-s,
      --  C3 A9 = e-acute.
      Umlaut_A : constant String := Character'Val (16#C3#) & Character'Val (16#84#);
      Sharp_S  : constant String := Character'Val (16#C3#) & Character'Val (16#9F#);
      E_Acute  : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);

      A_Umlaut_Name : constant String := Umlaut_A & "pfel";      --  "Äpfel"
      Sharp_Name    : constant String := "Stra" & Sharp_S & "e"; --  "Straße"
      Acute_Name    : constant String := "caf" & E_Acute;        --  "café"
   begin
      --  The accented letter folds to its base, so the key collates with the
      --  base letter rather than after all of a..z (the raw-byte-order bug).
      Files_Suite.Support.Assert_Equal (F (A_Umlaut_Name), "apfel", "an umlaut folds to its base letter");
      Files_Suite.Support.Assert_Equal (F (A_Umlaut_Name), F ("Apfel"), "accented and plain names share a fold key");
      Assert (F (A_Umlaut_Name) < F ("Bericht"), "the umlaut name sorts before Bericht");
      Assert
        (F (A_Umlaut_Name) < F ("Zebra"),
         "the umlaut name sorts before Zebra, not after every a..z name");
      Files_Suite.Support.Assert_Equal (F (Sharp_Name), "strasse", "sharp-s folds to ss");
      Files_Suite.Support.Assert_Equal
        (F (Sharp_Name),
         F ("Strasse"),
         "strasse and its sharp-s spelling share a fold key");
      Files_Suite.Support.Assert_Equal (F (Acute_Name), "cafe", "an acute accent folds to the base letter");

      --  Plain ASCII is just lower-cased, and a script with no Latin base is
      --  preserved rather than dropped.
      Files_Suite.Support.Assert_Equal (F ("HELLO.txt"), "hello.txt", "ASCII is lower-cased");
      Files_Suite.Support.Assert_Equal
        (F (Character'Val (16#CE#) & Character'Val (16#A9#)),
         Character'Val (16#CE#) & Character'Val (16#A9#),
         "a non-Latin codepoint keeps its own bytes");
   end Test_Accent_Folding_Sort;

   procedure Test_History_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Empty : Files.File_System.Item_Vectors.Vector;
      History_Path : constant String := Join (Root, "history-entry");
   begin
      --  Recording far more undo entries than the cap keeps only the most recent
      --  ones; the reachable LIFO history is bounded rather than growing forever.
      Reset_Root;
      Write_Binary_File (History_Path, "history");
      for Index in 1 .. 260 loop
         declare
            Image : constant String := Integer'Image (Index);
            pragma Unreferenced (Image);
            From : Files.Types.String_Vectors.Vector;
         begin
            From.Append (To_Unbounded_String (History_Path));
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, From => From,
               To => Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         end;
      end loop;
      declare
         Count  : Natural := 0;
         Action : Files.Model.Undo_Entry;
         Found  : Boolean;
      begin
         loop
            Files.Model.Take_Undo (Model, Action, Found);
            exit when not Found;
            Count := Count + 1;
         end loop;
         Files_Suite.Support.Assert_Equal (Count, 200, "the undo stack is capped at 200 entries; kept" & Count'Image);
      end;

      --  Back-navigation history is bounded the same way.
      for Index in 1 .. 260 loop
         Files.Model.Navigate_To (Model, "/dir/" & Integer'Image (Index), Empty);
      end loop;
      declare
         Count : Natural := 0;
      begin
         while Files.Model.Can_Go_Back (Model) loop
            Files.Model.Go_Back (Model);
            Count := Count + 1;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Count,
            200,
            "back-navigation history is capped at 200; went back" & Count'Image);
      end;
   end Test_History_Bounds;

   procedure Test_History_Restore_Admission
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;

      function Rename_Action return Files.Model.Undo_Entry is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Rename;
         Result.From.Append (To_Unbounded_String ("/missing/new-name"));
         Result.To.Append (To_Unbounded_String ("/missing/old-name"));
         Result.Created_Identities.Append (To_Unbounded_String ("persisted-identity"));
         Result.Created_Tree_Revisions.Append (Null_Unbounded_String);
         return Result;
      end Rename_Action;

      Good_Undo : Files.Model.Undo_Entry := Rename_Action;
      Good_Redo : constant Files.Model.Undo_Entry := Rename_Action;
      Short_Targets : Files.Model.Undo_Entry := Rename_Action;
      Foreign_Marker : Files.Model.Undo_Entry := Rename_Action;
      Bad_Metadata : Files.Model.Undo_Entry := Rename_Action;
      Bad_Restore : Files.Model.Undo_Entry := Rename_Action;
      Bad_Copy_Records : Files.Model.Undo_Entry := Rename_Action;
      Relative_From : Files.Model.Undo_Entry := Rename_Action;
      Nul_Target : Files.Model.Undo_Entry := Rename_Action;
      Relative_Forward : Files.Model.Undo_Entry := Rename_Action;
      Relative_Restore : Files.Model.Undo_Entry := Rename_Action;
      Relative_Copy_Record : Files.Model.Undo_Entry := Rename_Action;
      Undo_Only_Redo : Files.Model.Undo_Entry := Rename_Action;
   begin
      Good_Undo.Reverse_Completed.Append (Good_Undo.From.First_Element);

      Short_Targets.To.Clear;

      Foreign_Marker.Reverse_Completed.Append
        (To_Unbounded_String ("/missing/not-in-action"));

      Bad_Metadata.Kind := Files.Model.Undo_Set_Permissions;
      Bad_Metadata.To.Replace_Element
        (Bad_Metadata.To.First_Index, To_Unbounded_String ("not-a-mode"));
      Bad_Metadata.Forward.Append (To_Unbounded_String ("420"));

      Bad_Restore.Redoable := False;
      Bad_Restore.Restore_Trash.Append (To_Unbounded_String ("/missing/trash-entry"));

      Bad_Copy_Records.Kind := Files.Model.Undo_Delete_Created;
      Bad_Copy_Records.To.Clear;
      Bad_Copy_Records.Forward.Append (To_Unbounded_String ("/missing/source"));
      Bad_Copy_Records.Create_Kind := Files.Model.Create_Copy;
      Bad_Copy_Records.Copy_Records.Append (To_Unbounded_String ("incomplete-group"));

      Relative_From.From.Replace_Element
        (Relative_From.From.First_Index, To_Unbounded_String ("relative-new-name"));

      Nul_Target.To.Replace_Element
        (Nul_Target.To.First_Index,
         To_Unbounded_String ("/missing/old" & Character'Val (0) & "name"));

      Relative_Forward.Kind := Files.Model.Undo_Delete_Created;
      Relative_Forward.To.Clear;
      Relative_Forward.Forward.Append (To_Unbounded_String ("relative-source"));
      Relative_Forward.Create_Kind := Files.Model.Create_Symbolic_Link;

      Relative_Restore.Redoable := False;
      Relative_Restore.Kind := Files.Model.Undo_Move;
      Relative_Restore.Restore_Trash.Append
        (To_Unbounded_String ("/missing/trash-entry"));
      Relative_Restore.Restore_Identities.Append
        (To_Unbounded_String ("persisted-trash-identity"));
      Relative_Restore.Restore_Targets.Append
        (To_Unbounded_String ("relative-restore-target"));

      Relative_Copy_Record.Kind := Files.Model.Undo_Delete_Created;
      Relative_Copy_Record.To.Clear;
      Relative_Copy_Record.Forward.Append
        (To_Unbounded_String ("/missing/source"));
      Relative_Copy_Record.Create_Kind := Files.Model.Create_Copy;
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("source-identity"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("source-revision"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("content-digest"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("relative-copied-path"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("destination-identity"));
      Relative_Copy_Record.Copy_Records.Append
        (To_Unbounded_String ("destination-revision"));

      Undo_Only_Redo.Redoable := False;

      Undo.Append (Short_Targets);
      Undo.Append (Good_Undo);
      Undo.Append (Foreign_Marker);
      Undo.Append (Bad_Metadata);
      Undo.Append (Bad_Restore);
      Undo.Append (Bad_Copy_Records);
      Undo.Append (Relative_From);
      Undo.Append (Nul_Target);
      Undo.Append (Relative_Forward);
      Undo.Append (Relative_Restore);
      Undo.Append (Relative_Copy_Record);
      Redo.Append (Undo_Only_Redo);
      Redo.Append (Good_Redo);

      Files.Model.Set_History (Model, Undo, Redo);

      Assert
        (Natural (Files.Model.Undo_History (Model).Length) = 1
         and then Files.Model.Undo_History (Model).First_Element = Good_Undo,
         "only the structurally and path-valid Undo action and its partial progress survive");
      Assert
        (Natural (Files.Model.Redo_History (Model).Length) = 1
         and then Files.Model.Redo_History (Model).First_Element = Good_Redo,
         "Redo filters undo-only entries but retains a valid action with stale paths");
      Assert
        (Files.Model.Undo_History (Model).First_Element.Created_Identities.First_Element =
           To_Unbounded_String ("persisted-identity"),
         "sanitizing restored history does not recapture or discard its identity snapshot");
   end Test_History_Restore_Admission;

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
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 3, "hidden files are hidden by default");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "afile.txt",
         "name ordering can sort files before dirs");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "c.bin",
         "name sort keeps files in deterministic order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "zdir",
         "directory follows file when name sort wins");

      Settings.Sort_Field_Value := Files.Settings.Sort_By_Filetype;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "c.bin",
         "filetype sort uses configured field");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "zdir",
         "filetype ties fall back to name order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "afile.txt",
         "text file sorts after inode/filetype entries");

      Settings.Sort_Field_Value := Files.Settings.Sort_By_Size;
      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "c.bin",
         "descending size sort uses metadata");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "afile.txt",
         "smaller file follows larger file");

      Settings.Show_Hidden_Files := True;
      Settings.Sort_Field_Value := Files.Settings.Sort_By_Name;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 5, "show-hidden setting exposes dot files");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         ".profile",
         "hidden file participates in stable sorting");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         ".secret",
         "leading-dot files sort deterministically");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Filetype),
         "application/octet-stream",
         "leading-dot file loaded from disk does not use extension mapping");

      Ada.Directories.Create_Path (Join (Dir, ".vault"));
      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 3, "hidden directories are hidden by default");

      Settings.Show_Hidden_Files := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 6, "show-hidden setting exposes dot directories");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         ".profile",
         "hidden files sort by name with other items");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         ".secret",
         "hidden files remain in deterministic order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         ".vault",
         "hidden directories sort by name with files");

      Ada.Directories.Create_Path (Tie_Dir);
      Write_File (Join (Tie_Dir, "B_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "a_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "later.txt"), "larger");

      Settings.Show_Hidden_Files := False;
      Settings.Sort_Field_Value := Files.Settings.Sort_By_Size;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "a_equal.txt",
         "ascending size ties use name fallback");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "B_equal.txt",
         "ascending size tie fallback is deterministic");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "later.txt",
         "ascending size places larger item after ties");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "later.txt",
         "descending size places larger item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "a_equal.txt",
         "descending size ties keep deterministic name fallback");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "B_equal.txt",
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
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "old.txt",
         "modified sort orders older item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name),
         "new.txt",
         "modified sort orders newer item last");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Modified_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "new.txt",
         "descending modified sort orders newer item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name),
         "old.txt",
         "descending modified sort orders older item last");
   end Test_Directory_Projection_Settings;

   --  The "extra info" is now computed lazily (not stored on load), so tests
   --  compute it on demand via the shared token function.
   function Item_Extra (I : Files.File_System.Directory_Item) return String is
     (Files.File_System.Extra_Info_Token
        (To_String (I.Full_Path), I.Kind, To_String (I.Filetype)));

   procedure Test_Filetype_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
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
   end Test_Filetype_Metadata_Policy;

   procedure Test_Executable_And_Symlink_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Run_Path  : constant String := Join (Root, "run.sh");
      --  What "executable" means is host-specific, so cover both meanings: the
      --  mode bit on POSIX, the extension on Windows. See Support.Honours_Executable_Bit.
      Bat_Path  : constant String := Join (Root, "run.bat");
      Text_Path : constant String := Join (Root, "plain.txt");
      Symlink_Path : constant String := Join (Root, "link-to-plain.adb");
      Executable_Symlink_Path : constant String := Join (Root, "link-to-run.sh");
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Run : Boolean := False;
      Found_Symlink : Boolean := False;
      Found_Executable_Symlink : Boolean := False;
      Symlink_Created : Boolean := False;
      Executable_Symlink_Created : Boolean := False;
   begin
      Reset_Root;
      Write_File (Run_Path, "echo run");
      Write_File (Bat_Path, "@echo run");
      Write_File (Text_Path, "plain");
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
               if Files_Suite.Support.Honours_Executable_Bit then
                  Assert
                    (Item.Kind = Files.Types.Executable_Item,
                     "the executable bit affects item kind");
               else
                  Assert
                    (Item.Kind /= Files.Types.Executable_Item,
                     "a chmod +x .sh is not an executable on a host that runs by extension");
               end if;
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
               if Files_Suite.Support.Honours_Executable_Bit then
                  Assert (Permissions (3) = 'x', "executable permission is captured");
               end if;
            end;
         elsif To_String (Item.Name) = "run.bat" then
            --  The other meaning of executable: no bit was ever set on this file.
            if not Files_Suite.Support.Honours_Executable_Bit then
               Assert
                 (Item.Kind = Files.Types.Executable_Item,
                  "a .bat is an executable on a host that runs by extension");
               Assert
                 (To_String (Item.Permissions) (3) = 'x',
                  "and it is reported as executable in its permissions");
            end if;
         elsif To_String (Item.Name) = "plain.txt" then
            Assert (To_String (Item.Permissions)'Length = 3, "regular file permissions are captured");
         elsif To_String (Item.Name) = "link-to-plain.adb" then
            Found_Symlink := True;
            Assert (Item.Kind = Files.Types.Symlink_Item, "symlink metadata affects item kind");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "inode/symlink",
               "real symlink directory item ignores extension mappings");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Icon_Id),
               "link",
               "real symlink directory item uses link icon");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "symlink.target|plain.txt",
               "real symlink directory item records target metadata");
         elsif To_String (Item.Name) = "link-to-run.sh" then
            Found_Executable_Symlink := True;
            Assert
              (Item.Kind = Files.Types.Symlink_Item,
               "executable symlink metadata keeps symlink kind");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "inode/symlink",
               "executable symlink filetype wins before executable metadata");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "symlink.target|run.sh",
               "executable symlink records target metadata");
         end if;
      end loop;

      Assert (Found_Run, "executable item was loaded");
      if Symlink_Created then
         Assert (Found_Symlink, "symlink item was loaded");
      end if;
      if Executable_Symlink_Created then
         Assert (Found_Executable_Symlink, "executable symlink item was loaded");
      end if;
   end Test_Executable_And_Symlink_Metadata;

   procedure Test_Text_Encoding_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Long_Text_Path : constant String := Join (Root, "long-line.txt");
      Utf8_Path : constant String := Join (Root, "utf8.txt");
      Binary_Text_Path : constant String := Join (Root, "binary.txt");
      Late_Binary_Text_Path : constant String := Join (Root, "late-binary.txt");
      Sampled_Text_Path : constant String := Join (Root, "sampled.txt");
      Huge_Oneline_Path : constant String := Join (Root, "huge-oneline.txt");
      Split_Utf8_Path : constant String := Join (Root, "split-utf8.txt");
      Overlong_Text_Path : constant String := Join (Root, "overlong.txt");
      Surrogate_Text_Path : constant String := Join (Root, "surrogate.txt");
      Markdown_Path : constant String := Join (Root, "notes.md");
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Long_Text : Boolean := False;
      Found_Utf8 : Boolean := False;
      Found_Binary_Text : Boolean := False;
      Found_Late_Binary_Text : Boolean := False;
      Found_Sampled_Text : Boolean := False;
      Found_Huge_Oneline : Boolean := False;
      Found_Split_Utf8 : Boolean := False;
      Found_Overlong_Text : Boolean := False;
      Found_Surrogate_Text : Boolean := False;
      Found_Markdown : Boolean := False;
   begin
      Reset_Root;
      Write_File (Long_Text_Path, String'(1 .. 2048 => 'x'));
      Write_Binary_File (Utf8_Path, "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Binary_Text_Path, "bad" & Character'Val (16#C3#));
      Write_Binary_File (Late_Binary_Text_Path, String'(1 .. 4096 => 'x') & Character'Val (0));
      --  A binary byte only past the 128 KiB encoding sample window: a bounded
      --  scan classifies this by its clean prefix and never reads the NUL.
      Write_Binary_File (Sampled_Text_Path, String'(1 .. 131_072 => 'x') & Character'Val (0));
      --  Bigger than the metadata readers' 8 MiB scan cap and newline-free until
      --  past it: a correctly capped line count stops early and reports the one
      --  trailing partial line (1), rather than reading the whole file to find
      --  the two newlines near its end.
      Write_Filler_File
        (Huge_Oneline_Path, 'x', 8_388_610, Character'Val (10) & "A" & Character'Val (10));
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

      Load := Files.File_System.Load_Directory (Root, Settings);

      for Item of Load.Items loop
         if To_String (Item.Name) = "long-line.txt" then
            Found_Long_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|ascii",
               "long text lines count as one physical line");
         elsif To_String (Item.Name) = "utf8.txt" then
            Found_Utf8 := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|utf8",
               "UTF-8 text files expose text encoding metadata");
         elsif To_String (Item.Name) = "binary.txt" then
            Found_Binary_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "invalid text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "late-binary.txt" then
            Found_Late_Binary_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "text encoding metadata scans beyond the first read buffer");
         elsif To_String (Item.Name) = "sampled.txt" then
            Found_Sampled_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|ascii",
               "text encoding sampling stops at a bounded prefix, not the whole file");
         elsif To_String (Item.Name) = "huge-oneline.txt" then
            Found_Huge_Oneline := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|ascii",
               "line counting stops at the byte-scan cap instead of reading a huge file");
         elsif To_String (Item.Name) = "split-utf8.txt" then
            Found_Split_Utf8 := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|utf8",
               "text encoding metadata accepts UTF-8 split across read buffers");
         elsif To_String (Item.Name) = "overlong.txt" then
            Found_Overlong_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "overlong UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "surrogate.txt" then
            Found_Surrogate_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "surrogate UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "notes.md" then
            Found_Markdown := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "markdown.lines_encoding|2|ascii",
               "Markdown files expose markdown line and encoding metadata");
         end if;
      end loop;

      Assert (Found_Long_Text, "long text line item was loaded");
      Assert (Found_Utf8, "UTF-8 text item was loaded");
      Assert (Found_Binary_Text, "binary text item was loaded");
      Assert (Found_Late_Binary_Text, "late binary text item was loaded");
      Assert (Found_Sampled_Text, "sampled text item was loaded");
      Assert (Found_Huge_Oneline, "huge single-line text item was loaded");
      Assert (Found_Split_Utf8, "split UTF-8 text item was loaded");
      Assert (Found_Overlong_Text, "overlong UTF-8 text item was loaded");
      Assert (Found_Surrogate_Text, "surrogate UTF-8 text item was loaded");
      Assert (Found_Markdown, "Markdown item was loaded");
   end Test_Text_Encoding_Metadata;

   procedure Test_Document_Media_And_Source_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
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
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
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
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "folder"));
      Write_File (Join (Join (Root, "folder"), "inside.txt"));
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

      Load := Files.File_System.Load_Directory (Root, Settings);

      for Item of Load.Items loop
         if To_String (Item.Name) = "picture.png" then
            Found_Png := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "image.dimensions|32x16",
               "PNG dimensions are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "photo.jpg" then
            Found_Jpeg := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "image.dimensions|48x24",
               "JPEG dimensions tolerate fill bytes before frame markers");
         elsif To_String (Item.Name) = "folder" then
            Found_Dir := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "directory.count|1",
               "directory item counts are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "paper.pdf" then
            Found_Pdf := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/pdf",
               "PDF extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "document.pdf.pages|1",
               "PDF files expose page marker metadata");
         elsif To_String (Item.Name) = "paper-control.pdf" then
            Found_Pdf_Control := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "document.pdf.pages|2",
               "PDF page markers accept vertical tab and form feed separators");
         elsif To_String (Item.Name) = "bundle.zip" then
            Found_Zip := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/zip",
               "ZIP extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.zip.entries|1",
               "ZIP files expose entry-count metadata");
         elsif To_String (Item.Name) = "split.zip" then
            Found_Split_Zip := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.zip.entries|1",
               "ZIP entry counting detects signatures split across read buffers");
         elsif To_String (Item.Name) = "report.docx" then
            Found_Docx := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
               "DOCX extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "office.docx.entries|1",
               "DOCX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "sheet.xlsx" then
            Found_Xlsx := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
               "XLSX extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "office.xlsx.entries|1",
               "XLSX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "track.mp3" then
            Found_Mp3 := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "audio/mpeg",
               "MP3 extension maps to filetype");
            Files_Suite.Support.Assert_Equal (Item_Extra (Item), "media.kind|audio", "MP3 files expose audio metadata");
         elsif To_String (Item.Name) = "clip.mp4" then
            Found_Mp4 := True;
            Files_Suite.Support.Assert_Equal (To_String (Item.Filetype), "video/mp4", "MP4 extension maps to filetype");
            Files_Suite.Support.Assert_Equal (Item_Extra (Item), "media.kind|video", "MP4 files expose video metadata");
         elsif To_String (Item.Name) = "archive.tar.gz" then
            Found_Tar_Gz := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/gzip-tar",
               "compound extension maps to filetype; got "
               & To_String (Item.Filetype));
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.format|gzip",
               "compound gzip-tar archive files expose gzip format metadata");
         elsif To_String (Item.Name) = "unit.adb" then
            Found_Ada := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "text/x-ada",
               "Ada body extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.ada.lines_encoding|4|ascii",
               "Ada source files expose source metadata");
         elsif To_String (Item.Name) = "data.json" then
            Found_Json := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/json",
               "JSON extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.json.lines_encoding|1|ascii",
               "JSON files expose source metadata");
         elsif To_String (Item.Name) = "doc.xml" then
            Found_Xml := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/xml",
               "XML extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.xml.lines_encoding|1|ascii",
               "XML files expose source metadata");
         end if;
      end loop;

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
   end Test_Document_Media_And_Source_Metadata;

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
        (Files.File_Types.Extension_Of ("archive.tar.gz"),
         "gz",
         "final extension is extracted");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of ("MAIN.ADB"),
         "adb",
         "extension extraction normalizes case");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (".profile"),
         "",
         "leading-dot file has no extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of ("name."),
         "",
         "trailing-dot file has no extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (" main.adb "),
         "adb",
         "extension extraction trims whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (ASCII.LF & "main.adb" & ASCII.LF),
         "adb",
         "extension extraction trims line-feed whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (ASCII.VT & "main.adb" & ASCII.FF),
         "adb",
         "extension extraction trims vertical-tab and form-feed whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (C1_Break & "main.adb" & C1_Break),
         "adb",
         "extension extraction trims C1 line-break whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (NBSP & "main.adb" & NBSP),
         "adb",
         "extension extraction trims UTF-8 NBSP whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of (Line_Separator & "main.adb" & Line_Separator),
         "adb",
         "extension extraction trims UTF-8 line-separator whitespace");
      Files_Suite.Support.Assert_Equal (Files.File_Types.Extension_Of ("   "), "", "blank filename has no extension");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of ("/tmp/dir.with.dots/main.adb"),
         "adb",
         "extension extraction uses the Unix path leaf name");
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of ("C:\tmp\dir.with.dots\main.adb"),
         "adb",
         "extension extraction uses the Windows path leaf name");
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         Files_Suite.Support.Assert_Equal
           (Files.File_Types.Extension_Of ("report.txt\raw"),
            "txt\raw",
            "a POSIX backslash remains part of the extension-bearing filename");
      end if;
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Extension_Of ("/tmp/dir.with.dots/file"),
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
      Files.Settings.Add_Extension_Mapping (Settings, "backup.tar.gz", "application/x-backup");
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

   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Large_Icons,
         "large icons can be selected");
      Files.Commands.Execute (Files.Commands.Select_Details_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details command selects details");
      Files.Commands.Execute (Files.Commands.Select_Small_Icons_Command, Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "small command clears prior mode");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "first movement selects first visible item");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Left);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "left from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "right from last wraps to first");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Up);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "up from first wraps to last");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "right from last wraps to first after up wrap");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 2, "down advances selection");
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
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection_Grid_Columns (Grid_Model),
            2,
            "model records rendered grid columns");
         Files.Model.Select_Visible (Grid_Model, 1);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            3,
            "down moves to same column in next grid row");
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Up);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            1,
            "up moves to same column in previous grid row");
         Files.Model.Select_Visible (Grid_Model, 5);
         Files.Model.Move_Selection (Grid_Model, Guikit.Input.Move_Down);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Grid_Model),
            1,
            "down from last grid item wraps to first");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "toggle adds a second deterministic selection");
      Assert (Files.Model.Is_Selected (Model, 1), "first toggled item is selected");
      Assert (Files.Model.Is_Selected (Model, 2), "primary item remains selected");
      declare
         Selected_Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Selected_Items.Length),
            2,
            "selected items API returns all selected items");
         Files_Suite.Support.Assert_Equal
           (To_String (Selected_Items.Element (1).Name),
            "Alpha.txt",
            "selected items use item order");
         Files_Suite.Support.Assert_Equal
           (To_String (Selected_Items.Element (2).Name),
            "Beta.txt",
            "selected items include primary item");
      end;
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 1, "toggle removes selected item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "primary selection falls back to remaining selected item");
      Files.Model.Clear_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "clear selection empties deterministic selection set");
      Files.Model.Select_Visible (Model, 2);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "controller arrow moves selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "controller down advances selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "shift-down expands selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         2,
         "shift-down moves primary selection to target item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "shift-down keeps anchor and target selected");
      Assert (Files.Model.Is_Selected (Model, 1), "shift-down keeps anchor item selected");
      Assert (Files.Model.Is_Selected (Model, 2), "shift-down selects target item");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down, Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "second shift-down expands selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "second shift-down moves primary selection to next item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "second shift-down preserves range anchor");
      Assert (Files.Model.Is_Selected (Model, 1), "second shift-down keeps original anchor selected");
      Assert (Files.Model.Is_Selected (Model, 3), "second shift-down selects new target item");
      Files.Model.Select_Visible (Model, 3);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1, Modifiers => Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "control-click toggles selection");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 2, "control-click adds to selection");
      Assert (Files.Model.Is_Selected (Model, 1), "control-click selects clicked item");
      Assert (Files.Model.Is_Selected (Model, 3), "control-click preserves existing selection");
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "second control-click removes selected item");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "range selection selects every visible item");
      Assert (Files.Model.Is_Selected (Model, 1), "range selection includes anchor");
      Assert (Files.Model.Is_Selected (Model, 2), "range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "range selection includes target");
      Files.Model.Select_Visible_Range (Model, 3, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "reverse range selection selects every visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "reverse range selection makes target primary");
      Assert (Files.Model.Is_Selected (Model, 1), "reverse range selection includes target");
      Assert (Files.Model.Is_Selected (Model, 2), "reverse range selection includes middle item");
      Assert (Files.Model.Is_Selected (Model, 3), "reverse range selection includes anchor");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "select-all selects every visible loaded item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "select-all keeps first visible item primary");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "select-all respects visible filter projection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "filtered select-all selects visible item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_All_Command,
         "Control+A routes select-all command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "Control+A selects all visible loaded items");
      Files.Model.Clear_Selection (Model);
      Files.Model.Select_Visible (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "invert test starts with a single selection");
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "invert selects the previously unselected visible items");
      Assert (not Files.Model.Is_Selected (Model, 1), "invert unselects the previously selected item");
      Assert (Files.Model.Is_Selected (Model, 2), "invert selects a previously unselected item");
      Assert (Files.Model.Is_Selected (Model, 3), "invert selects the remaining unselected item");
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "second invert restores the original selection count");
      Assert (Files.Model.Is_Selected (Model, 1), "second invert restores the original selected item");
      Assert (not Files.Model.Is_Selected (Model, 2), "second invert clears the intermediate selection");
      Files.Model.Set_Filter (Model, "alpha");
      Files.Model.Clear_Selection (Model);
      Files.Model.Invert_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "invert only touches visible filtered items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "invert selects the visible filtered item");
      Files.Model.Set_Filter (Model, "");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_I, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Invert_Selection_Command,
         "Control+I routes invert-selection command");
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "deselect test starts from a full selection");
      Files.Model.Deselect_All (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "deselect all clears the selection");
      Files.Model.Select_All_Visible (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_A, Ctrl_Shift);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Deselect_All_Command,
         "Control+Shift+A routes deselect-all command");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "Control+Shift+A clears the selection");
      Files.Model.Select_Visible (Model, 1);
      declare
         Shift : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Shift (Guikit.Input.Shift_Key) := True;
         Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3, Modifiers => Shift);
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "shift-click selects a deterministic visible range");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "shift-click makes the clicked item primary");
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Focus_Path_Input (Model);
      declare
         Before_Focused_Key : constant Natural := Files.Model.Selected_Index (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "focused input suppresses arrow selection");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            Before_Focused_Key,
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         25,
         "paging model exposes all 25 visible items");

      --  Direct model primitives: first / last selection.
      Files.Model.Select_Last_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         25,
         "Select_Last_Visible selects the last visible item");
      Files.Model.Select_First_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "Select_First_Visible selects the first visible item");

      --  Single-column paging moves by Page_Rows items and clamps at the edges.
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         11,
         "PageDown advances the selection by one page (10 rows)");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         21,
         "a second PageDown advances another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 25, "PageDown clamps at the last item");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 25, "PageDown on the last item stays put");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         15,
         "PageUp retreats the selection by one page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 5, "a second PageUp retreats another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "PageUp clamps at the first item");

      --  Grid stride: with 3 columns a page spans Page_Rows * columns items.
      Files.Model.Set_Selection_Grid_Columns (Model, 3);
      Files.Model.Select_First_Visible (Model);
      Files.Model.Move_Selection_By_Page (Model, 2, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         7,
         "grid paging moves Page_Rows * columns items (2*3)");

      --  Empty model: paging clears rather than crashing.
      declare
         Empty : Files.Model.Window_Model := Paging_Model (0);
      begin
         Files.Model.Select_First_Visible (Empty);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Empty),
            0,
            "first-visible on an empty grid selects nothing");
         Files.Model.Move_Selection_By_Page (Empty, 10, Down => True);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Empty),
            0,
            "paging an empty grid selects nothing");
      end;

      --  Through the real controller key seam: plain Home/End move the grid
      --  selection and never navigate (Alt+Home stays the navigate-home key).
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "plain End moves the grid selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         25,
         "plain End selects the last visible item");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Home_Dir, "plain End does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "plain Home moves the grid selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "plain Home selects the first visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Home_Dir,
         "plain Home does not navigate home (that stays Alt+Home)");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "plain Home on the first item is ignored");

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
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "do", 1),
         2,
         "matcher returns the first item starting with the prefix");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "DO", 1),
         2,
         "matcher is case-insensitive");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "z", 1),
         0,
         "matcher returns zero when nothing matches");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "", 1),
         0,
         "matcher returns zero for an empty prefix");
      --  Start-index respected: "d" items sit at 1, 3, 4; scanning from 3 finds 3.
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 3),
         3,
         "matcher honours the start index inclusively");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 5),
         1,
         "matcher wraps around past the end of the projection");

      --  Through the seam with the grid focused (Focus_None): a bare printable
      --  character selects the first matching item.
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "fresh grid model starts unfocused");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "type-ahead reports a moved selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "typing d selects the first d-item (delta)");

      --  A longer prefix refines to the matching item.
      Feed ("u");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "refining to du selects dune");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "du",
         "buffer accumulates the refined prefix");

      --  A non-matching character leaves the selection where it was.
      Feed ("z");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "a non-matching character keeps the current selection");

      --  Repeated single letter cycles through every item starting with it.
      Model := New_Grid_Model;
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "first d selects delta");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 2, "second d cycles to Doc");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "third d cycles to dune");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 4, "fourth d cycles to date");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "fifth d wraps back to delta");

      --  Reset trigger (arrow key): a fresh keystroke starts a new prefix rather
      --  than extending the stale one.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "du selects dune before the reset");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "",
         "an arrow key clears the type-ahead buffer");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 4, "arrow key moves selection to date");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "a keystroke after the reset starts a fresh single-letter cycle (delta)");

      --  Reset trigger (focus change): focusing a text field clears the buffer,
      --  and returning to the grid begins a fresh prefix.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "du selects dune before the focus change");
      Files.Model.Focus_Path_Input (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "",
         "focusing a text field clears the type-ahead buffer");

      --  Typing into the focused text field edits the field and never moves the
      --  grid selection (the path input, unlike the filter, does not reproject).
      declare
         Before        : constant Natural := Files.Model.Selected_Index (Model);
         Before_Length : constant Natural := Files.Model.Path_Input_Text (Model)'Length;
      begin
         Feed ("x");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Path_Input_Text (Model)'Length,
            Before_Length + 1,
            "typed text lands in the focused path input");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Type_Ahead_Buffer (Model),
            "",
            "typing into a text field never feeds type-ahead");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            Before,
            "typing into a text field does not jump the grid selection");
      end;

      --  Back on the grid, a fresh keystroke starts a new prefix.
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "cancelling returns focus to the grid");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "d",
         "a keystroke after the focus reset starts a fresh prefix");
   end Test_Type_Ahead_Selection;

   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model        : Files.Model.Window_Model := Sample_Model;
      Missing_Item : Files.File_System.Directory_Item;
      Result       : Files.Controller.Controller_Result;
   begin
      Missing_Item := Files.Model.Visible_Item (Model, 99);
      Files_Suite.Support.Assert_Equal
        (To_String (Missing_Item.Name),
         "",
         "invalid visible item index returns empty item");
      Assert (Missing_Item.Kind = Files.Types.Unknown_Item, "invalid visible item index returns unknown kind");
      declare
         --  Content-search hits whose names lack the query stay listed, and the
         --  drawn rows agree with the count that clicks and selection use.
         Search_Model : Files.Model.Window_Model := Sample_Model;
      begin
         Files.Model.Set_Filter (Search_Model, "zzz-not-in-any-name");
         Files.Model.Note_Search_Results (Search_Model, Files.Types.Search_Contents);
         Assert
           (Natural (Files.Model.Visible_Rows (Search_Model).Length) = Files.Model.Visible_Count (Search_Model)
            and then Files.Model.Visible_Count (Search_Model) = Files.Model.Item_Count (Search_Model),
            "search results draw every hit, matching the rows clicks map to");
      end;
      Files.Model.Select_Visible (Model, 3);
      Files.Model.Set_Filter (Model, "alp");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "filter matches item names case-insensitively");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "filtered-out selection moves to first visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "selection points to visible item");
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
         Files_Suite.Support.Assert_Equal
           (Files.Model.Visible_Count (Unicode_Model),
            1,
            "filter matches UTF-8 Latin-1 item names case-insensitively");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Name (Unicode_Model),
            Upper_Name,
            "UTF-8 Latin-1 filter selects the matching visible item");
      end;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single visible item movement is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "single visible item movement keeps selection");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Visible_Selection (Model, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         3,
         "filter reconciliation starts from multi-selection");
      Files.Model.Set_Filter (Model, "beta");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "multi-selection filter leaves one visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "filter reconciliation drops invisible multi-selected items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Beta.txt",
         "filter reconciliation keeps visible multi-selected item primary");
      Files.Model.Set_Filter (Model, "zzz");
      Files_Suite.Support.Assert_Equal (Files.Model.Visible_Count (Model), 0, "unmatched filter hides all items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "selection becomes empty when no items are visible");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "moving selection with no visible items stays empty");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "empty visible selection movement is ignored");
   end Test_Filtering_Reconciles_Selection;

   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Items : constant Files.File_System.Item_Vectors.Vector := Sample_Items;
   begin
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "empty back history leaves path unchanged");
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "empty forward history leaves path unchanged");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "history test starts with multi-selection");
      Files.Model.Navigate_To (Model, Root, Items);
      Assert (not Files.Model.Can_Go_Back (Model), "same-path navigation does not push history");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "same-path navigation clears multi-selection state");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/second", Items);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "navigation clears multi-selection state");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/third", Items);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "second navigation clears multi-selection state");
      Assert (Files.Model.Can_Go_Back (Model), "back is enabled after navigation");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Path_Input_Text (Model, "/tmp/bad-history-path");
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/second",
         "back restores previous path");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "back clears multi-selection state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/files_aunit/second",
         "back restores path input text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "back clears path validation state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "back closes command palette");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "back clears focus");
      Assert (Files.Model.Can_Go_Forward (Model), "forward is enabled after back");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/branch", Items);
      Assert (not Files.Model.Can_Go_Forward (Model), "new navigation after back clears forward history");
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/second",
         "back reaches branch origin");
      Files.Model.Begin_Create_File (Model, "forward-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/branch",
         "forward reaches branch path");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "forward clears multi-selection state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/files_aunit/branch",
         "forward restores path input text");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "forward closes command palette");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "forward clears focus");
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/branch",
         "forward is exhausted after branch path");
      Files.Model.Go_Home (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/home/test",
         "home navigates to model home path");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path input receives focus directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "path input focus restores current path text");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Assert (not Files.Model.Path_Input_Is_Valid (Model), "invalid input sets validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "error.path.missing",
         "invalid input records error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "invalid input does not change current path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "invalid path input keeps focus");
      Files.Model.Focus_Filter_Input (Model);
      Files.Model.Focus_Path_Input (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Root,
         "refocus restores current path after invalid input");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "refocus clears stale path validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "refocus clears stale path validation error");
      Files.Model.Set_Path_Input_Text (Model, "/does/not/exist");
      Files.Model.Commit_Path_Input (Model, Invalid, Empty);
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Path_Input_Text (Model), Root, "escape restores current path text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "escape clears path validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "escape clears path validation error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "escape clears path input focus");

      Files.Model.Open_Command_Palette (Model);
      Files.Model.Focus_Path_Input (Model);
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "path input focus closes command palette");
      Files.Model.Set_Path_Input_Text (Model, "/tmp/files_aunit/valid");
      Files.Model.Commit_Path_Input (Model, Valid, Empty);
      Assert (Files.Model.Path_Input_Is_Valid (Model), "valid input clears validation state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Error_Key (Model),
         "",
         "valid input clears validation error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/valid",
         "valid input changes path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "valid path input clears focus");
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
      --  Startup applies the persisted sort right after Initialize
      --  (Apply_Persisted_UI_State); the drawn order is the model's order.
      Files.Model.Apply_Sort (Model, Files.Model.Sort_Name, Ascending => True);

      Files_Suite.Support.Assert_Equal

        (Files.Model.Sort_Field_Of (Model),

         Files.Model.Sort_Name,

         "default runtime sort field is name");
      Assert (Files.Model.Sort_Is_Ascending (Model), "default runtime sort direction is ascending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "alpha.md", "default snapshot sorts by name ascending");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (4),
         "zulu",
         "default snapshot does not group directories before files");

      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Sort_Menu_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Sort_Menu_Command,
         "sort menu command is routed");
      Assert (Files.Model.Sort_Menu_Is_Open (Model), "sort menu opens");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Sort_By_Size_Command,
         "sort-by-size command is routed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Size,
         "sort-by-size selects size field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "new sort field starts ascending");
      Assert (not Files.Model.Sort_Menu_Is_Open (Model), "selecting a sort field closes the menu");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "charlie.bin", "size ascending sorts smallest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Size_Command, Model, Settings);
      Assert (not Files.Model.Sort_Is_Ascending (Model), "selecting same sort field toggles descending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "alpha.md", "size descending sorts largest file first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Type_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Type,
         "sort-by-type selects type field");
      Assert (Files.Model.Sort_Is_Ascending (Model), "different sort field resets to ascending");
      Files_Suite.Support.Assert_Equal (Snapshot_Name (1), "charlie.bin", "type ascending sorts by filetype token");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Created_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Created,
         "sort-by-created selects creation field");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (1),
         "charlie.bin",
         "created ascending sorts oldest creation time first");

      Result := Files.Controller.Execute_Command (Files.Commands.Sort_By_Changed_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Changed,
         "sort-by-changed selects modified field");
      Files_Suite.Support.Assert_Equal
        (Snapshot_Name (1),
         "alpha.md",
         "changed ascending sorts oldest modified time first");
   end Test_Runtime_Sort_State;

   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Roots_A  : Files.Types.String_Vectors.Vector;
      Roots_B  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Root_Status : Files.File_System.Root_Discovery_Diagnostics;

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

   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Roots_A := Files.File_System.Available_Roots;
      Roots_B := Files.File_System.Available_Roots;
      Entries := Files.File_System.Available_Root_Entries;
      Root_Status := Files.File_System.Root_Discovery_Status;
      Assert (not Roots_A.Is_Empty, "available roots is never empty");
      Files_Suite.Support.Assert_Equal
        (Natural (Entries.Length),
         Natural (Roots_A.Length),
         "root metadata count matches root paths");
      Files_Suite.Support.Assert_Equal
        (Root_Status.Root_Count,
         Natural (Entries.Length),
         "root diagnostics count discovered roots");
      Files_Suite.Support.Assert_Equal
        (Root_Status.Ready_Count,
         Natural (Entries.Length),
         "root diagnostics count ready roots");
      Assert
        (Files_Suite.Repository.Source_Contains ("function Is_Mount_Container")
         and then Files_Suite.Repository.Source_Contains ("return not Is_Mount_Container"),
         "root discovery excludes mount container rows");
      Files_Suite.Support.Assert_Equal
        (Natural (Roots_A.Length),
         Natural (Roots_B.Length),
         "available roots count is deterministic");
      for Index in 1 .. Natural (Roots_A.Length) loop
         declare
            Detail : constant Files.File_System.Root_Volume_Details :=
              Files.File_System.Root_Volume_Details_For (Entries.Element (Index));
         begin
            Files_Suite.Support.Assert_Equal
              (To_String (Detail.Path),
               To_String (Entries.Element (Index).Path),
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
            Files_Suite.Support.Assert_Equal
              (Detail.Capacity_Known,
               Detail.Free_Known,
               "root volume size flags are consistent");
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
         Files_Suite.Support.Assert_Equal
           (To_String (Entries.Element (Index).Path),
            To_String (Roots_A.Element (Index)),
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
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|tmpfs"),
               0,
               "root selector excludes tmpfs mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|proc"),
               0,
               "root selector excludes proc mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|sysfs"),
               0,
               "root selector excludes sysfs mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|squashfs"),
               0,
               "root selector excludes snap package mounts from proc metadata");
         end if;
         Assert (Ada.Directories.Exists (To_String (Roots_A.Element (Index))), "available root path exists");
         Assert
           (Ada.Directories.Kind (To_String (Roots_A.Element (Index))) = Ada.Directories.Directory,
            "available root path is a directory");
         Files_Suite.Support.Assert_Equal
           (To_String (Roots_A.Element (Index)),
            To_String (Roots_B.Element (Index)),
            "available roots preserve deterministic order");
         for Other in Index + 1 .. Natural (Roots_A.Length) loop
            Assert
              (To_String (Roots_A.Element (Index)) /= To_String (Roots_A.Element (Other)),
               "available roots do not contain duplicates");
         end loop;
      end loop;
   end Test_Root_Discovery;

   procedure Test_Root_Volume_Capabilities_And_Platform_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
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
   begin
      Assert
        (not Volume_Caps.Labels_From_Platform_Api,
         "root volume capabilities do not claim platform labels yet");
      Assert (Volume_Caps.Readiness_From_Platform_Api, "root volume capabilities expose readiness checks");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Capacity_From_Platform_Api,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume capacity capability matches capacity-byte availability");
      Assert
        (Volume_Caps.Native_Binding_Status = Files.File_System.Native_API_Binding_Available,
         "current target exposes native volume binding status");
      Files_Suite.Support.Assert_Equal
        (To_String (Volume_Caps.Binding_Unit),
         "Files.File_System",
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
      --  Exactly one adapter is the current target, and which one depends on the
      --  host. This block used to assert it was always Linux, which is why every
      --  one of these failed the moment the suite first ran on a Mac.
      Files_Suite.Support.Assert_Equal
        (Linux_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Linux),
         "the Linux profile marks itself the current target exactly on Linux");
      Files_Suite.Support.Assert_Equal
        (Windows_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Windows),
         "the Windows profile marks itself the current target exactly on Windows");
      Files_Suite.Support.Assert_Equal
        (Macos_Profile.Current_Target,
         (Current_Profile.Adapter = Files.File_System.Native_Adapter_Macos),
         "the macOS profile marks itself the current target exactly on macOS");
      Assert (Current_Profile.Current_Target, "the current profile is the current target");
      Assert
        (Linux_Profile.Volume_Binding_Status = Volume_Caps.Native_Binding_Status,
         "Linux native profile follows volume capability binding status");
      Files_Suite.Support.Assert_Equal
        (To_String (Linux_Profile.Volume_Binding_Unit),
         "Files.File_System.Root_Volume_Details_For",
         "Linux native profile records volume binding unit");
      declare
         Host_Profile : constant Files.File_System.Native_Platform_API_Profile :=
           Files.File_System.Native_Platform_API_Profile_For (Current_Profile.Adapter);
      begin
         Assert
           (Current_Profile.Volume_Binding_Status = Host_Profile.Volume_Binding_Status,
            "platform current API profile follows host volume status");
         Files_Suite.Support.Assert_Equal
           (To_String (Current_Profile.Volume_Binding_Unit),
            To_String (Host_Profile.Volume_Binding_Unit),
            "platform current API profile exposes host binding unit");
      end;
      Assert
        (Current_Profile.Adapter = Files.File_System.Native_Adapter_Windows
         or else Windows_Profile.Trash_Binding_Status = Files.File_System.Native_API_Not_Target,
         "Windows native profile is not active off Windows");
      Files_Suite.Support.Assert_Equal
        (To_String (Windows_Profile.Trash_Binding_Unit),
         "Hostkit.Trash",
         "Windows native profile records the unit that owns the trash binding");
      Files_Suite.Support.Assert_Equal
        (To_String (Windows_Profile.Volume_API_Name),
         "GetVolumeInformationW+GetDiskFreeSpaceExW",
         "Windows native profile records volume APIs");
      Assert
        (Current_Profile.Adapter = Files.File_System.Native_Adapter_Macos
         or else Macos_Profile.Volume_Binding_Status = Files.File_System.Native_API_Not_Target,
         "macOS native profile is not active off macOS");
      Files_Suite.Support.Assert_Equal
        (To_String (Macos_Profile.Required_Framework),
         "Foundation",
         "macOS native profile names the framework its trash binding actually needs");
      --  The project file no longer selects per-OS bodies -- there are none left
      --  to select. files_suite-startup asserts the single source list.
      --  The Windows and macOS trash bindings, and the C imports behind them --
      --  SHFileOperationW, the UTF-16 path it needs, NSFileManager's trash --
      --  moved to Hostkit.Trash, and hostkit's release checker asserts each body
      --  still binds its host's call (check_hostkit's Require_Binding). It did
      --  not when these assertions were first removed from here, which is worth
      --  remembering: "the other crate checks it" is a claim to verify, not to
      --  make. What stays checkable here is that files reports which unit owns
      --  the binding, above.
      --  (The two volume imports named here were never called: the volumes bodies
      --  declared them and then pragma Unreferenced'd them. The volume query has
      --  always been the metadata one, which is Hostkit.Metadata now.)
      Assert
        (To_String (Volume_Caps.Native_Api_Name) = "none"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts"
         or else To_String (Volume_Caps.Native_Api_Name) = "statvfs+proc.mounts+sysfs"
         or else To_String (Volume_Caps.Native_Api_Name) = "sysfs",
         "root volume capabilities name adapter");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Source_Device_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume source-device availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Mount_Options_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume mount-options availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Network_Metadata_Available,
         Volume_Caps.Filesystem_Type_Available,
         "root volume network metadata availability follows mount metadata availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Free_Bytes_Known,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume free-byte availability follows capacity availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Inode_Count_Known,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume inode availability follows statvfs availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Read_Only_Available,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume read-only availability follows statvfs availability");
      Files_Suite.Support.Assert_Equal
        (Volume_Caps.Name_Max_Available,
         Volume_Caps.Capacity_Bytes_Known,
         "root volume name-limit availability follows statvfs availability");
      Assert (not Volume_Caps.Eject_Available, "root volume capabilities do not claim eject support");
   end Test_Root_Volume_Capabilities_And_Platform_Profiles;

   procedure Test_Root_Discovery_Environment_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Had_Home       : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_User_Profile : constant Boolean := Ada.Environment_Variables.Exists ("USERPROFILE");
      Had_Home_Drive : constant Boolean := Ada.Environment_Variables.Exists ("HOMEDRIVE");
      Had_Home_Path  : constant Boolean := Ada.Environment_Variables.Exists ("HOMEPATH");
      Old_Home       : Unbounded_String;
      Old_User_Profile : Unbounded_String;
      Old_Home_Drive : Unbounded_String;
      Old_Home_Path  : Unbounded_String;

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

      Reset_Root;
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
         Files_Suite.Support.Assert_Equal
           (Shared_Profile_Count,
            1,
            "available roots collapse duplicate HOME and USERPROFILE directories");
         Restore_Root_Environment;
      exception
         when others =>
            Restore_Root_Environment;
            raise;
      end;
   end Test_Root_Discovery_Environment_Profiles;

   procedure Test_Root_Selector_Open_And_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "drive selector command is routed");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector opens root selector");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "root selector opening closes settings pane");
      Assert (Files.Model.Root_Count (Model) >= 1, "root selector contains at least one root");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "root selector selects the first root by default");
      Assert (Files.Model.Root_Path (Model, 1) /= "", "root selector exposes a root path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Path (Model, 99),
         "",
         "invalid root selector index returns empty path");

      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Root_Selector_Open, "snapshot captures root selector visibility");
      Assert (not Snapshot.Settings_Pane_Open, "snapshot exposes root selector as exclusive settings modal");
      Files_Suite.Support.Assert_Equal
        (Snapshot.Root_Selected_Index,
         1,
         "snapshot captures selected root selector row");
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Root_Paths.Length),
         Files.Model.Root_Count (Model),
         "snapshot captures root selector paths");
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Root_Labels.Length),
         Files.Model.Root_Count (Model),
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
   end Test_Root_Selector_Open_And_Snapshot;

   procedure Test_Root_Volume_Details_By_Mount_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
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
         Files_Suite.Support.Assert_Equal
           (To_String (Bad_Detail.Native_Api_Name),
            "none",
            "malformed root volume detail skips platform adapter");
         Assert
           (not Bad_Detail.Uses_Platform_Detail,
            "malformed root volume detail has no platform metadata");
      end;
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
         Files_Suite.Support.Assert_Equal
           (To_String (Network_Detail.Remote_Protocol),
            "smb",
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
         Files_Suite.Support.Assert_Equal
           (To_String (Local_Detail.Remote_Protocol),
            "",
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
   end Test_Root_Volume_Details_By_Mount_Kind;

   procedure Test_Root_Selector_Eject_And_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
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
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Eject_Selected_Root_Command,
         "eject command reports command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "eject command reports unavailable native operation");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.root.eject_unavailable",
         "eject command reports localized unavailable error");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         "/tmp/example-mount",
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
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "root-open command reports root activation command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root-open command navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "root-open loads selected root");
   end Test_Root_Selector_Eject_And_Open;

   procedure Test_Root_Selector_Settings_Exclusivity_And_Close (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Roots_A := Files.File_System.Available_Roots;
      --  Open the selected root and come back to Root, so the selector starts
      --  closed over a navigated window.
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String (Target),
            Label => To_Unbounded_String ("root.mount|selected-root"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("selected-root"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      Files.Model.Open_Root_Selector (Model, Entries);
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Selected_Root_Command, Model, Settings);
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
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "second drive selector click is routed");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "second drive selector click closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "second drive selector click does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after toggle close");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes root selector close");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "root selector Escape reports successful state-only close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "Escape closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "Escape clears closed root selector entries");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "root selector Escape does not navigate");

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Close_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "close command routes root selector close");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "close command closes root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "close command clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after close command");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks path focus command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked path focus keeps root selector open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked path focus leaves focus clear");
      Files.Model.Close_Root_Selector (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct close clears closed root selector entries");
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector reopens after blocked path focus");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "palette command is routed");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens from toolbar state");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette opening preserves root selector");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "same palette search cursor click is ignored");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "drive selector clears palette focus");
      Files.Model.Close_Root_Selector (Model);
   end Test_Root_Selector_Settings_Exclusivity_And_Close;

   procedure Test_Root_Selection_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      --  An empty listing at Root with every overlay closed.
      Files.Model.Navigate_To (Model, Root, Files.File_System.Item_Vectors.Empty_Vector);

      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Assert (Files.Model.Root_Selector_Is_Open (Model), "drive selector can reopen after palette Escape");
      Files.Model.Begin_Create_File (Model, "root-pending.txt");
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);

      Result := Files.Controller.Select_Root (Model, Settings, Join (Root, "missing-root"));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "invalid root selection executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "invalid root selection reports drive command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "invalid root selection fails as data");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.path.missing",
         "invalid root selection reports path diagnostic");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "invalid root selection does not navigate");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "invalid root selection keeps selector open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "invalid root selection records error");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid root selection preserves temporary create state");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid root selection preserves rename state");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "outside root row click is ignored");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "outside root row click keeps selector open");

      Result := Files.Controller.Select_Root (Model, Settings, Target);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "root selection executes command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "root selection reports drive command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root selection navigates");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         Ada.Directories.Full_Name (Target),
         "root selection operation carries normalized path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "selected root is loaded");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "root selection clears stale error state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "root selection clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "root selection clears rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Item_Count (Model), 1, "selected root directory items are loaded");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "root selection closes selector");
      Assert (Files.Model.Can_Go_Back (Model), "root selection updates back history");
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "closed root selector row click is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "closed root selector row click does not navigate");
   end Test_Root_Selection_Navigation;

   procedure Test_Root_Selector_Keyboard_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.Types.String_Vectors.Empty_Vector);
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "empty root selector stays closed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         0,
         "empty root selector has no selected row");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "empty root selector does not create an invisible modal command blocker");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single root selector movement is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector Home at first row is ignored");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "single root selector End is ignored");
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "non-empty root selector selects first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Down moves root selector row");
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 2, "Down selects next root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 1, "Up selects previous root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         3,
         "Up wraps root selector to last row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 1, "Home selects first root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal (Files.Model.Root_Selected_Index (Model), 3, "End selects last root row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Right wraps root selector to first row");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         1,
         "Right from last root row wraps to first row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "Left wraps root selector to last row");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Selected_Index (Model),
         3,
         "Left from first root row wraps to last row");
   end Test_Root_Selector_Keyboard_Navigation;

   procedure Test_Root_Selector_Blocks_Background_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      --  A three-row selector opened over a focused path input.
      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Delete);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background delete key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "blocked root selector delete keeps selection");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked root selector delete keeps selector open");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Path_Input, Cursor_Position => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background text focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked text focus leaves focus clear");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks background wheel scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked root selector scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Auto,
           Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks targeted auto scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked root auto scroll leaves main view still");
      Result :=
        Files.Controller.Handle_Targeted_Scroll
          (Model,
           Files.Events.Scroll_Main_View,
           Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks targeted main scroll");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "root selector allows palette shortcut");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "palette opens over root selector from shortcut");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "palette shortcut keeps root selector available");
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Snapshot.Command_Palette_Open, "snapshot exposes the active palette overlay");
      Assert
        (not Snapshot.Root_Selector_Open,
         "snapshot suppresses root selector drawing while the palette is above it");
      Result := Files.Controller.Handle_Text_Click (Model, Files.Types.Focus_Command_Palette, Cursor_Position => 0);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "same palette search cursor click is ignored over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct path focus command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "blocked direct path focus leaves focus clear");
      Files.Model.Set_Error (Model, "error.path.missing");
      Result := Files.Controller.Execute_Command (Files.Commands.Delete_Selected_Items_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct delete command");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 1, "blocked direct delete keeps selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "modal command block does not replace existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Toggle_Settings_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "root selector blocks direct settings command");
      Assert (Files.Model.Root_Selector_Is_Open (Model), "blocked direct settings keeps root selector open");
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "blocked direct settings leaves settings pane closed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.path.missing",
         "root selector settings block preserves existing error");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Command_Palette_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Command_Palette_Command,
         "root selector allows direct palette command");
      Assert (Files.Model.Command_Palette_Is_Open (Model), "direct palette command opens over root selector");
      Files.Model.Close_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Select_Drive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Drive_Command,
         "root selector allows drive toggle command");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "drive toggle closes root selector");
   end Test_Root_Selector_Blocks_Background_Input;

   procedure Test_Root_Selector_Row_Activation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Roots_A  : Files.Types.String_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Roots_A.Append (To_Unbounded_String (Root));
      Roots_A.Append (To_Unbounded_String (Target));
      Roots_A.Append (To_Unbounded_String (Ada.Directories.Full_Name (Root)));
      --  Row 2 is Target.
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Set_Root_Selected_Index (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "Return activates selected root row");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "Return root activation navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "Return loads selected root");

      Files.Model.Initialize (Model, Root, Sample_Items, Root);
      Roots_A.Clear;
      Roots_A.Append (To_Unbounded_String (Target));
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Files.Model.Focus_Path_Input (Model);
      Files.Controller.Replace_Focused_Text (Model, "/tmp/root-click-edit");
      Files.Model.Open_Root_Selector (Model, Roots_A);
      Result := Files.Controller.Handle_Root_Click (Model, Settings, Root_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "root row click reports root activation command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root row click navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "root row click loads root");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "root row click clears path input focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         Ada.Directories.Full_Name (Target),
         "root row click replaces edited path text");
   end Test_Root_Selector_Row_Activation;

   procedure Test_Bounded_Host_Text_Records
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "bounded-host-lines");
      File     : Ada.Text_IO.File_Type;
      Line     : Unbounded_String;
      Complete : Boolean;
   begin
      Reset_Root;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "123456789");
      Ada.Text_IO.Put_Line (File, "12345678");
      Ada.Text_IO.Put (File, "tail");
      Ada.Text_IO.Close (File);

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (not Complete and then Length (Line) = 0,
         "an oversized physical line is rejected without returning a prefix");

      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (Complete and then To_String (Line) = "12345678",
         "a line exactly at the bound is accepted after the oversized record");

      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (Complete and then To_String (Line) = "tail",
         "an unterminated final line below the bound is accepted");
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Test_Bounded_Host_Text_Records;

   procedure Test_Info_Pane_Toggle_And_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;

      --  The info pane can always be toggled, even with nothing selected.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "Control+4 routes info-pane command with no selection");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "Control+4 toggles the info pane with no selection");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane opens without a selection");
      --  Close it again, then reopen with a selection so the rest of the
      --  scenario starts from an open, selection-backed info pane.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second Control+4 closes the info pane");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "Control+4 routes info-pane command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info pane toggles open");
      Files_Suite.Support.Assert_Equal (Files.Model.Info_Pane_Scroll_Lines (Model), 0, "info pane opens unscrolled");

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Set_Info_Pane_Scroll_Lines (Model, 0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "holding an unmoved info-pane scrollbar does not revise the model");
      end;

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "PageUp at top of info pane is ignored");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "ignored info-pane PageUp leaves the model revision unchanged");
      end;

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, -1);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "negative info scroll at top is ignored");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "PageDown pages info pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         10,
         "PageDown scrolls info pane by page");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'Last);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large info scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         Natural'Last,
         "large info scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, Integer'First);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large negative info scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "large negative info scroll clamps to top");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         10,
         "info pane scroll resumes after saturation");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "PageUp pages info pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "PageUp scrolls info pane back to top");
   end Test_Info_Pane_Toggle_And_Scroll;

   procedure Test_Info_Pane_Scroll_Resets_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      --  Start from an open, selection-backed, unscrolled info pane.
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);

      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         3,
         "info pane can scroll before selection changes");
      Files.Model.Select_Visible (Model, 2);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "single selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Toggle_Visible_Selection (Model, 1);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "toggle selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Select_Visible_Range (Model, 1, 3);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "range selection resets info pane scroll");
      Files.Model.Scroll_Info_Pane (Model, Lines => 3);
      Files.Model.Clear_Selection (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "clear selection resets info pane scroll");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over info pane");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "wheel scrolls the open settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "settings wheel scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "auto scroll reaches the settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "settings auto scroll leaves info pane still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Info_Pane, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks targeted info scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "blocked targeted scroll leaves info pane still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks background PageDown");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model),
         0,
         "blocked PageDown leaves info pane still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes after scroll block checks");
   end Test_Info_Pane_Scroll_Resets_And_Settings_Block;

   procedure Test_View_Mode_And_Bottom_Bar_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      --  Start from an open info pane with nothing selected.
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_4, Ctrl);
      Files.Model.Clear_Selection (Model);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_2, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Large_Icons_Command,
         "Control+2 routes large-icons command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Large_Icons,
         "large mode shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_3, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Details_Command,
         "Control+3 routes details command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details shortcut works");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_1, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Small_Icons_Command,
         "Control+1 routes small-icons command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Small_Icons,
         "small mode shortcut works");

      --  The info pane can always be toggled, even with no selection: the click
      --  now closes the currently open pane rather than being ignored.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "info-pane click routes command with no selection");
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "info-pane click closes the pane with no selection");
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Toggle_Info_Pane_Command,
         "enabled info-pane click routes command");
      Assert (Files.Model.Info_Pane_Is_Open (Model), "info-pane click toggles open");
      --  Restore the closed state expected by the following command click
      --  checks.
      Result := Files.Controller.Handle_Command_Click (Files.Commands.Toggle_Info_Pane_Command, Model, Settings);
      Assert (not Files.Model.Info_Pane_Is_Open (Model), "a second info-pane click closes the pane again");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.Select_Details_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Select_Details_Command,
         "details click routes command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "details click changes view mode");

      Result := Files.Controller.Handle_Command_Click (Files.Commands.No_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "empty command click is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.No_Command,
         "empty command click reports no command");
   end Test_View_Mode_And_Bottom_Bar_Clicks;

   procedure Test_Grid_Page_Keys_Page_The_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      --  Over the file grid (info pane closed) plain Page Up / Page Down now
      --  page the SELECTION rather than scrolling the main view. The main view
      --  still scrolls through the wheel / targeted-scroll seam, which
      --  Test_Main_View_Scroll_And_Settings_Block covers.
      Files.Model.Select_Visible (Model, 1);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "grid PageUp on the first item is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "grid PageUp keeps the first item selected");

      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Result := Files.Controller.Handle_Scroll (Model, Lines => -1);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Controller.Controller_Ignored,
            "negative main scroll at top is ignored");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "ignored main-view scrolling leaves the model revision unchanged");
      end;

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "grid PageDown pages the selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         Files.Model.Visible_Count (Model),
         "grid PageDown moves the selection a full page down to the last item");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "grid PageDown on the last item is ignored");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         Files.Model.Visible_Count (Model),
         "grid PageDown keeps the last item selected");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Up);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "grid PageUp pages the selection back");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "grid PageUp returns the selection to the first item");
   end Test_Grid_Page_Keys_Page_The_Selection;

   procedure Test_Main_View_Scroll_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Model.Select_Visible (Model, 1);

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'Last);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large main scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         Natural'Last,
         "large main scroll saturates");

      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, Integer'First);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "large negative main scroll is handled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "large negative main scroll clamps to top");
      declare
         Before : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Model.Set_Main_View_Scroll_Lines (Model, 0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Revision (Model),
            Before,
            "holding an unmoved main scrollbar does not revise the model");
      end;
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "settings pane opens over main view");
      Result := Files.Controller.Handle_Scroll (Model, Lines => 3);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "wheel scrolls the open settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "settings wheel scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Auto, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Command_Executed,
         "auto scroll reaches the settings pane");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "settings auto scroll leaves main view still");
      Result := Files.Controller.Handle_Targeted_Scroll (Model, Files.Events.Scroll_Main_View, 10);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks targeted main scroll");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked targeted scroll leaves main view still");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Page_Down);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "settings pane blocks main PageDown");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "blocked PageDown leaves main view still");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Toggle_Settings_Pane_Command,
           Model,
           Settings);
      Assert (not Files.Model.Settings_Pane_Is_Open (Model), "settings pane closes before command click checks");
   end Test_Main_View_Scroll_And_Settings_Block;

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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct rename clears stale root selector entries");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Field_Count (Model),
         2,
         "multi-selection rename opens one field per item");
      Files.Model.Toggle_Rename (Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "toggling rename again cancels multi rename");
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (Files.Model.Rename_Is_Active (Model), "rename command enters rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Text (Model),
         "Beta.txt",
         "rename text is selected file name");
      Files.Model.Select_Visible (Model, 1);
      Assert (not Files.Model.Rename_Is_Active (Model), "selection change cancels stale rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "selection change clears stale rename focus");

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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "Alpha.txt",
         "filter reconciliation selects visible item");
      Files.Model.Clear_Filter (Model);
      Files.Model.Select_Visible (Model, 2);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Files.Commands.Execute (Files.Commands.Rename_Selected_Items_Command, Model);
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 while renaming cancels rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes rename through controller");
      Assert (Files.Model.Rename_Is_Active (Model), "controller F2 enters rename mode");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "rename Escape reports successful state-only cancel");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels focused rename mode");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered again");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "path focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Escape clears focused path input");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape cancels rename state after path focus");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename_Is_Active (Model), "rename can be entered after path focus Escape");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Filter_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Filter_Input,
         "focus can move away from rename");
      Assert (Files.Model.Rename_Is_Active (Model), "moving focus does not implicitly cancel rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "first Escape clears focused filter input");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Field_Count (Model),
         2,
         "multi-rename opens one field per selected item");

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
      Files_Suite.Support.Assert_Equal (RCursor (1), 0, "a click moves the clicked field's caret");
      Files_Suite.Support.Assert_Equal (RCursor (2), 4, "a click leaves the other field's caret untouched");

      --  A keyboard arrow moves every caret together.
      Changed := Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right);
      Assert (Changed, "arrow reports a change across the fields");
      Assert (RCursor (1) = 1 and then RCursor (2) = 5, "a keyboard arrow moves every caret together");
   end Test_Multi_Rename_Broadcast;

   procedure Test_Create_File_Command_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 2.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Open_Root_Selector (Model, Files.File_System.Available_Roots);
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Begin_Create_File (Model, "draft.txt");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "direct create adds temporary item");
      Assert (not Files.Model.Root_Selector_Is_Open (Model), "direct create closes stale root selector");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Root_Count (Model),
         0,
         "direct create clears stale root selector entries");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "direct create closes stale command palette");
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      Files.Model.Set_Error (Model, "error.path.missing");
      Files.Model.Scroll_Main_View (Model, 4);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Create_File_Command,
         "create command routes through controller");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "create command reports successful temporary-item operation");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "",
         "create command clears stale error state");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "create command adds temporary item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 3.txt",
         "temporary item name is deterministic");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "create command scrolls temporary item into view");
      Assert (Files.Model.Rename_Is_Active (Model), "create command starts rename mode");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Rename_Input,
         "create command focuses rename input");
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Create_File_Command, Model),
         "create command is disabled while a temporary item exists");
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "second create command is ignored");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Disabled,
         "second create command reports disabled operation");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.create.pending",
         "second create command reports pending-create error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.create.pending",
         "second create records error");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 3.txt",
         "ignored create keeps pending name");
   end Test_Create_File_Command_State;

   procedure Test_Create_File_Temporary_Item_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
      Operation : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 2.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      --  Open a gap in the untitled names before creating.
      Ada.Directories.Delete_File (Join (Root, "untitled 2.txt"));
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 2.txt",
         "create command uses first name gap");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         1,
         "temporary item appears despite active filter");
      Files_Suite.Support.Assert_Equal
        (To_String (Files.Model.Visible_Item (Model, 1).Name),
         "untitled 2.txt",
         "temporary item is the visible item while pending");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "create command selects temporary item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         1,
         "temporary item counts as a selected visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "untitled 2.txt",
         "temporary selection exposes pending name");
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
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be opened directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "temporary open records disabled state");
      Operation := Files.Operations.Delete_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be deleted directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "temporary delete records disabled state");
      Operation := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "temporary item cannot be renamed directly");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "temporary rename records disabled state");
   end Test_Create_File_Temporary_Item_Guards;

   procedure Test_Create_File_Mixed_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Mixed_Model : Files.Model.Window_Model := Sample_Model;
      Mixed_Items : Files.File_System.Item_Vectors.Vector;
      Operation : Files.Operations.Operation_Result;
   begin
      Files.Model.Begin_Create_File (Mixed_Model, "pending.txt");
      Files.Model.Select_Visible_Range
        (Mixed_Model,
         Anchor_Index => Positive (Files.Model.Visible_Count (Mixed_Model)),
         Target_Index => 1);
      Mixed_Items := Files.Model.Selected_Items (Mixed_Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Mixed_Model),
         4,
         "mixed selection includes real items and temporary item");
      Files_Suite.Support.Assert_Equal
        (Natural (Mixed_Items.Length),
         3,
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
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "mixed temporary selection cannot open");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Mixed_Model),
         "error.selection.empty",
         "mixed temporary open records disabled state");
      Operation := Files.Operations.Delete_Selected (Mixed_Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Operation.Status,
         Files.Operations.Operation_Disabled,
         "mixed temporary selection cannot delete");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Mixed_Model),
         "error.selection.empty",
         "mixed temporary delete records disabled state");
   end Test_Create_File_Mixed_Selection;

   procedure Test_Create_File_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Write_File (Join (Root, "untitled.txt"));
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_Filter (Model, "does-not-match-untitled");
      --  A pending "untitled 2.txt" create in a filtered, empty listing.
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Rename_Selected_Items_Command,
         "F2 routes temporary rename cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "F2 cancels pending temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "F2 clears temporary rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "F2 clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "F2 removes temporary item from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 2.txt")), "F2 does not create a file");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Create_File_Command,
         "Control+N routes create-file command");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N adds temporary item");
      Files.Model.Cancel_Create_File (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "direct create cancel clears rename focus");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N can add temporary item after direct cancel");
      Result := Files.Controller.Execute_Command (Files.Commands.Focus_Path_Input_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_Path_Input,
         "path focus can move away from create");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "Escape clears path focus during create");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item after path focus");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears create rename after path focus");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "path-focus Escape removes temporary item from projection");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Close_Command_Palette_Command,
         "Escape routes context cancel");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "create Escape reports successful state-only cancel");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "Escape cancels temporary item");
      Assert (not Files.Model.Rename_Is_Active (Model), "Escape clears temporary rename state");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "Escape clears temporary selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "cancelled temporary item disappears from projection");
      Assert (not Ada.Directories.Exists (Join (Root, "untitled 3.txt")), "Escape does not create a file");

      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 1);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Success,
         "temporary-row item click reports successful context cancel");
      Assert
        (not Files.Model.Temporary_Item_Is_Active (Model),
         "temporary-row item click cancels pending create");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "temporary-row item click does not leave a zero selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         0,
         "temporary-row item click removes the only visible row");
   end Test_Create_File_Cancellation;

   procedure Test_Untitled_Name_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
      Dangling_Untitled : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "untitled.txt"));
      Write_File (Join (Root, "untitled 3.txt"));
      Write_File (Join (Root, "name-parent.txt"));
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Next_Untitled_Name (Join (Root, "name-parent.txt")),
         "untitled.txt",
         "untitled name generation falls back deterministically for non-directory probes");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Next_Untitled_Name (Root),
         "untitled 2.txt",
         "untitled name generation skips directory collisions");
      Dangling_Untitled := Create_Symlink ("missing-target", Join (Root, "untitled 2.txt"));
      if Dangling_Untitled then
         Files_Suite.Support.Assert_Equal
           (Files.File_System.Next_Untitled_Name (Root),
            "untitled 4.txt",
            "untitled name generation skips dangling-link collisions");
      end if;
      Files.Model.Initialize (Model, Root, Items, Root);
      Result := Files.Controller.Execute_Command (Files.Commands.Create_File_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         (if Dangling_Untitled then "untitled 4.txt" else "untitled 2.txt"),
         "create uses the first suffix without an existing directory entry");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Temporary_Item_Name (Model),
         "untitled 11.txt",
         "create uses explicit spaced suffix text after single digits");
   end Test_Untitled_Name_Generation;

   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Operations.Operation_Result;
      Item     : Files.File_System.Directory_Item;
   begin
      Item := Files.Model.Selected_Item (Model);
      Files_Suite.Support.Assert_Equal (To_String (Item.Name), "", "empty selection returns an empty selected item");
      Files_Suite.Support.Assert_Equal (To_String (Item.Full_Path), "", "empty selection selected item has empty path");
      Assert (Item.Kind = Files.Types.Unknown_Item, "empty selection selected item has unknown kind");
      Assert (not Files.Model.Selected_Item_Is_Temporary (Model), "empty selection is not temporary");

      Result := Files.Operations.Open_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "empty open is represented as disabled");
      Files_Suite.Support.Assert_Equal (To_String (Result.Path), "", "disabled empty open has no target path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.selection.empty",
         "empty open records an error");
      Result := Files.Operations.Navigate_Back (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "empty back history is disabled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.history.back_unavailable",
         "empty back history records an error");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "create commit without temporary item is disabled");
      Files_Suite.Support.Assert_Equal (To_String (Result.Path), "", "disabled create commit has no target path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.create.no_temporary_item",
         "missing temporary item records an error");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Disabled,
         "rename commit outside rename mode is disabled");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.rename.disabled",
         "disabled rename records an error");

      Files.Model.Select_Visible (Model, 1);
      Result := Files.Operations.Delete_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "trash failure is represented as data");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Path),
         Join (Root, "Alpha.txt"),
         "trash failure reports selected path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.trash.failed",
         "trash failure is recorded as data; key was "
         & Files.Model.Last_Error_Key (Model));
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
         Files_Suite.Support.Assert_Equal (Natural (Content.Text_Lines.Length), 3, "all three short lines are carried");
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Text_Lines.First_Element),
            "alpha",
            "the first line is preserved");
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
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Image_Path),
            "/tmp/photo.png",
            "image content carries the source path");
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
         Files_Suite.Support.Assert_Equal (To_String (Content.Name), "Documents", "info content carries the item name");
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Filetype),
            "inode/directory",
            "info content carries the item type");
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
      Files_Suite.Support.Assert_Equal
        (Files.Model.Quick_Look_Path (Model),
         To_String (Files.Model.Selected_Item (Model).Full_Path),
         "quick look records the previewed item path");
      Assert
        (Files.Model.Quick_Look_Content_Of (Model).Kind = Files.Quick_Look.Info_Content,
         "the pure toggle prepares metadata-only info content");

      declare
         Content  : constant Files.Quick_Look.Quick_Look_Content :=
           (Kind         => Files.Quick_Look.Image_Content,
            Image_Width  => Natural'Last,
            Image_Height => Natural'Last,
            others       => <>);
         Snapshot : Files.Rendering.View_Snapshot;
      begin
         Files.Model.Open_Quick_Look (Model, Content);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (Snapshot.Quick_Look_Image_Width = 0
              and then Snapshot.Quick_Look_Image_Height = 0,
            "impossible quick-look dimensions are rejected without arithmetic overflow");
      end;

      Files.Model.Toggle_Quick_Look (Model);
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "toggling again closes quick look");

      --  Reopen, then a selection change closes the now-stale preview.
      Files.Model.Toggle_Quick_Look (Model);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "quick look reopens for the current selection");
      Files_Suite.Support.Select_Name (Model, "Beta.txt");
      Assert (not Files.Model.Quick_Look_Is_Open (Model), "changing the selection closes quick look");
   end Test_Quick_Look_Model_State;

   procedure Test_Grouping_Band_Edges (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Today : constant Ada.Calendar.Time := Files.Grouping.Day_Start (Ada.Calendar.Clock);
      Day   : constant Duration := 86_400.0;

      function Typed (Kind : Files.Types.Item_Kind; Filetype : String) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Type, Kind, Filetype, False, Today, False, 0, Files.Types.No_Label, Today));

      function Dated (Known : Boolean; At_Time : Ada.Calendar.Time) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Modified, Files.Types.Regular_File_Item, "", Known, At_Time, False, 0,
            Files.Types.No_Label, Today));

      function Sized (Known : Boolean; Size : Long_Long_Integer) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Size, Files.Types.Regular_File_Item, "", False, Today, Known, Size,
            Files.Types.No_Label, Today));

      Mib : constant Long_Long_Integer := 1024 * 1024;
   begin
      Files_Suite.Support.Assert_Equal (Typed (Files.Types.Directory_Item, ""), 1, "folders come first");
      Files_Suite.Support.Assert_Equal
        (Typed (Files.Types.Regular_File_Item, "IMAGE/PNG"),
         2,
         "image types, in any case");
      Assert (Typed (Files.Types.Regular_File_Item, "audio/flac") = 3
              and then Typed (Files.Types.Regular_File_Item, "video/mp4") = 4, "audio, then video");
      Assert (Typed (Files.Types.Regular_File_Item, "text/plain") = 5
              and then Typed (Files.Types.Regular_File_Item, "application/pdf") = 5
              and then Typed (Files.Types.Regular_File_Item, "application/vnd.oasis.opendocument.text") = 5,
              "documents");
      Assert (Typed (Files.Types.Regular_File_Item, "application/zip") = 6
              and then Typed (Files.Types.Regular_File_Item, "application/x-7z-compressed") = 6, "archives");
      Assert (Typed (Files.Types.Regular_File_Item, "application/octet-stream") = 7
              and then Typed (Files.Types.Regular_File_Item, "") = 7, "everything else last");

      Assert (Dated (True, Today) = 1 and then Dated (True, Ada.Calendar.Clock) = 1, "today, from midnight on");
      Files_Suite.Support.Assert_Equal
        (Dated (True, Today + 3.0 * Day),
         1,
         "a time past now counts as today, not as earlier");
      Assert (Dated (True, Today - 1.0) = 2 and then Dated (True, Today - 6.0 * Day + 60.0) = 2,
              "the six days before today");
      Files_Suite.Support.Assert_Equal (Dated (True, Today - 7.0 * Day), 3, "older than that");
      Files_Suite.Support.Assert_Equal (Dated (False, Today), 4, "an unknown time last");

      Assert (Sized (True, 0) = 1 and then Sized (True, -5) = 1, "empty");
      Assert (Sized (True, 1) = 2 and then Sized (True, Mib - 1) = 2, "under a MiB");
      Assert (Sized (True, Mib) = 3 and then Sized (True, 1024 * Mib - 1) = 3, "under a GiB");
      Files_Suite.Support.Assert_Equal (Sized (True, 1024 * Mib), 4, "a GiB and up");
      Files_Suite.Support.Assert_Equal (Sized (False, 0), 5, "an unknown size last");
   end Test_Grouping_Band_Edges;

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
      --  The window loop does this before every frame.
      Files.Model.Sync_Grouping (Model, Settings);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Prev_Was_Header : Boolean := False;
         Position : Natural := 0;
         Last_Visible : Natural := 0;
      begin
         for Item of Snapshot.Items loop
            Position := Position + 1;
            if not Item.Is_Group_Header then
               --  Keyboard and range selection walk visible indexes in order;
               --  the drawn rows must follow the same order.
               Files_Suite.Support.Assert_Equal
                 (Item.Visible_Index,
                  Last_Visible + 1,
                  "grouped rows are drawn in the order the keyboard walks them");
               Last_Visible := Item.Visible_Index;
            end if;
            if Item.Is_Group_Header then
               Header_Count := Header_Count + 1;
               Files_Suite.Support.Assert_Equal (Item.Visible_Index, 0, "a label band header is non-selectable");
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
         Files_Suite.Support.Assert_Equal (Header_Count, 3, "three occupied label bands emit three headers");
         Assert (Header_Before_Alpha, "the first labeled item sits under a band header");
         --  Band order: Red (Alpha) before Blue (Gamma) before Unlabeled (Beta).
         Assert (Alpha_Pos > 0 and then Gamma_Pos > 0 and then Beta_Pos > 0,
                 "every real item is placed under a band");
         Assert (Alpha_Pos < Gamma_Pos, "the red band precedes the blue band");
         Assert (Gamma_Pos < Beta_Pos, "the blue band precedes the unlabeled band");
      end;

      --  Leaving the grouping restores the plain name order.
      Settings.Group_By := Files.Types.No_Grouping;
      Files.Model.Sync_Grouping (Model, Settings);
      declare
         Reference : Files.Model.Window_Model := Sample_Model;
      begin
         Files.Model.Set_View_Mode (Reference, Files.Types.Details);
         Files.Model.Apply_Sort
           (Reference, Files.Model.Sort_Field_Of (Model), Files.Model.Sort_Is_Ascending (Model));
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            Expected : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Reference, Settings);
         begin
            Files_Suite.Support.Assert_Equal
              (Snapshot.Items.Last_Index,
               Expected.Items.Last_Index,
               "ungrouping keeps every item");
            for Index in Snapshot.Items.First_Index .. Snapshot.Items.Last_Index loop
               Assert (not Snapshot.Items (Index).Is_Group_Header, "no band headers without grouping");
               Assert (Snapshot.Items (Index).Name = Expected.Items (Index).Name,
                       "ungrouping restores the plain sort order");
            end loop;
         end;
      end;
   end Test_Group_By_Label_Bands;

   --  Build_Snapshot looks favorites and labels up in a hashed index of the
   --  settings rather than scanning both lists per item. It must answer as
   --  Files.Settings.Is_Favorite and Label_Of do -- exact path equality, no
   --  case folding or separator trimming, and the first of repeated labels.
   procedure Test_Snapshot_Labels_And_Favorites_At_Scale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Count    : constant := 400;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Favorites : Natural := 0;
      Labelled  : Natural := 0;

      function Name_Of (Index : Positive) return String is
        ("item_" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left) & ".txt");

      function Color_For (Index : Positive) return Files.Types.Color_Label is
        (if Index mod 2 = 0 then Files.Types.Red else Files.Types.Blue);
   begin
      for Index in 1 .. Count loop
         Items.Append
           (Files.File_System.Make_Item (Root, Name_Of (Index), Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Directory_Path => Root, Items => Items, Home_Path => "/home/test");

      for Index in 1 .. Count loop
         if Index mod 3 = 0 then
            Files.Settings.Toggle_Favorite_Path (Settings, Join (Root, Name_Of (Index)));
         end if;
         if Index mod 5 = 0 then
            Files.Settings.Set_Label (Settings, Join (Root, Name_Of (Index)), Color_For (Index));
         end if;
      end loop;
      --  Paths that only resemble an item's: another case, a trailing
      --  separator. Neither names item 1 or 2 for the settings.
      Files.Settings.Toggle_Favorite_Path (Settings, Join (Root, "ITEM_1.TXT"));
      Files.Settings.Set_Label (Settings, Join (Root, Name_Of (2)) & "/", Files.Types.Green);
      --  A repeated entry, as a hand-edited settings file can hold: the first
      --  one is the label.
      Settings.Labels.Append
        (Files.Settings.Path_Label'
           (Path => To_Unbounded_String (Join (Root, Name_Of (5))), Label => Files.Types.Green));

      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal (Natural (Snapshot.Items.Length), Count, "every item is in the snapshot");
         for Item of Snapshot.Items loop
            declare
               Name : constant String := To_String (Item.Name);
               Path : constant String := Join (Root, Name);
            begin
               Files_Suite.Support.Assert_Equal
                 (Item.Is_Favorite,
                  Files.Settings.Is_Favorite (Settings, Path),
                  Name & " is a favorite exactly when the settings say so");
               Assert (Item.Label = Files.Settings.Label_Of (Settings, Path),
                       Name & " carries exactly the label the settings store for it");
               if Item.Is_Favorite then
                  Favorites := Favorites + 1;
               end if;
               if Item.Label /= Files.Types.No_Label then
                  Labelled := Labelled + 1;
               end if;
               if Name = Name_Of (1) then
                  Assert (not Item.Is_Favorite, "a favorite stored in another case does not mark the item");
               elsif Name = Name_Of (2) then
                  Assert (Item.Label = Files.Types.No_Label,
                          "a label stored with a trailing separator does not mark the item");
               elsif Name = Name_Of (5) then
                  Assert (Item.Label = Color_For (5), "the first of two stored labels for a path wins");
               end if;
            end;
         end loop;
         Files_Suite.Support.Assert_Equal (Favorites, Count / 3, "every stored favorite is marked, and no other item");
         Files_Suite.Support.Assert_Equal (Labelled, Count / 5, "every stored label is shown, and no other");
      end;
   end Test_Snapshot_Labels_And_Favorites_At_Scale;

   --  Owner and group names reach the info pane through the model: the window
   --  layer samples them (Files.Application.Sample_Account_Names) and
   --  Build_Snapshot only reads them, so building a snapshot makes no NSS
   --  lookup. Unsampled, the pane gets no name and falls back to the number.
   procedure Test_Snapshot_Owner_Names_From_Model (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Owned    : Files.File_System.Directory_Item :=
        Files.File_System.Make_Item (Root, "Owned.txt", Files.Types.Regular_File_Item, "text/plain");
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Revision : Natural;

      function Shown_Info return Files.Rendering.Info_Snapshot is
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Snapshot.Selected_Info.Length), 1, "the info pane lists the selected item");
         return Snapshot.Selected_Info.First_Element;
      end Shown_Info;
   begin
      Owned.Ownership_Available := True;
      Owned.Owner_Id := 0;
      Owned.Group_Id := 0;
      Items.Append (Owned);
      Files.Model.Initialize (Model, Directory_Path => Root, Items => Items, Home_Path => "/home/test");
      Select_Name (Model, "Owned.txt");
      if not Files.Model.Info_Pane_Is_Open (Model) then
         Files.Model.Toggle_Info_Pane (Model);
      end if;

      declare
         Info : constant Files.Rendering.Info_Snapshot := Shown_Info;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Owner_Name), "", "an unsampled owner has no name, so the pane shows the id");
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Group_Name), "", "an unsampled group has no name, so the pane shows the id");
         Files_Suite.Support.Assert_Equal (Info.Owner_Id, 0, "the pane still carries the owner id");
      end;
      Assert (not Files.Model.Account_Names_Current (Model), "nothing has been sampled yet");

      Files.Application.Sample_Account_Names (Model);
      Assert (Files.Model.Account_Names_Current (Model), "the sample covers the model as it is");
      declare
         Info : constant Files.Rendering.Info_Snapshot := Shown_Info;
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Owner_Name),
            Files.File_System.User_Name_For_Id (0),
            "the pane shows the owner name the window layer sampled");
         Files_Suite.Support.Assert_Equal
           (To_String (Info.Group_Name),
            Files.File_System.Group_Name_For_Id (0),
            "the pane shows the group name the window layer sampled");
      end;

      --  An unchanged name is not a change; a new one is, and is shown.
      Revision := Files.Model.Revision (Model);
      Files.Model.Set_Account_Name
        (Model, Files.Model.User_Account, 0, Files.File_System.User_Name_For_Id (0));
      Files_Suite.Support.Assert_Equal
        (Files.Model.Revision (Model), Revision, "recording the same name leaves the revision alone");
      Files.Model.Set_Account_Name (Model, Files.Model.User_Account, 0, "renamed_owner");
      Assert (Files.Model.Revision (Model) /= Revision, "a changed name bumps the revision so the view rebuilds");
      Files_Suite.Support.Assert_Equal
        (To_String (Shown_Info.Owner_Name), "renamed_owner", "the pane shows the newly recorded name");
      Assert (not Files.Model.Account_Names_Current (Model), "a changed model asks for a new sample");
   end Test_Snapshot_Owner_Names_From_Model;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Model_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Model;
