with Ada.Directories;
with Hostkit.Fs;
with Files.IO.Fs_Primitives;
with Ada.Strings.Unbounded;

package body Files.Settings.Storage is

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
