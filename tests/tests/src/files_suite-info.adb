with Files.Items;
with Files.Folder_Size.Testing;
with Files.Model.Testing;
with Files.Process_Jobs;
with Files.Refresh_Jobs;
with Files.Extra_Info_Reader;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Files.Commands;
with Files.Events;
with Files.File_System;
with Files.Folder_Size;
with Files.Interaction;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Folder_Sizes;
with Files.Operations;
with Guikit.Draw;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Info is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Guikit.Draw.Accessibility_Role;
   use type Files.Types.Item_Kind;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Info_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Info_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Info_Test_Case);

   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Details_Off_The_UI_Thread (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Survives_Background_Read (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stale_Folder_Size_Dropped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Type_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Localized_Extras (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Facts_Characterized (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Pdf_Page_Markers_Any_Spacing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extra_Counts_Mark_Capped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Count_Honours_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Details_Reject_Stale_Revision (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Slots_Serve_Many_Windows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Frame_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Word_Wrap (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Item_Field_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Multi_Selection_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background_Folder_Size_Matches_Reference
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Batches_And_Hand_Over (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Survives_Faults (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Size_Multi_Selection
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Selection_Total_Counts_Folders
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Size_Over_Links (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Info_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files info pane and folder sizes");
   end Name;

   overriding procedure Register_Tests (T : in out Info_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Survives_Background_Read'Access,
         "a background read neither restarts a folder measurement nor bumps the revision when nothing changed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stale_Folder_Size_Dropped'Access,
         "a folder size measured before the folder changed is dropped and measured again");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Metadata_Snapshot'Access, "info pane snapshot includes metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Type_Metadata'Access, "item snapshots localize per-filetype metadata");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Localized_Extras'Access, "info pane localizes every kind of extra info");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Facts_Characterized'Access,
         "every filetype keeps its kind label, extra-info fallback and icon from the one mime table");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Pdf_Page_Markers_Any_Spacing'Access,
         "pdf page markers allow any white-space between the type and page names");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extra_Counts_Mark_Capped'Access,
         "counts stopped at a limit are marked capped");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Count_Honours_Hidden'Access,
         "a folder's item count includes hidden entries only when they are shown");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Details_Reject_Stale_Revision'Access,
         "item details read before a file changed are not applied to its new listing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Slots_Serve_Many_Windows'Access,
         "the background reader serves every window however many ask");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Frame_Layout'Access, "info pane frame lays out heading, rows and permission matrix");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Word_Wrap'Access, "info metadata wraps at word boundaries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Item_Field_Fallbacks'Access, "info pane reports metadata errors and item-field fallbacks");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Multi_Selection_Snapshot'Access, "info snapshot covers every selected item, coalesced");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Section_Tooltips'Access, "info pane sections carry descriptive tooltips");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Coalesced_Multi'Access,
         "multi-selection info pane coalesces sections with one value row per item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Filesize_Files_Only'Access,
         "info pane Filesize section is shown only for files, dropped when all folders");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Total_In_Contents'Access,
         "combined selection total is the last line of the Contents section");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Extra_Is_Lazy'Access,
         "filetype extra (folder counts, document scans) is computed lazily, not on load");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Helper_Cancellation'Access,
         "stalled folder-size helpers allow prompt polling, retargeting and cancellation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Is_Lazy'Access,
         "recursive folder size is requested for a selected folder and computed off the UI path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background_Folder_Size_Matches_Reference'Access,
         "background folder-size scan matches the synchronous Directory_Size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Batches_And_Hand_Over'Access,
         "folder sizes for more than one helper's worth: each once, a kept helper, a paced hand-over");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Survives_Faults'Access,
         "folder sizes are answered through refused launches and late results");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Size_Multi_Selection'Access,
         "a multi-item selection caches each selected folder's recursive size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Selection_Total_Counts_Folders'Access,
         "the selection total counts selected folders' recursive size");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recursive_Folder_Size'Access, "recursive folder size sums descendant files and surfaces the row");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Size_Over_Links'Access,
         "folder size counts a link once and never follows a cycle, a dangling link or a link out of the tree");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Window_Folder_Measurements'Access,
         "window size helpers are independent and refresh invalidates cached measurements");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Refresh'Access, "empty metadata is cached and info panes preserve manual refreshes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Details_Off_The_UI_Thread'Access,
         "a window reads the selected item's details off the UI thread");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Selection_Completion'Access, "keyboard selection and completed refresh populate info metadata");
   end Register_Tests;

   procedure Test_Folder_Size_Survives_Background_Read (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stale_Folder_Size_Dropped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Type_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Localized_Extras (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filetype_Facts_Characterized (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Pdf_Page_Markers_Any_Spacing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extra_Counts_Mark_Capped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Count_Honours_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Details_Reject_Stale_Revision (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Background_Slots_Serve_Many_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Frame_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Word_Wrap (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Item_Field_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Multi_Selection_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Each info-pane section label carries a descriptive hover tooltip drawn from
   --  its "<key>.tooltip" catalog entry.
   procedure Test_Info_Pane_Section_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  With several items selected the info pane is coalesced field-major: each
   --  section label is drawn once (not repeated per item) and each selected
   --  item's value follows as its own row.
   procedure Test_Info_Pane_Coalesced_Multi (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Filesize is a file-only field: folders show nothing for it, and when every
   --  selected item is a folder the section is dropped entirely. The label is
   --  "Filesize" in the default catalog.
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The combined selection total is the last line of the Contents section
   --  (below the Contents label and the per-folder rows), not a header above the
   --  sections.
   procedure Test_Info_Pane_Total_In_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The expensive "extra info" (folder child counts, document scans) must not
   --  be computed on load -- that made navigation slow. It is computed lazily
   --  only for the selected item when the info pane is open.
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Size_Helper_Cancellation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Selection_Completion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Refresh (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Details_Off_The_UI_Thread (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Window_Folder_Measurements (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Folder sizes used by the info pane and selection total are requested from
   --  Files.Folder_Size. Selecting a folder must leave the recursive walk to the
   --  helper and publish the completed result on a later frame.
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The background scan must produce exactly the same totals as the
   --  synchronous Directory_Size for a subtree within the entry/depth guards.
   procedure Test_Background_Folder_Size_Matches_Reference (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Size_Batches_And_Hand_Over (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Size_Survives_Faults (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  A multi-item selection measures every selected directory: each folder's
   --  recursive size is cached under its own path so the info pane can show a
   --  per-folder size and a combined selection total.
   procedure Test_Folder_Size_Multi_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  The combined selection total (shown in the bottom bar) counts the recursive
   --  size of selected folders, not just selected files -- and it is computed for
   --  any selection, independent of the info pane.
   procedure Test_Selection_Total_Counts_Folders (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recursive_Folder_Size (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Directory_Size_Over_Links (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Info_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Info;
