with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Alire_Manifests;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Project_Tools.Text;

--  Release-readiness checker for the files crate. Validates, using the shared
--  project_tools release helpers, that the project can be published: the
--  pin-free release manifest is publishable and in sync with the pinned
--  development manifest, the required release artifacts exist, and the release
--  notes are a maintained changelog. Run via tools/bin/release_check.
procedure Release_Check is
   use Ada.Text_IO;
   use Ada.Strings.Unbounded;

   function Project_Root return String is
      Here : constant String := Ada.Directories.Current_Directory;
   begin
      if Ada.Directories.Exists (Here & "/files.gpr") then
         return Here;
      elsif Ada.Directories.Exists (Here & "/../files.gpr") then
         return Ada.Directories.Full_Name (Here & "/..");
      else
         return Here;
      end if;
   end Project_Root;

   --  Extract the value of the manifest's top-level version = "..." field.
   function Manifest_Version (Path : String) return String is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Marker  : constant String := "version = """;
      First   : constant Natural := Ada.Strings.Fixed.Index (Content, Marker);
   begin
      if First = 0 then
         return "";
      end if;

      declare
         Start : constant Positive := First + Marker'Length;
         Stop  : constant Natural := Ada.Strings.Fixed.Index (Content (Start .. Content'Last), """");
      begin
         if Stop = 0 then
            return "";
         end if;

         return Content (Start .. Stop - 1);
      end;
   end Manifest_Version;

   Root         : constant String := Project_Root;
   Checker      : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (Root);
   Dev_Manifest : constant String := Root & "/alire.toml";
   Rel_Manifest : constant String := Root & "/alire.release.toml";
begin
   if not Project_Tools.Files.File_Exists (Root & "/files.gpr") then
      Put_Line
        (Standard_Error,
         "release_check must be run from the files project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Required release artifacts.
   Project_Tools.Release_Checks.Require_File (Checker, "alire.toml");
   Project_Tools.Release_Checks.Require_File (Checker, "alire.release.toml");
   Project_Tools.Release_Checks.Require_File (Checker, "README.md");
   Project_Tools.Release_Checks.Require_File (Checker, "share/doc/files/release-notes.md");

   --  The release manifest must be publishable: pin-free, named "files",
   --  declaring a license, and depending on the formerly-pinned crates by
   --  wildcard version.
   Project_Tools.Alire_Manifests.Require_Pin_Free_Crate_Manifest (Rel_Manifest, "files");
   Project_Tools.Alire_Manifests.Require_No_Local_Pins (Rel_Manifest);
   Project_Tools.Alire_Manifests.Require_Release_Dependencies
     (Rel_Manifest,
      [To_Unbounded_String ("project_tools"),
       To_Unbounded_String ("i18n"),
       To_Unbounded_String ("textrender"),
       To_Unbounded_String ("zlib")]);
   Project_Tools.Release_Checks.Require_Text (Checker, "alire.release.toml", "licenses =");

   --  The development manifest must keep the local workspace pins so that local
   --  builds resolve the sibling checkouts.
   Project_Tools.Alire_Manifests.Require_Workspace_Pin (Dev_Manifest, "project_tools", "../project_tools");
   Project_Tools.Alire_Manifests.Require_Workspace_Pin (Dev_Manifest, "i18n", "../i18n");
   Project_Tools.Alire_Manifests.Require_Workspace_Pin (Dev_Manifest, "textrender", "../textrender");
   Project_Tools.Alire_Manifests.Require_Workspace_Pin (Dev_Manifest, "zlib", "../zlib");

   --  The two manifests must declare the same version.
   declare
      Dev_Version : constant String := Manifest_Version (Dev_Manifest);
      Rel_Version : constant String := Manifest_Version (Rel_Manifest);
   begin
      if Dev_Version = "" then
         Project_Tools.Release_Checks.Fail ("alire.toml is missing a version");
      elsif Dev_Version /= Rel_Version then
         Project_Tools.Release_Checks.Fail
           ("alire.release.toml version (" & Rel_Version
            & ") must match alire.toml version (" & Dev_Version & ")");
      end if;
   end;

   --  Release notes must be a maintained changelog with an Unreleased section.
   Project_Tools.Release_Checks.Require_Text
     (Checker, "share/doc/files/release-notes.md", "## [Unreleased]");

   Put_Line ("files release checks passed");
exception
   when others =>
      --  The project_tools Require_*/Fail helpers print a diagnostic and set
      --  the failure exit status before raising; swallow the propagated raise
      --  so the tool exits with that status and no Ada traceback.
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Release_Check;
