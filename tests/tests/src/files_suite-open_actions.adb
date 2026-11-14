with Files.Items;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Hostkit.Host;
with Hostkit.Shell;
with Files.Desktop_Applications;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Operations;
with Files.Operations.Testing;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Open_Actions is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.Operations.Testing.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Open_Actions_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Open_Actions_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Open_Actions_Test_Case);

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_File_Open_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Shell_Environment (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Click_Selects_Without_Opening (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Explicit_Shell_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_Executable_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Return_And_Double_Click_Open (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Backslash_Executable_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Application_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Exec_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Open_With_Palette_Launch (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Relative_Xdg_Application_Paths (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Open_Actions_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files open actions");
   end Name;

   overriding procedure Register_Tests (T : in out Open_Actions_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_Directory_Loads_Items'Access, "open directory loads and navigates");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Action_Policy'Access, "a generic failed operation is not an open-action preflight failure");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Selected_File_Prepares_Action'Access, "open file executes configured action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multi_File_Open_Preflight'Access, "multi-file open preflights every action before spawning");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Shell_Environment'Access, "open-action shell follows the host shell environment");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Click_Selects_Without_Opening'Access, "item click selects without opening and keeps focus rules");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Explicit_Shell_Open_Actions'Access, "explicit shell open actions quote arguments and launch detached");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_Executable_Preflight'Access,
         "open actions reject missing, directory and placeholder executables");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Return_And_Double_Click_Open'Access, "Return and double-click run the modifier-specific open action");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Missing_Open_Action_Reports_Error'Access, "missing open action reports localized error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Backslash_Executable_Lookup'Access, "a POSIX executable containing a backslash is found on PATH");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detected_Terminal_Helper'Access, "detected terminal helper honors the TERMINAL override");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Application_Discovery'Access,
         "open-with discovers valid desktop entries and rejects malformed or hidden ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Exec_Expansion'Access, "desktop Exec templates expand into launch argument vectors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Open_With_Palette_Launch'Access,
         "the Open With palette launches per target and reports a missing executable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Relative_Xdg_Application_Paths'Access,
         "application discovery ignores relative XDG data paths");
   end Register_Tests;

   procedure Test_Open_Selected_Directory_Loads_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Action_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Selected_File_Prepares_Action (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Multi_File_Open_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Shell_Environment (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Click_Selects_Without_Opening (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Explicit_Shell_Open_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_Executable_Preflight (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Return_And_Double_Click_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Missing_Open_Action_Reports_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Backslash_Executable_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detected_Terminal_Helper (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Application_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Exec_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Open_With_Palette_Launch (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Relative_Xdg_Application_Paths (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Open_Actions_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Open_Actions;
