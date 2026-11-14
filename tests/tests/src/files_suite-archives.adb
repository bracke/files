with Files.Items;
with Files.File_Identities.Testing;
with Ada.Directories;
with Interfaces;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with Zlib;
with Hostkit.Host;
with Files.Archive_Writing;
with Files.Controller;
with Files.File_System;
with Files.Model;
with Files.Model.Selection;
with Files.Model.History;
with Files.Operations;
with Files.Settings;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Archives is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Host.Kind;
   use type Files.Operations.Operation_Status;
   use type Files.Operations.Archive_Format;
   use type Files.Types.Item_Kind;
   use type Files.Types.Search_Scope;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Archives_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Archives_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Archives_Test_Case);

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compress_Same_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Zip_Entries_From_End_Record (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Archives_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files archives");
   end Name;

   overriding procedure Register_Tests (T : in out Archives_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compress_Same_Names'Access,
         "Compressing two same-named items keeps both");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Zip_Entries_From_End_Record'Access,
         "zip entries are read from the end of central directory record");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compress_Selected_Operation'Access, "compress selected items into zip and 7z archives");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extract_Selected_Operation'Access, "extract selected archive into a new folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Archive_Completeness'Access,
         "archives fail instead of silently omitting selected sources");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Recent_Archive_Destinations'Access,
         "Recent archives publish beside their sources and preserve the working directory");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Archive_Directories'Access, "ZIP and 7z preserve nested empty and directory-only selections");
   end Register_Tests;

   procedure Test_Compress_Same_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Zip_Entries_From_End_Record (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Empty_Archive_Directories (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Archive_Completeness (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Recent_Archive_Destinations (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Archives_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Archives;
