with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Glfw;

with GNAT.OS_Lib;

with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Durability;

with Files.Application;
with Files.Application.Windows;
with Files.Application.Windows.Smoke;
with Files.Commands;
with Files.Drop_Events;
with Files.Durable_Writes;
with Files.Durable_Writes.Testing;
with Files.File_System;
with Files.Fs_Primitives;
with Files.Localization;
with Files.Model;
with Files.Settings;
with Files.Types;
with Files_Suite.Repository;
with Files_Suite.Support;

package body Files_Suite.Startup is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Hostkit.Host.Kind;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_32;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Application.Run_Mode;
   use Files_Suite.Support;

   type Startup_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Startup_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Startup_Test_Case);

   procedure Test_Startup_Path_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Existing_Settings_File_Is_Not_Orphaned
     (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Default_Home_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Loads_Settings_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Invalid_Settings_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Settings_Path_Not_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_And_Runtime_Smoke_Reports (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Runtime_Capabilities_And_Drop_Events (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Fractional_Scroll_Accumulation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Input_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Window_Smoke_Plan (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Error_Report (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Startup_Report_Settings_Error (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Run_Configuration_Parsing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Durable_Publication_Outcomes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Localization_Runtime_Labels (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Localization_Western_Translations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Localization_Pane_Labels (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Localization_Error_And_Command_Keys (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Locale_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Locale_Variable_Precedence (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detected_Locale_Catalogs (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Host_Locale_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Runtime_Wiring (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Desktop_Packaging_Contents (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Smoke_Gate_Outcome (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Live_Smoke_Scenarios_Verdict (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Startup_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files startup and policy");
   end Name;

   overriding procedure Register_Tests (T : in out Startup_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Path_Normalization'Access, "startup path normalization");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Default_Home_Selection'Access, "default home selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Existing_Settings_File_Is_Not_Orphaned'Access,
         "an existing settings file is not orphaned when the host location changes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Loads_Settings_File'Access, "startup loads settings file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Invalid_Settings_Diagnostic'Access, "startup reports invalid settings");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Settings_Path_Not_File'Access, "startup reports non-file settings path");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_And_Runtime_Smoke_Reports'Access,
         "startup and runtime smoke reports use localized labels and verdicts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Runtime_Capabilities_And_Drop_Events'Access, "runtime capabilities and the drop event source");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Fractional_Scroll_Accumulation'Access,
         "fractional and pending scroll offsets accumulate and saturate");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Input_Mapping'Access,
         "desktop text input, coordinate scaling, scrollbar drag and cursor bounds");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Window_Smoke_Plan'Access, "live window smoke plan and headless smoke evaluation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Error_Report'Access, "desktop startup error report");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Startup_Report_Settings_Error'Access, "startup report formats settings errors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Run_Configuration_Parsing'Access, "runtime smoke argument parsing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Durable_Publication_Outcomes'Access, "durable publication outcome taxonomy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localization_Runtime_Labels'Access,
         "default catalog localizes startup, runtime smoke and CLI help labels");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localization_Western_Translations'Access,
         "western locales translate command, error and status labels");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localization_Pane_Labels'Access,
         "default catalog localizes info pane, status and landmark labels with key fallback");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localization_Error_And_Command_Keys'Access, "every error key and registered command is localized");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Locale_Normalization'Access, "locale names normalize, and hostile ones fall back to English");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Locale_Variable_Precedence'Access, "locale environment variables apply in POSIX precedence");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detected_Locale_Catalogs'Access, "a detected locale loads its translated and date/time catalogs");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Host_Locale_Fallbacks'Access, "the system locale is asked of the host, falling back to KDE formats");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Runtime_Wiring'Access, "desktop runtime wiring and capability report");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Desktop_Packaging_Contents'Access,
         "desktop packaging ships its metadata, documentation and manifest entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Smoke_Gate_Outcome'Access, "live smoke gate outcome taxonomy");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Live_Smoke_Scenarios_Verdict'Access, "live smoke multi-scenario verdict aggregation");
   end Register_Tests;

   procedure Test_Startup_Path_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Existing_Settings_File_Is_Not_Orphaned
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Default_Home_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_Loads_Settings_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_Invalid_Settings_Diagnostic (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_Settings_Path_Not_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_And_Runtime_Smoke_Reports (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Runtime_Capabilities_And_Drop_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Fractional_Scroll_Accumulation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Input_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Live_Window_Smoke_Plan (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Error_Report (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Startup_Report_Settings_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Run_Configuration_Parsing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Durable_Publication_Outcomes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Localization_Runtime_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Localization_Western_Translations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Localization_Pane_Labels (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Localization_Error_And_Command_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Locale_Normalization (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Locale_Variable_Precedence (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detected_Locale_Catalogs (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Host_Locale_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Runtime_Wiring (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Desktop_Packaging_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Live_Smoke_Gate_Outcome (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Live_Smoke_Scenarios_Verdict (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Startup_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Startup;
