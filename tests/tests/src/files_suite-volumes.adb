with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Hostkit.Host;
with Hostkit.Metadata;
with Hostkit.Process;
with Project_Tools.Files;

with Files_Suite.Support;

package body Files_Suite.Volumes is

   use Ada.Strings.Unbounded;
   use type Hostkit.Host.Kind;

   Searched : Boolean := False;
   Found    : Unbounded_String;
   Serial   : Natural := 0;

   --  The device of Path, or of its nearest existing ancestor: the scratch
   --  root may not have been made yet when a test first asks.
   --
   --  @param Path Path to place.
   --  @param Known True when the host gave a comparable id.
   --  @return The id when Known, otherwise 0.
   function Device_Of (Path : String; Known : out Boolean) return Long_Long_Integer;

   --  A name no earlier call in this run returned.
   --
   --  @param Prefix Readable leading part of the name.
   --  @return Prefix followed by a time stamp and a serial number.
   function Unique_Name (Prefix : String) return String;

   --  Make a new directory directly under Base.
   --
   --  @param Base Existing directory.
   --  @param Prefix Readable leading part of the new directory's name.
   --  @return The new directory, or "" when none could be made.
   function Make_Directory (Base, Prefix : String) return String;

   --  Is Candidate a writable directory on another device than the root?
   --
   --  @param Candidate Directory to try.
   --  @return True when it qualifies as Other_Volume.
   function Qualifies (Candidate : String) return Boolean;

   function Device_Of (Path : String; Known : out Boolean) return Long_Long_Integer is
   begin
      if Ada.Directories.Exists (Path) then
         return Hostkit.Metadata.Device_Id (Path, Known);
      end if;
      declare
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent = Path then
            Known := False;
            return 0;
         end if;
         return Device_Of (Parent, Known);
      end;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         Known := False;
         return 0;
   end Device_Of;

   function Unique_Name (Prefix : String) return String is
      Stamp : String :=
        Ada.Strings.Fixed.Trim (Duration'Image (Ada.Calendar.Seconds (Ada.Calendar.Clock)), Ada.Strings.Left);
   begin
      for C of Stamp loop
         if C = '.' then
            C := '-';
         end if;
      end loop;
      Serial := Serial + 1;
      return Prefix & Stamp & "-" & Ada.Strings.Fixed.Trim (Natural'Image (Serial), Ada.Strings.Left);
   end Unique_Name;

   function Make_Directory (Base, Prefix : String) return String is
   begin
      for Attempt in 1 .. 100 loop
         declare
            Candidate : constant String := Ada.Directories.Compose (Base, Unique_Name (Prefix));
         begin
            if not Ada.Directories.Exists (Candidate) then
               Ada.Directories.Create_Directory (Candidate);
               return Candidate;
            end if;
         exception
            when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
               null;
         end;
      end loop;
      return "";
   end Make_Directory;

   function Qualifies (Candidate : String) return Boolean is
      use type Ada.Directories.File_Kind;
      Root_Known, Here_Known : Boolean;
   begin
      if Candidate = ""
        or else not Ada.Directories.Exists (Candidate)
        or else Ada.Directories.Kind (Candidate) /= Ada.Directories.Directory
      then
         return False;
      end if;
      declare
         Root_Device : constant Long_Long_Integer := Device_Of (Files_Suite.Support.Root, Root_Known);
         Here_Device : constant Long_Long_Integer := Device_Of (Candidate, Here_Known);
      begin
         if not Root_Known or else not Here_Known or else Root_Device = Here_Device then
            return False;
         end if;
      end;
      declare
         Probe : constant String := Make_Directory (Candidate, "files-test-volume-probe-");
      begin
         if Probe = "" then
            return False;
         end if;
         Ada.Directories.Delete_Directory (Probe);
         return True;
      end;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         return False;
   end Qualifies;

   function Other_Volume return String is
   begin
      if not Searched then
         Searched := True;
         declare
            Configured : constant String := Ada.Environment_Variables.Value ("FILES_TEST_OTHER_VOLUME", "");
         begin
            if Configured /= "" and then Qualifies (Configured) then
               Found := To_Unbounded_String (Configured);
            else
               if Configured /= "" then
                  --  Said once: CI set it up, and its tests would otherwise skip
                  --  with nothing to say the volume was the cause.
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "FILES_TEST_OTHER_VOLUME=" & Configured
                     & " is ignored: not a writable directory on a device other than " & Files_Suite.Support.Root);
               end if;
               if Hostkit.Host.Current = Hostkit.Host.Linux and then Qualifies ("/dev/shm") then
                  Found := To_Unbounded_String ("/dev/shm");
               end if;
            end if;
         end;
      end if;
      return To_String (Found);
   end Other_Volume;

   --  Delete the tree Directory made, if any; never raises, since it runs
   --  from Finalize while an assertion may already be propagating.
   --
   --  @param Directory Object whose tree goes.
   procedure Remove (Directory : in out Remote_Directory);

   procedure Remove (Directory : in out Remote_Directory) is
      Location : constant String := To_String (Directory.Location);
   begin
      Directory.Location := Null_Unbounded_String;
      if Location /= "" and then Ada.Directories.Exists (Location) then
         Project_Tools.Files.Delete_Tree (Location);
      end if;
      if Length (Directory.Volume_Trash) > 0
        and then Ada.Directories.Exists (To_String (Directory.Volume_Trash))
      then
         Project_Tools.Files.Delete_Tree (To_String (Directory.Volume_Trash));
      end if;
      Directory.Volume_Trash := Null_Unbounded_String;
   exception
      when others =>
         null;
   end Remove;

   --  Where this user's freedesktop trash would be on the volume holding
   --  Path: .Trash-$uid at the volume's top; "" without a numeric user id.
   function Volume_Trash_Of (Path : String) return String is
      Known  : Boolean;
      Device : constant Long_Long_Integer := Hostkit.Metadata.Device_Id (Path, Known);
      Top    : Unbounded_String := To_Unbounded_String (Path);
      Id     : Natural;
   begin
      if not Known or else not Hostkit.Process.Current_User_Id (Id) then
         return "";
      end if;
      loop
         declare
            Up       : constant String := Ada.Directories.Containing_Directory (To_String (Top));
            Up_Known : Boolean;
         begin
            exit when Up = To_String (Top)
              or else Hostkit.Metadata.Device_Id (Up, Up_Known) /= Device
              or else not Up_Known;
            Top := To_Unbounded_String (Up);
         exception
            when Ada.Directories.Use_Error => exit;
         end;
      end loop;
      return
        Ada.Directories.Compose
          (To_String (Top), ".Trash-" & Ada.Strings.Fixed.Trim (Natural'Image (Id), Ada.Strings.Left));
   end Volume_Trash_Of;

   procedure Create (Directory : in out Remote_Directory; Prefix : String) is
      Base : constant String := Other_Volume;
   begin
      Remove (Directory);
      if Base /= "" then
         Directory.Location := To_Unbounded_String (Make_Directory (Base, Prefix));
         declare
            Trash : constant String := Volume_Trash_Of (Base);
         begin
            if Trash /= "" and then not Ada.Directories.Exists (Trash) then
               Directory.Volume_Trash := To_Unbounded_String (Trash);
            end if;
         end;
      end if;
   end Create;

   function Path (Directory : Remote_Directory) return String is
     (To_String (Directory.Location));

   overriding procedure Finalize (Directory : in out Remote_Directory) is
   begin
      Remove (Directory);
   end Finalize;

end Files_Suite.Volumes;
