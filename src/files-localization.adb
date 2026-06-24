with Ada.Containers.Vectors;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

with Files.Platform.Macos;
with Files.Platform.Windows;
with Files_Config;

package body Files.Localization is
   use Ada.Strings.Unbounded;
   use type I18N.Result.Render_Status;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Unbounded_String);

   Runtime     : I18N.Runtime.Instance;
   Initialized : Boolean := False;
   Available   : Boolean := False;
   Loaded_Locales : String_Vectors.Vector;

   function Environment_Locale (Name : String) return String;
   function Environment_Portable_Locale (Name : String) return Boolean;
   function Configured_Category_Locale (Category_Key : String) return String;
   function Host_OS return String;
   function Native_System_Locale return String;
   function Render_Text
     (Key    : String;
      Locale : String)
      return String;
   function Locale_Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String;
   function Portable_Locale (Value : String) return Boolean;
   function Catalog_Root return String;
   function Catalog_Path return String;
   function Locale_Catalog_Path (Locale : String) return String;
   function Locale_Loaded (Locale : String) return Boolean;
   procedure Load_Locale (Locale : String);
   procedure Ensure_Initialized;

   function Normalize_Locale (Value : String) return String is
      Raw    : constant String := Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
      Last   : Natural := Raw'Last;
      Result : Unbounded_String;
      Region : Boolean := False;
   begin
      if Raw'Length = 0 then
         return "en";
      end if;

      for Index in Raw'Range loop
         if Raw (Index) = '.' or else Raw (Index) = '@' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      if Last < Raw'First then
         return "en";
      end if;

      declare
         Base : constant String := Raw (Raw'First .. Last);
      begin
         if Base = "C" or else Base = "POSIX" then
            return "en";
         end if;

         for Character of Base loop
            if Character = '_' or else Character = '-' then
               Append (Result, '-');
               Region := True;
            elsif Region then
               Append (Result, Ada.Characters.Handling.To_Upper (Character));
            else
               Append (Result, Ada.Characters.Handling.To_Lower (Character));
            end if;
         end loop;
      end;

      if Length (Result) = 0 then
         return "en";
      end if;

      return To_String (Result);
   end Normalize_Locale;

   function System_Locale return String is
      LC_All      : constant String := Environment_Locale ("LC_ALL");
      LC_Messages : constant String := Environment_Locale ("LC_MESSAGES");
      Lang        : constant String := Environment_Locale ("LANG");
   begin
      if LC_All /= "" then
         return LC_All;
      elsif LC_Messages /= "" then
         return LC_Messages;
      elsif Lang /= "" then
         return Lang;
      end if;

      declare
         Native : constant String := Native_System_Locale;
      begin
         if Native /= "" then
            return Native;
         end if;
      end;

      return "en";
   end System_Locale;

   function System_Time_Locale return String is
      LC_All  : constant String := Environment_Locale ("LC_ALL");
      LC_Time : constant String := Environment_Locale ("LC_TIME");
      Lang    : constant String := Environment_Locale ("LANG");
      Config  : constant String := Configured_Category_Locale ("LC_TIME");
   begin
      if LC_All /= "" then
         return LC_All;
      elsif LC_Time /= "" then
         return LC_Time;
      elsif Lang /= "" and then not Environment_Portable_Locale ("LANG") then
         return Lang;
      elsif Config /= "" then
         return Config;
      elsif Lang /= "" then
         return Lang;
      end if;

      declare
         Native : constant String := Native_System_Locale;
      begin
         if Native /= "" then
            return Native;
         end if;
      end;

      return "en";
   end System_Time_Locale;

   function System_Number_Locale return String is
      LC_All     : constant String := Environment_Locale ("LC_ALL");
      LC_Numeric : constant String := Environment_Locale ("LC_NUMERIC");
      Lang       : constant String := Environment_Locale ("LANG");
      Config     : constant String := Configured_Category_Locale ("LC_NUMERIC");
   begin
      if LC_All /= "" then
         return LC_All;
      elsif LC_Numeric /= "" then
         return LC_Numeric;
      elsif Lang /= "" and then not Environment_Portable_Locale ("LANG") then
         return Lang;
      elsif Config /= "" then
         return Config;
      elsif Lang /= "" then
         return Lang;
      end if;

      declare
         Native : constant String := Native_System_Locale;
      begin
         if Native /= "" then
            return Native;
         end if;
      end;

      return "en";
   end System_Number_Locale;

   function Environment_Locale (Name : String) return String is
   begin
      if not Ada.Environment_Variables.Exists (Name) then
         return "";
      end if;

      declare
         Value : constant String :=
           Ada.Strings.Fixed.Trim (Ada.Environment_Variables.Value (Name), Ada.Strings.Both);
      begin
         if Value'Length = 0 then
            return "";
         end if;

         return Normalize_Locale (Value);
      end;
   end Environment_Locale;

   function Environment_Portable_Locale (Name : String) return Boolean is
   begin
      return Ada.Environment_Variables.Exists (Name)
        and then Portable_Locale (Ada.Environment_Variables.Value (Name));
   end Environment_Portable_Locale;

   function Host_OS return String is
   begin
      return Files_Config.Alire_Host_OS;
   end Host_OS;
   pragma No_Inline (Host_OS);

   function Native_System_Locale return String is
      Raw : constant String :=
        (if Host_OS = "windows" then
            Files.Platform.Windows.Native_Locale
         elsif Host_OS = "macos" then
            Files.Platform.Macos.Native_Locale
         else "");
   begin
      if Raw = "" then
         return "";
      end if;

      return Normalize_Locale (Raw);
   end Native_System_Locale;

   function Configured_Category_Locale (Category_Key : String) return String is
      Home : Unbounded_String;

      function Existing_Value
        (Path    : String;
         Section : String;
         Key     : String)
         return String
      is
         Value : constant String := Locale_Config_Value (Path, Section, Key);
      begin
         if Value /= "" then
            return Normalize_Locale (Value);
         end if;

         return "";
      end Existing_Value;
   begin
      if Ada.Environment_Variables.Exists ("HOME") then
         Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;

      if Length (Home) > 0 then
         declare
            Plasma : constant String := To_String (Home) & "/.config/plasma-localerc";
            Value  : constant String := Existing_Value (Plasma, "Formats", Category_Key);
         begin
            if Value /= "" then
               return Value;
            end if;
         end;

         declare
            Plasma : constant String := To_String (Home) & "/.config/plasma-localerc";
            Value  : constant String := Existing_Value (Plasma, "Formats", "LANG");
         begin
            if Value /= "" then
               return Value;
            end if;
         end;
      end if;

      declare
         Value : constant String := Existing_Value ("/etc/locale.conf", "", Category_Key);
      begin
         if Value /= "" then
            return Value;
         end if;
      end;

      declare
         Value : constant String := Existing_Value ("/etc/locale.conf", "", "LANG");
      begin
         if Value /= "" then
            return Value;
         end if;
      end;

      declare
         Value : constant String := Existing_Value ("/etc/default/locale", "", Category_Key);
      begin
         if Value /= "" then
            return Value;
         end if;
      end;

      declare
         Value : constant String := Existing_Value ("/etc/default/locale", "", "LANG");
      begin
         if Value /= "" then
            return Value;
         end if;
      end;

      return "";
   end Configured_Category_Locale;

   function Locale_Config_Value
     (Path    : String;
      Section : String;
      Key     : String)
      return String
   is
      File       : Ada.Text_IO.File_Type;
      In_Section : Boolean := Section = "";
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line       : constant String := Ada.Text_IO.Get_Line (File);
            Trimmed    : constant String := Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
            Equals_Pos : Natural;
         begin
            if Trimmed'Length = 0
              or else Trimmed (Trimmed'First) = '#'
              or else Trimmed (Trimmed'First) = ';'
            then
               null;
            elsif Trimmed'Length > 2
              and then Trimmed (Trimmed'First) = '['
              and then Trimmed (Trimmed'Last) = ']'
            then
               In_Section := Trimmed (Trimmed'First + 1 .. Trimmed'Last - 1) = Section;
            elsif In_Section then
               Equals_Pos := Ada.Strings.Fixed.Index (Trimmed, "=");
               if Equals_Pos > 0 then
                  declare
                     Name  : constant String :=
                       Ada.Strings.Fixed.Trim (Trimmed (Trimmed'First .. Equals_Pos - 1), Ada.Strings.Both);
                     Value : constant String :=
                       (if Equals_Pos < Trimmed'Last then
                          Ada.Strings.Fixed.Trim (Trimmed (Equals_Pos + 1 .. Trimmed'Last), Ada.Strings.Both)
                        else "");
                  begin
                     if Name = Key then
                        Ada.Text_IO.Close (File);
                        return Value;
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
   end Locale_Config_Value;

   function Portable_Locale (Value : String) return Boolean is
      Raw  : constant String := Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
      Last : Natural := Raw'Last;
   begin
      if Raw'Length = 0 then
         return True;
      end if;

      for Index in Raw'Range loop
         if Raw (Index) = '.' or else Raw (Index) = '@' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      if Last < Raw'First then
         return True;
      end if;

      declare
         Base : constant String := Raw (Raw'First .. Last);
      begin
         return Base = "C" or else Base = "POSIX";
      end;
   end Portable_Locale;

   function Catalog_Root return String is
   begin
      if Ada.Directories.Exists ("share/files.catalog") then
         return "share";
      elsif Ada.Directories.Exists ("../../share/files.catalog") then
         return "../../share";
      elsif Ada.Directories.Exists ("../share/files.catalog") then
         return "../share";
      end if;

      return "share";
   end Catalog_Root;

   function Catalog_Path return String is
   begin
      return Catalog_Root & "/files.catalog";
   end Catalog_Path;

   function Locale_Catalog_Path (Locale : String) return String is
   begin
      return Catalog_Root & "/locales/files-" & Locale & ".catalog";
   end Locale_Catalog_Path;

   function Locale_Loaded (Locale : String) return Boolean is
   begin
      for Item of Loaded_Locales loop
         if To_String (Item) = Locale then
            return True;
         end if;
      end loop;

      return False;
   end Locale_Loaded;

   procedure Load_Locale (Locale : String) is
      Normalized : constant String := Normalize_Locale (Locale);
      Path       : constant String := Locale_Catalog_Path (Normalized);
   begin
      if not Available or else Locale_Loaded (Normalized) then
         return;
      end if;

      if Ada.Directories.Exists (Path) then
         I18N.Runtime.Load (Runtime, Path);
         Available := I18N.Runtime.Is_Valid (Runtime);
      end if;

      Loaded_Locales.Append (To_Unbounded_String (Normalized));

      for Index in Normalized'Range loop
         if Normalized (Index) = '-' then
            Load_Locale (Normalized (Normalized'First .. Index - 1));
            exit;
         end if;
      end loop;
   end Load_Locale;

   procedure Ensure_Initialized is
   begin
      if not Initialized then
         I18N.Runtime.Initialize (Runtime, Catalog_Path);
         Available := I18N.Runtime.Is_Valid (Runtime);
         Initialized := True;
         Load_Locale (System_Locale);
         Load_Locale (System_Time_Locale);
         Load_Locale (System_Number_Locale);
      end if;
   end Ensure_Initialized;

   function Text
     (Key    : String;
      Locale : String := "")
      return String
   is
      Effective_Locale : constant String :=
        (if Locale'Length = 0 then System_Locale else Normalize_Locale (Locale));
   begin
      Ensure_Initialized;
      Load_Locale (Effective_Locale);

      declare
         Rendered : constant String := Render_Text (Key, Effective_Locale);
      begin
         for Index in Effective_Locale'Range loop
            if Effective_Locale (Index) = '-' then
               declare
                  Language : constant String := Effective_Locale (Effective_Locale'First .. Index - 1);
                  Default_Rendered : constant String := Render_Text (Key, "en");
                  Language_Rendered : constant String := Render_Text (Key, Language);
               begin
                  if Language_Rendered /= Key
                    and then Language_Rendered /= Default_Rendered
                    and then (Rendered = Key or else Rendered = Default_Rendered)
                  then
                     return Language_Rendered;
                  end if;
               end;

               exit;
            end if;
         end loop;

         if Rendered /= Key then
            return Rendered;
         end if;
      end;

      for Index in Effective_Locale'Range loop
         if Effective_Locale (Index) = '-' then
            declare
               Language_Rendered : constant String :=
                 Render_Text (Key, Effective_Locale (Effective_Locale'First .. Index - 1));
            begin
               if Language_Rendered /= Key then
                  return Language_Rendered;
               end if;
            end;

            exit;
         end if;
      end loop;

      return Key;
   end Text;

   function Render_Text
     (Key    : String;
      Locale : String)
      return String
   is
      Args   : I18N.Arguments.Arguments;
      Result : I18N.Result.Render_Result;
   begin
      Ensure_Initialized;

      if not Available then
         return Key;
      end if;

      Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => Locale,
           Key       => Key,
           Arguments => Args);

      if Result.Status = I18N.Result.Success then
         return I18N.Result.Output_Text (Result.Text);
      end if;

      return Key;
   end Render_Text;

end Files.Localization;
