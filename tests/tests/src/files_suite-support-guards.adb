with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;

with Files.Commands;
with Files.Localization;
with Files.Refresh;
with Files.Localization.Testing;

package body Files_Suite.Support.Guards is
   use Ada.Strings.Unbounded;

   procedure Save (Guard : in out Environment_Guard; Name : String) is
   begin
      if Guard.Count = Guard.Saved'Last then
         raise Program_Error with "Environment_Guard holds at most" & Guard.Saved'Last'Image & " variables";
      end if;
      Guard.Count := Guard.Count + 1;
      Guard.Saved (Guard.Count) :=
        (Name  => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Value => Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value (Name, "")),
         Was   => Ada.Environment_Variables.Exists (Name));
   end Save;

   overriding procedure Finalize (Guard : in out Environment_Guard) is
   begin
      for Index in reverse 1 .. Guard.Count loop
         declare
            Item : Saved_Variable renames Guard.Saved (Index);
            Name : constant String := Ada.Strings.Unbounded.To_String (Item.Name);
         begin
            if Item.Was then
               Ada.Environment_Variables.Set (Name, Ada.Strings.Unbounded.To_String (Item.Value));
            else
               Ada.Environment_Variables.Clear (Name);
            end if;
         end;
      end loop;
      Guard.Count := 0;
      --  A restored locale variable must be read again, not remembered.
      Files.Localization.Testing.Reread_Locale_Environment;
   end Finalize;

   overriding procedure Finalize (Guard : in out Shortcut_Guard) is
      pragma Unreferenced (Guard);
   begin
      Files.Commands.Reset_Shortcut_Overrides;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Shortcut_Guard could not clear the shortcut overrides: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   procedure Release (Guard : in out Paste_Guard) is
   begin
      Files.Model.End_Foreground_Job (Guard.Model.all);
      Files.Refresh.Cancel (Guard.Model.all);
   end Release;

   overriding procedure Finalize (Guard : in out Paste_Guard) is
   begin
      Release (Guard);
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Paste_Guard could not end the paste execution: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   procedure Remove_Transport_Fixture (Path : Files.Types.UString) is
   begin
      if Length (Path) > 0 and then Ada.Directories.Exists (To_String (Path)) then
         Project_Tools.Files.Delete_Tree (To_String (Path));
      end if;
   end Remove_Transport_Fixture;

   procedure Track (Guard : in out Process_Jobs_Guard; Path : Files.Types.UString) is
   begin
      Guard.Fixtures.Append (Path);
   end Track;

   procedure Release (Guard : in out Process_Jobs_Guard) is
   begin
      Files.Jobs.Process.Reset (Guard.Session.all);
      for Path of Guard.Fixtures loop
         Remove_Transport_Fixture (Path);
      end loop;
   end Release;

   overriding procedure Finalize (Guard : in out Process_Jobs_Guard) is
   begin
      Release (Guard);
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Process_Jobs_Guard could not restore the job fixtures: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   overriding procedure Initialize (Guard : in out Directory_Guard) is
   begin
      Guard.Saved := To_Unbounded_String (Ada.Directories.Current_Directory);
   end Initialize;

   overriding procedure Finalize (Guard : in out Directory_Guard) is
   begin
      if Length (Guard.Saved) > 0 then
         Ada.Directories.Set_Directory (To_String (Guard.Saved));
      end if;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Directory_Guard could not return to " & To_String (Guard.Saved) & ": "
            & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   function Saved_Directory (Guard : Directory_Guard) return String is (To_String (Guard.Saved));

end Files_Suite.Support.Guards;
