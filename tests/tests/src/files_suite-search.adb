with Files.File_System.Search;
with Files.Operations.Archives;
with Files.Controller.Operation_Commands;
with Files.UI_Types;
with Files.Operation_Results;
with Files.File_System.Permissions;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Operations;
with Hostkit.Fs;
with Files.Settings;
with Files_Suite.Support;
with Files_Suite.Operations_Support;
with Files_Suite.Support.Disk;

package body Files_Suite.Search is

   --  The command entry points the tests drive, by a short name.
   package Operation_Commands renames Files.Controller.Operation_Commands;

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Operation_Results.Operation_Status;
   use type Files.Operations.Archives.Archive_Format;
   use type Files.UI_Types.Search_Scope;
   use Files_Suite.Support;
   use Files_Suite.Support.Disk;
   use Files_Suite.Operations_Support;

   type Search_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Search_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Search_Test_Case);

   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Content_Search_Utf8_Cut (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Skips_Unreadable_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Match_Cap (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Name_Search_No_Matches (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recursive_Search (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Results_Keep_Their_Query (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Results_Through_Helpers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Search_Results_Select_By_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Utf16_Transcoding (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Search_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files search");
   end Name;

   overriding procedure Register_Tests (T : in out Search_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recursive_Search'Access, "recursive search finds nested matches and routes through commands");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Result_Actions_Stay_Beside_Source'Access,
         "renaming, duplicating or linking a search result keeps it in its own folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Results_Keep_Their_Query'Access,
         "search results are searched again for their own query, and settle a listing owed to the folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Results_Through_Helpers'Access,
         "a stale search-again read is owed and searches again as the window is now; helpers that trash or "
         & "restore results show their own search afterwards");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Results_Select_By_Path'Access,
         "results select a renamed or copied item by its path, undo and redo show their helper's search, "
         & "typing changes only the field, and the chip reads the folder once");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Content_Search_Operation'Access,
         "content search matches file contents case-insensitively, skips binary and capped files, "
         & "and drives the scope model");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Input_Snapshot'Access, "search input is modal and stale outcomes are discarded");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Read_Errors'Access,
         "an unreadable search root fails without replacing the listing; unreadable parts below it do not");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Content_Search_Utf8_Cut'Access,
         "content search cuts its read back to a whole character and still folds non-Latin case");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Skips_Unreadable_Folder'Access,
         "an unreadable folder below the root leaves the other matches shown as incomplete");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Match_Cap'Access,
         "the match cap shows the first matches with the truncated notice");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Name_Search_No_Matches'Access,
         "a name search with no match shows the no-matches notice");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Search_Limit_Errors'Access, "search limits show what was found with the truncated notice");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Utf16_Transcoding'Access,
         "UTF-16 text is told by its mark or NULs and transcoded, surrogates paired or replaced");
   end Register_Tests;

   procedure Test_Recursive_Search (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Result_Actions_Stay_Beside_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Results_Keep_Their_Query (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Results_Through_Helpers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Results_Select_By_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Limit_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Input_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Read_Errors (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Content_Search_Utf8_Cut (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Skips_Unreadable_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Search_Match_Cap (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Name_Search_No_Matches (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Content_Search_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Utf16_Transcoding (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Search_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Search;
