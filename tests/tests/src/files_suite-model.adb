with Ada.Calendar;
with Files.Grouping;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with GNAT.OS_Lib;
with Hostkit.Host;

with Files.Application;
with Files.Application.Windows;
with Files.Bounded_Text_IO;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Files.Quick_Look;
with Files.Rendering;
with Files.Settings;
with Files.Type_Ahead;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;

package body Files_Suite.Model is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.Types.Sort_Field;
   use type Files.Model.Undo_Entry;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;
   use Files_Suite.Support;

   type Model_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Model_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Model_Test_Case);

   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Retire_Drain (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Overlay_Queries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_History_Move_Leaves_View (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_History_Retire_Drain'Access,
         "a model history mutation leaves retired payloads on disk until the operations layer settles it");
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlay_Queries'Access,
         "the overlay queries read one list of input-owning overlays");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_History_Move_Leaves_View'Access,
         "going back closes Quick Look and recording Undo redraws");
   end Register_Tests;

   procedure Test_Directory_Sorting (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Accent_Folding_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Retire_Drain (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Restore_Admission
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Directory_Projection_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The "extra info" is now computed lazily (not stored on load), so tests
   --  compute it on demand via the shared token function.
   function Item_Extra (I : Files.File_System.Directory_Item) return String is
     (Files.File_System.Extra_Info_Token
        (To_String (I.Full_Path), I.Kind, To_String (I.Filetype)));

   procedure Test_Filetype_Metadata_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Executable_And_Symlink_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Encoding_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Document_Media_And_Source_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filetype_Detection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_View_Mode_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Selection_Movement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Grid_Paging_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Type_Ahead_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filtering_Reconciles_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Input_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Runtime_Sort_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Volume_Capabilities_And_Platform_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class)
     is separate;

   procedure Test_Root_Discovery_Environment_Profiles (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Open_And_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Volume_Details_By_Mount_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Eject_And_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Settings_Exclusivity_And_Close (T : in out AUnit.Test_Cases.Test_Case'Class)
     is separate;

   procedure Test_Root_Selection_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Keyboard_Navigation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Blocks_Background_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Root_Selector_Row_Activation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bounded_Host_Text_Records
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Info_Pane_Toggle_And_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Scroll_Resets_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_View_Mode_And_Bottom_Bar_Clicks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Grid_Page_Keys_Page_The_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Main_View_Scroll_And_Settings_Block (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Rename_Mode (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_Rename_Broadcast (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Command_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Temporary_Item_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Mixed_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Untitled_Name_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Error_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Content_Prep (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Model_State (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Grouping_Band_Edges (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Group_By_Label_Bands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Snapshot_Labels_And_Favorites_At_Scale (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Snapshot_Owner_Names_From_Model (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlay_Queries (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_History_Move_Leaves_View (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Model_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Model;
