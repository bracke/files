with Files.Environment;
with GNAT.OS_Lib;
with Ada.Directories;
with Hostkit.Fs;
with Files.IO.Fs_Primitives;
with Ada.Strings.Unbounded;

package body Files.Settings.Storage is

   --  ~/.config/files/settings.conf on every host: correct on Linux, and where a
   --  settings file may already have been written on any host, which has to
   --  keep being found: see Default_Settings_Path.
   function Legacy_Settings_Path
     (Home_Path : String)
      return String is
   begin
      return
        Hostkit.Fs.Join
          (Hostkit.Fs.Join
             (Hostkit.Fs.Join (Home_Path, ".config"), "files"),
           "settings.conf");
   end Legacy_Settings_Path;

   function Default_Settings_Path
     (Home_Path : String)
      return String
   is
      --  Honouring XDG_CONFIG_HOME on every host is this application's policy,
      --  the same policy the thumbnail cache applies to XDG_CACHE_HOME: macOS and
      --  Windows do not read it, and Hostkit says what the host does, but a user
      --  who exported it meant it. It is a user-level override, so it applies
      --  whichever home is being asked about.
      Raw_Xdg_Config : constant String :=
        Files.Environment.Value ("XDG_CONFIG_HOME");
      Xdg_Config : constant String :=
        (if GNAT.OS_Lib.Is_Absolute_Path (Raw_Xdg_Config) then
            Raw_Xdg_Config
         else "");

      Legacy : constant String := Legacy_Settings_Path (Home_Path);

      --  Hostkit answers where configuration goes for THIS user -- it resolves
      --  the home itself -- so its answer applies only when the home being asked
      --  about is that user's. Asked about another home (a test fixture, or the
      --  fallback this application picked when the host's own home did not
      --  exist), the only layout that can be applied to it is the POSIX one.
      Host_Config : constant String :=
        (if Home_Path /= "" and then Home_Path = Hostkit.Fs.Home_Directory
           and then GNAT.OS_Lib.Is_Absolute_Path (Hostkit.Fs.Config_Directory)
         then Hostkit.Fs.Config_Directory
         else "");

      function In_Config_Root (Root : String) return String is
        (Hostkit.Fs.Join
           (Hostkit.Fs.Join (Root, "files"), "settings.conf"));
   begin
      if Xdg_Config /= "" then
         return In_Config_Root (Xdg_Config);
      end if;

      --  An existing settings file wins over relocating it. Configuration used
      --  to go in ~/.config on every host: right on Linux, neither convention on
      --  the other two. Asking Hostkit fixes that for a new install, but moving
      --  the path for an existing one would orphan the file -- Ensure_Default_File
      --  would find nothing at the new location and write a fresh default,
      --  silently, over choices that cannot be regenerated from anything.
      if Files.IO.Fs_Primitives.File_Exists (Legacy) or else Host_Config = "" then
         return Legacy;
      end if;

      return In_Config_Root (Host_Config);
   end Default_Settings_Path;

   function Configured_Settings_Path
     (Home_Path : String)
      return String
   is
      Files_Settings : constant String := Files.Environment.Value ("FILES_SETTINGS");
   begin
      --  FILES_SETTINGS is this application's own override and wins over
      --  everything; XDG_CONFIG_HOME, the user's override of where
      --  configuration goes, is read by Default_Settings_Path.
      if Files_Settings /= "" then
         return Files_Settings;
      end if;

      return Default_Settings_Path (Home_Path);
   end Configured_Settings_Path;

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   function Parent_Directory (Path : String) return String renames Files.IO.Fs_Primitives.Parent_Directory;

   --  The settings file as this process last read or wrote it (Load_File,
   --  Save_Text): its text, which tells another process's change, and what
   --  it said (Note_Seen_Settings may restate it), which Merge_From_File
   --  weighs this process's changes against.
   Seen_Path  : Unbounded_String;
   Seen_Text  : Unbounded_String;
   Seen_Base  : Settings_Model;
   Seen_Known : Boolean := False;

   procedure Note_Seen (Path, Text : String; Base : Settings_Model) is
   begin
      Seen_Path := To_Unbounded_String (Path);
      Seen_Text := To_Unbounded_String (Text);
      Seen_Base := Base;
      Seen_Known := True;
   end Note_Seen;

   procedure Note_Seen_Settings (Path : String; Settings : Settings_Model) is
   begin
      if Seen_Known and then To_String (Seen_Path) = Path then
         Seen_Base := Settings;
      end if;
   end Note_Seen_Settings;

   function Full_Result (Settings_Path : String) return Settings_Write_Result is
     (Success   => False,
      Durable   => False,
      Path      => To_Unbounded_String (Settings_Path),
      Error_Key => To_Unbounded_String ("error.settings.full"));

   function Unchanged_Result (Settings_Path : String) return Settings_Write_Result is
     (Success   => True,
      Durable   => True,
      Path      => To_Unbounded_String (Settings_Path),
      Error_Key => Null_Unbounded_String);

   function Write
     (Settings_Path : String;
      Settings      : in out Settings_Model)
      return Settings_Write_Result
   is
      Merged, Refused : Boolean;
   begin
      if Settings.Persistence_Refused then
         return
           (Success   => True,
            Durable   => False,
            Path      => To_Unbounded_String (Settings_Path),
            Error_Key => To_Unbounded_String ("error.settings.not_persisted"));
      elsif Settings_Path = "" then
         return (Success => True, Durable => True, Path => Null_Unbounded_String, Error_Key => Null_Unbounded_String);
      end if;
      declare
         Own : constant Settings_Model := Settings;
         --  The record of the file as seen, kept in case the merge is undone.
         Was_Text : constant Unbounded_String := Seen_Text;
         Was_Base : constant Settings_Model := Seen_Base;
      begin
         Merge_From_File (Settings_Path, Settings, Merged, Refused);
         if Refused then
            return
              (Success   => True,
               Durable   => False,
               Path      => To_Unbounded_String (Settings_Path),
               Error_Key => To_Unbounded_String ("error.settings.changed_elsewhere"));
         elsif Merged then
            if not Loadable (Settings) then
               --  Own is kept, measured against the file as it was seen.
               Settings := Own;
               Note_Seen (Settings_Path, To_String (Was_Text), Was_Base);
               return Full_Result (Settings_Path);
            end if;
         end if;
      end;
      return Save_Text (Settings_Path, To_Text (Settings));
   end Write;

   function Persist
     (Settings_Path : String;
      Settings      : in out Settings_Model;
      Taken_In      : out Boolean)
      return Settings_Write_Result
   is
      Before : constant Settings_Model := Settings;
   begin
      Taken_In := False;
      if not Loadable (Settings) then
         return Full_Result (Settings_Path);
      end if;
      declare
         Saved : constant Settings_Write_Result := Write (Settings_Path, Settings);
      begin
         Taken_In := not Same_Content (Settings, Before);
         return Saved;
      end;
   end Persist;

   function Decide_Commit
     (Current : Settings_Model;
      Updated : Settings_Model)
      return Commit_Decision is
   begin
      if Same_Content (Updated, Current) then
         return Commit_Unchanged;
      elsif not Loadable (Updated) and then Loadable (Current) then
         return Commit_Refused;
      else
         return Commit_Accepted;
      end if;
   end Decide_Commit;

   function Load_File
     (Path : String)
      return Settings_Parse_Result
 is separate;

   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
 is separate;

   procedure Merge_From_File
     (Path     : String;
      Settings : in out Settings_Model;
      Merged   : out Boolean;
      Refused  : out Boolean)
 is separate;

   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result
 is separate;

end Files.Settings.Storage;
