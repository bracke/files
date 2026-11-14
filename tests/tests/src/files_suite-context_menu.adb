with Files.File_System.Trash;
with Files.Rendering.Testing;
with Files.Items;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with Zlib;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Interaction;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Model.History;
with Files.Operations;
with Files.Paste;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Interaction_Support;

--  Headless coverage for the right-click menus: their contents, what enables
--  their rows, and command sequences run through them, through the real input
--  pipeline (the rules in Files_Suite.Interaction_Support).
package body Files_Suite.Context_Menu is

   use AUnit.Assertions;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Model.Clipboard_Mode;
   use Files_Suite.Interaction_Support;

   type Context_Menu_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Context_Menu_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Context_Menu_Test_Case);

   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Right_Click_On_Menu_Is_Ignored (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Right_Click_Translation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Conflict_Action_Guards (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Context_Menu_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files context menu");
   end Name;

   overriding procedure Register_Tests (T : in out Context_Menu_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Right_Click_Opens_Menu'Access, "right-click selects and opens the context menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Right_Click_On_Menu_Is_Ignored'Access,
         "a right-click on the open context menu is ignored, not passed to the item beneath");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Menu_Row_Dispatch'Access, "context-menu row dispatches its command and closes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Open_And_Edit'Access, "item-menu open, rename, cut, and duplicate commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Archive_Commands'Access, "item-menu compress-zip, compress-7z, and extract commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Empty_Area_Commands'Access, "empty-area menu new-folder and paste commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Trash_Lifecycle'Access, "item-menu delete, undo, and restore-from-trash lifecycle");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Menu_Contents_And_Enablement'Access,
         "item menu lists the expected commands and enables the selection-driven ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Area_Menu_Contents'Access,
         "empty-area menu lists create/new-folder/paste/open-terminal/refresh and no item-only commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Header_Menu_Column_Config'Access,
         "details-header menu lists the column toggles and grouping and flips a setting");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Right_Click_Translation'Access,
         "a right click is translated against the snapshot: item, header, empty view, chrome, the menu itself");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extract_Enablement_By_Selection'Access,
         "extract enables only when the selection includes an archive");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Restore_From_Trash_Enablement_By_Context'Access,
         "restore-from-trash enables only inside the trash files directory");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Enablement_Reflects_Clipboard'Access,
         "paste enables only when the clipboard holds items");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Conflict_Action_Guards'Access,
         "stale or malformed paste-conflict actions are ignored");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Disabled_Command_Does_Not_Act'Access,
         "dispatching a disabled menu command is gated and changes no state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Rename_Then_Undo'Access,
         "sequence: rename a file via the menu, commit, then undo back to the original name");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Compress_Then_Extract'Access,
         "sequence: compress a file to zip, then extract the reloaded archive");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Trash_Then_Restore'Access,
         "sequence: delete to trash, view the trash, then restore from the menu");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sequence_Cut_Paste_Into_Subdir'Access,
         "sequence: cut a file, paste it into a subdirectory, then undo the move");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Commands_Registry'Access,
         "recent commands register, gate on the recent view, and appear in the empty-area menu");
   end Register_Tests;

   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Right_Click_On_Menu_Is_Ignored (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Right_Click_Translation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extract_Enablement_By_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Conflict_Action_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Compress_Then_Extract (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Commands_Registry (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Context_Menu_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Context_Menu;
