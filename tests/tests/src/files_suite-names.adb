with Files.Items;
with Files.Model.Testing;
with Files.Process_Jobs;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Hostkit.Host;
with Files.File_System;
with Files.Localization;
with Files.Model;
with Files.Model.Selection;
with Files.Model.Rename;
with Files.Model.History;
with Files.Operations;
with Files.Paste;
with Hostkit.Fs;
with Files.Rendering;
with Files.Settings;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Names is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Host.Kind;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Search_Scope;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Names_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Names_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Names_Test_Case);

   procedure Test_Name_Too_Long_Is_Reported (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Leaf_Name_Length_Rules (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Generated_Names_Fit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Path_Text_Leaf_And_Parent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stem_And_Extension (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Numbered_Name_Fits (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_Create_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Invalid_Rename_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Rename_Stranded_Message (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Case_Only_Rename_Flips_Case (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Names_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files names");
   end Name;

   overriding procedure Register_Tests (T : in out Names_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_File'Access, "commit create-file temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Create_Folder'Access, "commit create-folder temporary item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Create_File_Does_Not_Overwrite'Access, "create-file refuses existing destination");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_Create_Names'Access, "create rejects invalid names without writing anything");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_Rename_Names'Access, "rename rejects invalid names and leaves the source in place");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Leaf_Name_Rules'Access, "leaf-name rules are host-gated");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Expand_User_Path'Access, "a leading tilde in the path field expands to home");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Rename'Access, "commit rename mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Commit_Multi_Rename'Access, "commit synchronized multi-rename best-effort");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Case_Only_Rename_Is_Safe'Access,
         "a case-only rename never loses data and distinct collisions stay refused");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Rename_Stranded_Message'Access,
         "a stranded case-only rename names where the item was left");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Case_Only_Rename_Flips_Case'Access,
         "renaming report.txt to Report.txt changes the case, on a case-insensitive volume too");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Name_Too_Long_Is_Reported'Access,
         "a name too long for any filesystem is reported as such");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Leaf_Name_Length_Rules'Access,
         "leaf name length is measured in bytes or utf-16 units by destination rules");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Generated_Names_Fit'Access,
         "a duplicate of a name at the length limit is cut to fit");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Path_Text_Leaf_And_Parent'Access,
         "a path's leaf and parent read from its text, for names the runtime will not parse");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stem_And_Extension'Access,
         "a leaf name splits into stem and extension one way everywhere");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Numbered_Name_Fits'Access,
         "a numbered keep-both name is cut to fit the destination");
   end Register_Tests;

   procedure Test_Commit_Create_File (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Create_Folder (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Invalid_Create_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Invalid_Rename_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Expand_User_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Leaf_Name_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Commit_Multi_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Name_Too_Long_Is_Reported (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Leaf_Name_Length_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Generated_Names_Fit (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Path_Text_Leaf_And_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Stem_And_Extension (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Numbered_Name_Fits (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  On a case-insensitive volume report.txt and Report.txt are one file, so
   --  the rename must go through a scratch name. The macOS and Windows
   --  runners' own disks are case-insensitive; where a macOS one is not, a
   --  small case-insensitive disk image stands in. Linux checks the plain case.
   procedure Test_Case_Only_Rename_Flips_Case (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Case_Only_Rename_Is_Safe (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Rename_Stranded_Message (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Names_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Names;
