with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files.UTF8;

package body Files.Settings is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   type Settings_Section is
     (No_Section,
      Filetypes_Section,
      Icons_Section,
      Open_Actions_Section,
      Settings_Section_Name);

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   function Trim (Text : String) return String is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;

      function Is_Settings_Space (Value : Character) return Boolean is
      begin
         return Value = ' ' or else Value = ASCII.HT or else Value = ASCII.CR;
      end Is_Settings_Space;
   begin
      while First <= Last and then Is_Settings_Space (Text (First)) loop
         First := First + 1;
      end loop;

      while Last >= First and then Is_Settings_Space (Text (Last)) loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      end if;

      return Text (First .. Last);
   end Trim;

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   function Contains_Line_Break (Text : String) return Boolean is
      Index     : Integer := Text'First;
      Codepoint : Natural := 0;
   begin
      while Index <= Text'Last loop
         declare
            Byte_Value : constant Natural := Character'Pos (Text (Index));
         begin
            if Byte_Value = Character'Pos (ASCII.LF)
              or else Byte_Value = Character'Pos (ASCII.CR)
              or else Byte_Value = Character'Pos (ASCII.VT)
              or else Byte_Value = Character'Pos (ASCII.FF)
              or else Byte_Value = 133
            then
               return True;
            end if;
         end;

         Files.UTF8.Decode_Next_Codepoint (Text, Index, Codepoint);
         if Codepoint = Character'Pos (ASCII.LF)
           or else Codepoint = Character'Pos (ASCII.CR)
           or else Codepoint = Character'Pos (ASCII.VT)
           or else Codepoint = Character'Pos (ASCII.FF)
           or else Codepoint = 16#0085#
           or else Codepoint = 16#2028#
           or else Codepoint = 16#2029#
         then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Line_Break;

   function Mapping_Key_Is_Valid (Text : String) return Boolean is
   begin
      return Text /= ""
        and then not Contains_Line_Break (Text)
        and then Ada.Strings.Fixed.Index (Text, "=") = 0;
   end Mapping_Key_Is_Valid;

   function Mapping_Value_Is_Valid (Text : String) return Boolean is
   begin
      return Text /= "" and then not Contains_Line_Break (Text);
   end Mapping_Value_Is_Valid;

   function Is_Whole_Placeholder (Text : String) return Boolean is
   begin
      return Text = "{path}"
        or else Text = "{parent}"
        or else Text = "{name}"
        or else Text = "{stem}"
        or else Text = "{extension}";
   end Is_Whole_Placeholder;

   function Contains_Known_Placeholder (Text : String) return Boolean is
   begin
      return Contains (Text, "{path}")
        or else Contains (Text, "{parent}")
        or else Contains (Text, "{name}")
        or else Contains (Text, "{stem}")
        or else Contains (Text, "{extension}");
   end Contains_Known_Placeholder;

   function Strip_Quotes (Text : String) return String is
      Clean : constant String := Trim (Text);
      Value : Unbounded_String := Null_Unbounded_String;
      Index : Natural;
   begin
      if Clean'Length >= 2
        and then Clean (Clean'First) = '"'
        and then Clean (Clean'Last) = '"'
      then
         Index := Clean'First + 1;
         while Index < Clean'Last loop
            if Clean (Index) = '"'
              and then Index + 1 < Clean'Last
              and then Clean (Index + 1) = '"'
            then
               Append (Value, '"');
               Index := Index + 2;
            else
               Append (Value, Clean (Index));
               Index := Index + 1;
            end if;
         end loop;

         return To_String (Value);
      end if;

      return Clean;
   end Strip_Quotes;

   function Quoted_Value_Is_Valid (Text : String) return Boolean is
      Clean : constant String := Trim (Text);
      Index : Natural;
   begin
      if Clean = "" then
         return True;
      elsif Clean (Clean'First) /= '"' then
         return Ada.Strings.Fixed.Index (Clean, """") = 0;
      elsif Clean'Length < 2 or else Clean (Clean'Last) /= '"' then
         return False;
      end if;

      Index := Clean'First + 1;
      while Index < Clean'Last loop
         if Clean (Index) = '"' then
            if Index + 1 < Clean'Last and then Clean (Index + 1) = '"' then
               Index := Index + 2;
            else
               return False;
            end if;
         else
            Index := Index + 1;
         end if;
      end loop;

      return True;
   end Quoted_Value_Is_Valid;

   function Parent_Directory (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      return Ada.Directories.Containing_Directory (Path);
   exception
      when others =>
         return "";
   end Parent_Directory;

   function Icon_Theme_Name_Is_Valid (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "files-basic" or else Clean = "files-high-contrast";
   end Icon_Theme_Name_Is_Valid;

   function Next_Action_Token
     (Text  : String;
      Start : Positive;
      Last  : out Natural;
      Found : out Boolean;
      Valid : out Boolean)
      return String
   is
      First : Natural := Start;
      Value : Unbounded_String := Null_Unbounded_String;
   begin
      Found := False;
      Valid := True;
      while First <= Text'Last
        and then (Text (First) = ' ' or else Text (First) = ASCII.HT)
      loop
         First := First + 1;
      end loop;

      if First > Text'Last then
         Last := Text'Last + 1;
         return "";
      end if;

      if Text (First) = '"' then
         Found := True;
         Last := First + 1;
         loop
            if Last > Text'Last then
               Valid := False;
               return "";
            elsif Text (Last) = '"' then
               if Last < Text'Last and then Text (Last + 1) = '"' then
                  Append (Value, '"');
                  Last := Last + 2;
               else
                  exit;
               end if;
            else
               Append (Value, Text (Last));
               Last := Last + 1;
            end if;
         end loop;

         Last := Last + 1;
         if Last <= Text'Last
           and then Text (Last) /= ' '
           and then Text (Last) /= ASCII.HT
         then
            Valid := False;
            return "";
         end if;

         return To_String (Value);
      else
         Found := True;
         Last := First;
         while Last <= Text'Last
           and then Text (Last) /= ' '
           and then Text (Last) /= ASCII.HT
         loop
            if Text (Last) = '"' then
               Valid := False;
               return "";
            end if;
            Last := Last + 1;
         end loop;

         return Text (First .. Last - 1);
      end if;
   end Next_Action_Token;

   function Parse_Action (Text : String) return Open_Action is
      Clean     : Unbounded_String := To_Unbounded_String (Trim (Text));
      Use_Shell : Boolean := False;
      Position  : Positive;
      Last      : Natural;
      Found     : Boolean;
      Valid     : Boolean;
      Args      : String_Vectors.Vector;
      Program   : Unbounded_String := Null_Unbounded_String;
   begin
      if Starts_With (Files.Types.To_Lower (To_String (Clean)), "shell:") then
         Use_Shell := True;
         if Length (Clean) > 6 then
            Clean := To_Unbounded_String (Trim (To_String (Clean) (7 .. Length (Clean))));
         else
            Clean := Null_Unbounded_String;
         end if;
      end if;

      if To_String (Clean) = "" then
         return Make_Action ("", Args, Use_Shell);
      end if;

      declare
         Clean_Text : constant String := To_String (Clean);
      begin
         Position := Clean_Text'First;
         declare
            Token : constant String := Next_Action_Token (Clean_Text, Position, Last, Found, Valid);
         begin
            if not Valid or else not Found then
               return Make_Action ("", Args, Use_Shell);
            end if;
            Program := To_Unbounded_String (Token);
            Position := Last;
         end;

         while Position <= Clean_Text'Last loop
            declare
               Token : constant String := Next_Action_Token (Clean_Text, Position, Last, Found, Valid);
            begin
               if not Valid then
                  return Make_Action ("", Args, Use_Shell);
               end if;
               exit when not Found;
               Args.Append (To_Unbounded_String (Token));
               Position := Last;
            end;
         end loop;
      end;

      return
        (Executable => Program,
         Arguments  => Args,
         Use_Shell  => Use_Shell);
   end Parse_Action;

   function Default_Settings return Settings_Model is
      Settings : Settings_Model;
      Args     : String_Vectors.Vector;
   begin
      Settings.Icon_Theme_Name := To_Unbounded_String ("files-basic");
      Add_Extension_Mapping (Settings, "txt", "text/plain");
      Add_Extension_Mapping (Settings, "adb", "text/x-ada");
      Add_Extension_Mapping (Settings, "ads", "text/x-ada");
      Add_Extension_Mapping (Settings, "md", "text/markdown");
      Add_Extension_Mapping (Settings, "json", "application/json");
      Add_Extension_Mapping (Settings, "xml", "application/xml");
      Add_Extension_Mapping (Settings, "png", "image/png");
      Add_Extension_Mapping (Settings, "jpg", "image/jpeg");
      Add_Extension_Mapping (Settings, "jpeg", "image/jpeg");
      Add_Extension_Mapping (Settings, "pdf", "application/pdf");
      Add_Extension_Mapping (Settings, "zip", "application/zip");
      Add_Extension_Mapping
        (Settings,
         "docx",
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
      Add_Extension_Mapping (Settings, "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      Add_Extension_Mapping (Settings, "tar", "application/x-tar");
      Add_Extension_Mapping (Settings, "tar.gz", "application/gzip-tar");
      Add_Extension_Mapping (Settings, "gz", "application/gzip");
      Add_Extension_Mapping (Settings, "mp3", "audio/mpeg");
      Add_Extension_Mapping (Settings, "wav", "audio/wav");
      Add_Extension_Mapping (Settings, "mp4", "video/mp4");

      Add_Icon_Mapping (Settings, "inode/directory", "folder");
      Add_Icon_Mapping (Settings, "inode/symlink", "link");
      Add_Icon_Mapping (Settings, "application/x-executable", "executable");
      Add_Icon_Mapping (Settings, "text/plain", "text");
      Add_Icon_Mapping (Settings, "text/x-ada", "ada");
      Add_Icon_Mapping (Settings, "text/markdown", "text");
      Add_Icon_Mapping (Settings, "application/json", "text");
      Add_Icon_Mapping (Settings, "application/xml", "text");
      Add_Icon_Mapping (Settings, "image/png", "image");
      Add_Icon_Mapping (Settings, "image/jpeg", "image");
      Add_Icon_Mapping (Settings, "application/pdf", "text");
      Add_Icon_Mapping (Settings, "application/zip", "unknown");
      Add_Icon_Mapping (Settings, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text");
      Add_Icon_Mapping (Settings, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "text");
      Add_Icon_Mapping (Settings, "application/x-tar", "unknown");
      Add_Icon_Mapping (Settings, "application/gzip-tar", "unknown");
      Add_Icon_Mapping (Settings, "application/gzip", "unknown");
      Add_Icon_Mapping (Settings, "audio/mpeg", "unknown");
      Add_Icon_Mapping (Settings, "audio/wav", "unknown");
      Add_Icon_Mapping (Settings, "video/mp4", "unknown");
      Add_Icon_Mapping (Settings, "application/octet-stream", "unknown");

      Args.Append (To_Unbounded_String ("{path}"));
      Add_Open_Action (Settings, "text/plain", Make_Action ("xdg-open", Args));
      return Settings;
   end Default_Settings;

   function Has_Embedded_Placeholder
     (Argument : String)
      return Boolean
   is
   begin
      return Contains_Known_Placeholder (Argument)
        and then not Is_Whole_Placeholder (Argument);
   end Has_Embedded_Placeholder;

   function Has_Embedded_Placeholder
     (Action : Open_Action)
      return Boolean
   is
   begin
      for Argument of Action.Arguments loop
         if Has_Embedded_Placeholder (To_String (Argument)) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Embedded_Placeholder;

   function Has_Unsafe_Placeholder_Usage
     (Action : Open_Action)
      return Boolean is
   begin
      return Contains_Known_Placeholder (To_String (Action.Executable))
        or else Has_Embedded_Placeholder (Action);
   end Has_Unsafe_Placeholder_Usage;

   function Action_Text_Is_Serializable
     (Action : Open_Action)
      return Boolean is
   begin
      if Contains_Line_Break (To_String (Action.Executable)) then
         return False;
      end if;

      for Argument of Action.Arguments loop
         if Contains_Line_Break (To_String (Argument)) then
            return False;
         end if;
      end loop;

      return True;
   end Action_Text_Is_Serializable;

   procedure Add_Extension_Mapping
     (Settings  : in out Settings_Model;
      Extension : String;
      Filetype  : String)
   is
      Key : constant String := Normalize_Extension (Extension);
      Value : constant String := Trim (Filetype);
   begin
      if not Mapping_Key_Is_Valid (Key) or else not Mapping_Value_Is_Valid (Value) then
         return;
      end if;

      if Settings.Extension_Filetypes.Contains (Key) then
         Settings.Extension_Filetypes.Replace (Key, Value);
      else
         Settings.Extension_Filetypes.Insert (Key, Value);
      end if;
   end Add_Extension_Mapping;

   procedure Add_Icon_Mapping
     (Settings : in out Settings_Model;
      Filetype : String;
      Icon     : String) is
      Key : constant String := Trim (Filetype);
      Value : constant String := Trim (Icon);
   begin
      if not Mapping_Key_Is_Valid (Key) or else not Mapping_Value_Is_Valid (Value) then
         return;
      end if;

      if Settings.Icon_Mappings.Contains (Key) then
         Settings.Icon_Mappings.Replace (Key, Value);
      else
         Settings.Icon_Mappings.Insert (Key, Value);
      end if;
   end Add_Icon_Mapping;

   function Modifier_Name_Is_Known (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "shift"
        or else Clean = "control"
        or else Clean = "alt"
        or else Clean = "meta";
   end Modifier_Name_Is_Known;

   function Structured_Filetype_Suffix_Is_Known (Name : String) return Boolean is
      Clean : constant String := Files.Types.To_Lower (Trim (Name));
   begin
      return Clean = "json"
        or else Clean = "xml"
        or else Clean = "zip"
        or else Clean = "gzip";
   end Structured_Filetype_Suffix_Is_Known;

   function Plus_Suffix_Is_Structured_Filetype (Token : String) return Boolean is
      Clean : constant String := Trim (Token);
      Plus  : Natural := 0;
   begin
      for Index in Clean'Range loop
         if Clean (Index) = '+' then
            Plus := Index;
         end if;
      end loop;

      return Plus > Clean'First
        and then Plus < Clean'Last
        and then Structured_Filetype_Suffix_Is_Known (Clean (Plus + 1 .. Clean'Last));
   end Plus_Suffix_Is_Structured_Filetype;

   function Modifier_Suffix_Start (Token : String) return Natural is
      Clean     : constant String := Trim (Token);
      Candidate : Natural := Ada.Strings.Fixed.Index (Clean, "+");
   begin
      while Candidate /= 0 loop
         declare
            Position : Natural := Candidate + 1;
            Valid    : Boolean :=
              Candidate > Clean'First
              and then Candidate < Clean'Last
              and then Clean (Candidate - 1) /= '+';
         begin
            while Valid and then Position <= Clean'Last loop
               declare
                  Last : Natural := Position;
               begin
                  while Last <= Clean'Last and then Clean (Last) /= '+' loop
                     Last := Last + 1;
                  end loop;

                  if Last = Position
                    or else not Modifier_Name_Is_Known (Clean (Position .. Last - 1))
                  then
                     Valid := False;
                  end if;

                  Position := Last + 1;
               end;
            end loop;

            if Valid then
               return Candidate;
            end if;
         end;

         if Candidate = Clean'Last then
            return 0;
         end if;

         declare
            Next : Natural := 0;
         begin
            for Index in Candidate + 1 .. Clean'Last loop
               if Clean (Index) = '+' then
                  Next := Index;
                  exit;
               end if;
            end loop;
            Candidate := Next;
         end;
      end loop;

      return 0;
   end Modifier_Suffix_Start;

   function Normalize_Action_Token (Token : String) return String is
      Clean : constant String := Trim (Token);
      Plus  : constant Natural := Modifier_Suffix_Start (Clean);
   begin
      if Plus = 0 then
         return Clean;
      end if;

      declare
         Filetype  : constant String := Trim (Clean (Clean'First .. Plus - 1));
         Position  : Natural := Plus + 1;
         Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
         Unknowns  : Unbounded_String := Null_Unbounded_String;

         procedure Add_Modifier (Text : String) is
            Name : constant String := Files.Types.To_Lower (Trim (Text));
         begin
            if Name = "shift" then
               Modifiers (Files.Types.Shift_Key) := True;
            elsif Name = "control" then
               Modifiers (Files.Types.Control_Key) := True;
            elsif Name = "alt" then
               Modifiers (Files.Types.Alt_Key) := True;
            elsif Name = "meta" then
               Modifiers (Files.Types.Meta_Key) := True;
            elsif Name /= "" then
               Append (Unknowns, "+");
               Append (Unknowns, Name);
            end if;
         end Add_Modifier;
      begin
         while Position <= Clean'Last loop
            declare
               Last : Natural := Position;
            begin
               while Last <= Clean'Last and then Clean (Last) /= '+' loop
                  Last := Last + 1;
               end loop;

               if Last > Position then
                  Add_Modifier (Clean (Position .. Last - 1));
               end if;

               Position := Last + 1;
            end;
         end loop;

         return Filetype & Modifier_Token (Modifiers) & To_String (Unknowns);
      end;
   end Normalize_Action_Token;

   function Action_Token_Modifiers_Are_Known (Token : String) return Boolean is
      Clean    : constant String := Trim (Token);
      Plus     : constant Natural := Modifier_Suffix_Start (Clean);
      Position : Natural := Plus + 1;
   begin
      if Plus = 0 then
         return Ada.Strings.Fixed.Index (Clean, "+") = 0
           or else Plus_Suffix_Is_Structured_Filetype (Clean);
      elsif Plus = Clean'Last or else Clean (Clean'Last) = '+' then
         return False;
      end if;

      while Position <= Clean'Last loop
         declare
            Last : Natural := Position;
         begin
            while Last <= Clean'Last and then Clean (Last) /= '+' loop
               Last := Last + 1;
            end loop;

            if Last = Position then
               return False;
            else
               declare
                  Name : constant String := Files.Types.To_Lower (Trim (Clean (Position .. Last - 1)));
               begin
                  if Name /= "shift"
                    and then Name /= "control"
                    and then Name /= "alt"
                    and then Name /= "meta"
                  then
                     return False;
                  end if;
               end;
            end if;

            Position := Last + 1;
         end;
      end loop;

      return True;
   end Action_Token_Modifiers_Are_Known;

   function Open_Action_Base_Key_Is_Valid (Text : String) return Boolean is
      Clean : constant String := Trim (Text);
   begin
      if not Mapping_Key_Is_Valid (Clean) then
         return False;
      end if;

      for Character_Value of Clean loop
         if Character_Value = ' '
           or else Character_Value = ASCII.HT
           or else Character_Value = '"'
           or else Character_Value = '['
           or else Character_Value = ']'
         then
            return False;
         end if;
      end loop;

      return True;
   end Open_Action_Base_Key_Is_Valid;

   procedure Add_Open_Action
     (Settings : in out Settings_Model;
      Token    : String;
      Action   : Open_Action)
   is
      Key : constant String := Normalize_Action_Token (Token);
      Plus : constant Natural := Modifier_Suffix_Start (Key);
      Clean_Action : Open_Action := Action;
   begin
      if Key = ""
        or else (Plus = Key'First)
        or else not Open_Action_Base_Key_Is_Valid ((if Plus = 0 then Key else Key (Key'First .. Plus - 1)))
        or else not Action_Token_Modifiers_Are_Known (Token)
        or else Trim (To_String (Action.Executable)) = ""
        or else Has_Unsafe_Placeholder_Usage (Action)
        or else not Action_Text_Is_Serializable (Action)
      then
         return;
      end if;

      Clean_Action.Executable := To_Unbounded_String (Trim (To_String (Action.Executable)));

      if Settings.Open_Actions.Contains (Key) then
         Settings.Open_Actions.Replace (Key, Clean_Action);
      else
         Settings.Open_Actions.Insert (Key, Clean_Action);
      end if;
   end Add_Open_Action;

   function Filetype_For_Extension
     (Settings  : Settings_Model;
      Extension : String)
      return String
   is
      Key : constant String := Normalize_Extension (Extension);
   begin
      if Settings.Extension_Filetypes.Contains (Key) then
         return Settings.Extension_Filetypes.Element (Key);
      end if;

      return "";
   end Filetype_For_Extension;

   function Icon_For_Filetype
     (Settings : Settings_Model;
      Filetype : String)
      return String
   is
      Key : constant String := Trim (Filetype);
   begin
      if Settings.Icon_Mappings.Contains (Key) then
         return Settings.Icon_Mappings.Element (Key);
      end if;

      return "";
   end Icon_For_Filetype;

   function Modifier_Token
     (Modifiers : Files.Types.Modifier_Set)
      return String
   is
      Result : Unbounded_String := Null_Unbounded_String;

      procedure Add (Name : String) is
      begin
         Append (Result, "+");
         Append (Result, Name);
      end Add;
   begin
      if Modifiers (Files.Types.Shift_Key) then
         Add ("shift");
      end if;
      if Modifiers (Files.Types.Control_Key) then
         Add ("control");
      end if;
      if Modifiers (Files.Types.Alt_Key) then
         Add ("alt");
      end if;
      if Modifiers (Files.Types.Meta_Key) then
         Add ("meta");
      end if;

      return To_String (Result);
   end Modifier_Token;

   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Files.Types.Modifier_Set)
      return Action_Lookup_Result
   is
      Base_Token : constant String := Trim (Filetype);
      Full_Token : constant String := Base_Token & Modifier_Token (Modifiers);
   begin
      if Base_Token = "" then
         return
           (Found     => False,
            Action    => Make_Action ("", String_Vectors.Empty_Vector),
            Token     => Null_Unbounded_String,
            Error_Key => To_Unbounded_String ("error.open_action.missing"));
      end if;

      if Settings.Open_Actions.Contains (Full_Token) then
         return
           (Found     => True,
            Action    => Settings.Open_Actions.Element (Full_Token),
            Token     => To_Unbounded_String (Full_Token),
            Error_Key => Null_Unbounded_String);
      elsif Settings.Open_Actions.Contains (Base_Token) then
         return
           (Found     => True,
            Action    => Settings.Open_Actions.Element (Base_Token),
            Token     => To_Unbounded_String (Base_Token),
            Error_Key => Null_Unbounded_String);
      end if;

      return
        (Found     => False,
         Action    => Make_Action ("", String_Vectors.Empty_Vector),
         Token     => To_Unbounded_String (Full_Token),
         Error_Key => To_Unbounded_String ("error.open_action.missing"));
   end Lookup_Open_Action;

   function Parse
     (Text : String)
      return Settings_Parse_Result
   is
      Settings   : Settings_Model := Default_Settings;
      Section    : Settings_Section := No_Section;
      Line_First : Positive := Text'First;
      Line_Last  : Natural;
   begin
      if Text = "" then
         return
           (Success   => True,
            Settings  => Settings,
            Error_Key => Null_Unbounded_String);
      end if;

      while Line_First <= Text'Last loop
         Line_Last := Line_First;
         while Line_Last <= Text'Last and then Text (Line_Last) /= ASCII.LF loop
            Line_Last := Line_Last + 1;
         end loop;

         declare
            Raw_Line : constant String := Text (Line_First .. Line_Last - 1);
            Line     : constant String := Trim (Raw_Line);
            Equals   : Natural;
         begin
            if Line = "" or else Line (Line'First) = '#' then
               null;
            elsif Line (Line'First) = '[' and then Line (Line'Last) = ']' then
               declare
                  Name : constant String :=
                    Files.Types.To_Lower (Trim (Line (Line'First + 1 .. Line'Last - 1)));
               begin
                  if Name = "filetypes" then
                     Section := Filetypes_Section;
                  elsif Name = "icons" then
                     Section := Icons_Section;
                  elsif Name = "open-actions" then
                     Section := Open_Actions_Section;
                  elsif Name = "settings" then
                     Section := Settings_Section_Name;
                  else
                     return
                       (Success   => False,
                        Settings  => Settings,
                        Error_Key => To_Unbounded_String ("error.settings.unknown_section"));
                  end if;
               end;
            else
               Equals := Ada.Strings.Fixed.Index (Line, "=");
               if Equals = 0 then
                  return
                    (Success   => False,
                     Settings  => Settings,
                     Error_Key => To_Unbounded_String ("error.settings.expected_equals"));
               end if;

               declare
                  Key       : constant String := Trim (Line (Line'First .. Equals - 1));
                  Setting_Key : constant String := Files.Types.To_Lower (Key);
                  Raw_Value : constant String := Trim (Line (Equals + 1 .. Line'Last));
                  Value     : constant String := Strip_Quotes (Raw_Value);
               begin
                  case Section is
                     when Filetypes_Section =>
                        if Normalize_Extension (Key) = ""
                          or else Value = ""
                          or else not Mapping_Key_Is_Valid (Normalize_Extension (Key))
                          or else not Mapping_Value_Is_Valid (Value)
                          or else not Quoted_Value_Is_Valid (Raw_Value)
                        then
                           return
                             (Success   => False,
                              Settings  => Settings,
                              Error_Key => To_Unbounded_String ("error.settings.invalid_mapping"));
                        end if;
                        Add_Extension_Mapping (Settings, Key, Value);
                     when Icons_Section =>
                        if Key = ""
                          or else Value = ""
                          or else not Mapping_Key_Is_Valid (Key)
                          or else not Mapping_Value_Is_Valid (Value)
                          or else not Quoted_Value_Is_Valid (Raw_Value)
                        then
                           return
                             (Success   => False,
                              Settings  => Settings,
                              Error_Key => To_Unbounded_String ("error.settings.invalid_mapping"));
                        end if;
                        Add_Icon_Mapping (Settings, Key, Value);
                     when Open_Actions_Section =>
                        declare
                           Normalized_Key : constant String := Normalize_Action_Token (Key);
                           Action : constant Open_Action := Parse_Action (Raw_Value);
                           Plus   : constant Natural := Modifier_Suffix_Start (Normalized_Key);
                        begin
                           if Key = ""
                             or else Normalized_Key = ""
                             or else (Plus = Normalized_Key'First)
                             or else not Open_Action_Base_Key_Is_Valid
                               ((if Plus = 0
                                 then Normalized_Key
                                 else Normalized_Key (Normalized_Key'First .. Plus - 1)))
                             or else not Action_Token_Modifiers_Are_Known (Key)
                             or else To_String (Action.Executable) = ""
                             or else Has_Unsafe_Placeholder_Usage (Action)
                             or else not Action_Text_Is_Serializable (Action)
                           then
                              return
                                (Success   => False,
                                 Settings  => Settings,
                                 Error_Key => To_Unbounded_String ("error.settings.invalid_open_action"));
                           end if;
                           Add_Open_Action (Settings, Key, Action);
                        end;
                     when Settings_Section_Name =>
                        if Setting_Key = "default_view_mode" then
                           declare
                              Mode : constant String := Files.Types.To_Lower (Value);
                           begin
                              if Mode = "small" or else Mode = "small_icons" then
                                 Settings.Default_View := Files.Types.Small_Icons;
                              elsif Mode = "large" or else Mode = "large_icons" then
                                 Settings.Default_View := Files.Types.Large_Icons;
                              elsif Mode = "details" then
                                 Settings.Default_View := Files.Types.Details;
                              else
                                 return
                                   (Success   => False,
                                    Settings  => Settings,
                                    Error_Key => To_Unbounded_String ("error.settings.invalid_view_mode"));
                              end if;
                           end;
                        elsif Setting_Key = "show_hidden_files" then
                           declare
                              Boolean_Value : constant String := Files.Types.To_Lower (Value);
                           begin
                              if Boolean_Value = "true" then
                                 Settings.Show_Hidden_Files := True;
                              elsif Boolean_Value = "false" then
                                 Settings.Show_Hidden_Files := False;
                              else
                                 return
                                   (Success   => False,
                                    Settings  => Settings,
                                    Error_Key => To_Unbounded_String ("error.settings.invalid_boolean"));
                              end if;
                           end;
                        elsif Setting_Key = "sort_field" then
                           declare
                              Field : constant String := Files.Types.To_Lower (Value);
                           begin
                              if Field = "name" then
                                 Settings.Sort_Field_Value := Sort_By_Name;
                              elsif Field = "filetype" then
                                 Settings.Sort_Field_Value := Sort_By_Filetype;
                              elsif Field = "size" then
                                 Settings.Sort_Field_Value := Sort_By_Size;
                              elsif Field = "modified" then
                                 Settings.Sort_Field_Value := Sort_By_Modified;
                              else
                                 return
                                   (Success   => False,
                                    Settings  => Settings,
                                    Error_Key => To_Unbounded_String ("error.settings.invalid_sort_field"));
                              end if;
                           end;
                        elsif Setting_Key = "sort_ascending" then
                           declare
                              Boolean_Value : constant String := Files.Types.To_Lower (Value);
                           begin
                              if Boolean_Value = "true" then
                                 Settings.Sort_Ascending := True;
                              elsif Boolean_Value = "false" then
                                 Settings.Sort_Ascending := False;
                              else
                                 return
                                   (Success   => False,
                                    Settings  => Settings,
                                    Error_Key => To_Unbounded_String ("error.settings.invalid_boolean"));
                              end if;
                           end;
                        elsif Setting_Key = "high_contrast_theme" then
                           declare
                              Boolean_Value : constant String := Files.Types.To_Lower (Value);
                           begin
                              if Boolean_Value = "true" then
                                 Settings.High_Contrast_Theme := True;
                              elsif Boolean_Value = "false" then
                                 Settings.High_Contrast_Theme := False;
                              else
                                 return
                                   (Success   => False,
                                    Settings  => Settings,
                                     Error_Key => To_Unbounded_String ("error.settings.invalid_boolean"));
                              end if;
                           end;
                        elsif Setting_Key = "icon_theme" then
                           if Icon_Theme_Name_Is_Valid (Value) then
                              Settings.Icon_Theme_Name := To_Unbounded_String (Files.Types.To_Lower (Value));
                           else
                              return
                                (Success   => False,
                                 Settings  => Settings,
                                 Error_Key => To_Unbounded_String ("error.settings.invalid_icon_theme"));
                           end if;
                        else
                           return
                             (Success   => False,
                              Settings  => Settings,
                              Error_Key => To_Unbounded_String ("error.settings.unknown_key"));
                        end if;
                     when No_Section =>
                        return
                          (Success   => False,
                           Settings  => Settings,
                           Error_Key => To_Unbounded_String ("error.settings.missing_section"));
                  end case;
               end;
            end if;
         end;

         Line_First := Line_Last + 1;
      end loop;

      return
        (Success   => True,
         Settings  => Settings,
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Settings  => Settings,
            Error_Key => To_Unbounded_String ("error.settings.invalid"));
   end Parse;

   function Load_File
     (Path : String)
      return Settings_Parse_Result
   is
      File : Ada.Text_IO.File_Type;
      Text : Unbounded_String := Null_Unbounded_String;
   begin
      if Path = "" then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
      elsif not Ada.Directories.Exists (Path) then
         return
           (Success   => True,
            Settings  => Default_Settings,
            Error_Key => Null_Unbounded_String);
      elsif Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Text, Ada.Text_IO.Get_Line (File));
         Append (Text, ASCII.LF);
      end loop;
      Safe_Close (File);

      return Parse (To_String (Text));
   exception
      when others =>
         Safe_Close (File);

         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.load"));
   end Load_File;

   function Default_Settings_Text return String is
   begin
      return To_Text (Default_Settings);
   end Default_Settings_Text;

   function View_Mode_Name (Mode : Files.Types.View_Mode) return String is
   begin
      case Mode is
         when Files.Types.Small_Icons =>
            return "small_icons";
         when Files.Types.Large_Icons =>
            return "large_icons";
         when Files.Types.Details =>
            return "details";
      end case;
   end View_Mode_Name;

   function Sort_Field_Name (Field : Sort_Field) return String is
   begin
      case Field is
         when Sort_By_Name =>
            return "name";
         when Sort_By_Filetype =>
            return "filetype";
         when Sort_By_Size =>
            return "size";
         when Sort_By_Modified =>
            return "modified";
      end case;
   end Sort_Field_Name;

   function Boolean_Name (Value : Boolean) return String is
   begin
      return (if Value then "true" else "false");
   end Boolean_Name;

   function Action_Token_Text (Value : String) return String is
      Needs_Quotes : Boolean := Value = "";
      Result       : Unbounded_String := Null_Unbounded_String;
   begin
      for Character_Value of Value loop
         if Character_Value = ' ' or else Character_Value = ASCII.HT then
            Needs_Quotes := True;
         elsif Character_Value = '"' then
            Needs_Quotes := True;
         end if;
      end loop;

      if not Needs_Quotes then
         return Value;
      end if;

      Append (Result, '"');
      for Character_Value of Value loop
         if Character_Value = '"' then
            Append (Result, """""");
         else
            Append (Result, Character_Value);
         end if;
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Action_Token_Text;

   function Action_Text (Action : Open_Action) return String is
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      if Action.Use_Shell then
         Append (Result, "shell:");
      end if;

      Append (Result, Action_Token_Text (To_String (Action.Executable)));
      for Argument of Action.Arguments loop
         Append (Result, " ");
         Append (Result, Action_Token_Text (To_String (Argument)));
      end loop;

      return To_String (Result);
   end Action_Text;

   procedure Sort (Keys : in out String_Vectors.Vector) is
      function Less (Left : UString; Right : UString) return Boolean is
      begin
         return To_String (Left) < To_String (Right);
      end Less;

      package Sorting is new String_Vectors.Generic_Sorting ("<" => Less);
   begin
      Sorting.Sort (Keys);
   end Sort;

   function To_Text
     (Settings : Settings_Model)
      return String
   is
      Result : Unbounded_String := Null_Unbounded_String;
      Keys   : String_Vectors.Vector;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      Append_Line ("[settings]");
      Append_Line ("default_view_mode = " & View_Mode_Name (Settings.Default_View));
      Append_Line ("show_hidden_files = " & Boolean_Name (Settings.Show_Hidden_Files));
      Append_Line ("sort_field = " & Sort_Field_Name (Settings.Sort_Field_Value));
      Append_Line ("sort_ascending = " & Boolean_Name (Settings.Sort_Ascending));
      Append_Line ("high_contrast_theme = " & Boolean_Name (Settings.High_Contrast_Theme));
      Append_Line ("icon_theme = " & Action_Token_Text (To_String (Settings.Icon_Theme_Name)));
      Append_Line;

      Append_Line ("[filetypes]");
      Keys.Clear;
      for Cursor in Settings.Extension_Filetypes.Iterate loop
         Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line
           (To_String (Key) & " = "
            & Action_Token_Text (Settings.Extension_Filetypes.Element (To_String (Key))));
      end loop;
      Append_Line;

      Append_Line ("[icons]");
      Keys.Clear;
      for Cursor in Settings.Icon_Mappings.Iterate loop
         Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line
           (To_String (Key) & " = "
            & Action_Token_Text (Settings.Icon_Mappings.Element (To_String (Key))));
      end loop;
      Append_Line;

      Append_Line ("[open-actions]");
      Keys.Clear;
      for Cursor in Settings.Open_Actions.Iterate loop
         Keys.Append (To_Unbounded_String (Action_Maps.Key (Cursor)));
      end loop;
      Sort (Keys);
      for Key of Keys loop
         Append_Line (To_String (Key) & " = " & Action_Text (Settings.Open_Actions.Element (To_String (Key))));
      end loop;

      return To_String (Result);
   end To_Text;

   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft is
      Extension     : Unbounded_String := Null_Unbounded_String;
      Filetype      : Unbounded_String := Null_Unbounded_String;
      Icon_Filetype : Unbounded_String := Null_Unbounded_String;
      Icon          : Unbounded_String := Null_Unbounded_String;
      Token         : Unbounded_String := Null_Unbounded_String;
      Command       : Unbounded_String := Null_Unbounded_String;
      Filetype_Keys : String_Vectors.Vector;
      Filetype_Values : String_Vectors.Vector;
      Icon_Keys     : String_Vectors.Vector;
      Icon_Values   : String_Vectors.Vector;
      Action_Keys   : String_Vectors.Vector;
      Action_Values : String_Vectors.Vector;
   begin
      if not Settings.Extension_Filetypes.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Extension_Filetypes.Iterate loop
               Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Filetype_Keys.Append (Key);
               Filetype_Values.Append (To_Unbounded_String (Settings.Extension_Filetypes.Element (To_String (Key))));
            end loop;
            Extension := Filetype_Keys.Element (1);
            Filetype := Filetype_Values.Element (1);
         end;
      end if;

      if not Settings.Icon_Mappings.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Icon_Mappings.Iterate loop
               Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Icon_Keys.Append (Key);
               Icon_Values.Append (To_Unbounded_String (Settings.Icon_Mappings.Element (To_String (Key))));
            end loop;
            Icon_Filetype := Icon_Keys.Element (1);
            Icon := Icon_Values.Element (1);
         end;
      end if;

      if not Settings.Open_Actions.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Open_Actions.Iterate loop
               Keys.Append (To_Unbounded_String (Action_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Action_Keys.Append (Key);
               Action_Values.Append
                 (To_Unbounded_String (Action_Text (Settings.Open_Actions.Element (To_String (Key)))));
            end loop;
            Token := Action_Keys.Element (1);
            Command := Action_Values.Element (1);
         end;
      end if;

      return
        (Default_View_Mode      => To_Unbounded_String (View_Mode_Name (Settings.Default_View)),
         Show_Hidden_Files      => To_Unbounded_String (Boolean_Name (Settings.Show_Hidden_Files)),
         Sort_Field_Value       => To_Unbounded_String (Sort_Field_Name (Settings.Sort_Field_Value)),
         Sort_Ascending         => To_Unbounded_String (Boolean_Name (Settings.Sort_Ascending)),
         High_Contrast_Theme    => To_Unbounded_String (Boolean_Name (Settings.High_Contrast_Theme)),
         Icon_Theme_Name        => Settings.Icon_Theme_Name,
         Filetype_Extension     => Extension,
         Filetype_Value         => Filetype,
         Filetype_Keys          => Filetype_Keys,
         Filetype_Values        => Filetype_Values,
         Filetype_Index         => (if Filetype_Keys.Is_Empty then 0 else 1),
         Icon_Filetype          => Icon_Filetype,
         Icon_Value             => Icon,
         Icon_Keys              => Icon_Keys,
         Icon_Values            => Icon_Values,
         Icon_Index             => (if Icon_Keys.Is_Empty then 0 else 1),
         Open_Action_Token      => Token,
         Open_Action_Command    => Command,
         Open_Action_Keys       => Action_Keys,
         Open_Action_Commands   => Action_Values,
         Open_Action_Index      => (if Action_Keys.Is_Empty then 0 else 1),
         Error_Key              => Null_Unbounded_String,
         Valid                  => True);
   end Make_Draft;

   function Draft_Mapping_Vectors_Are_Aligned
     (Draft : Settings_Draft)
      return Boolean is
   begin
      return Natural (Draft.Filetype_Keys.Length) = Natural (Draft.Filetype_Values.Length)
        and then Natural (Draft.Icon_Keys.Length) = Natural (Draft.Icon_Values.Length)
        and then Natural (Draft.Open_Action_Keys.Length) = Natural (Draft.Open_Action_Commands.Length);
   end Draft_Mapping_Vectors_Are_Aligned;

   function Draft_Mapping_Key_Error
     (Draft : Settings_Draft)
      return String is
   begin
      if (Length (Draft.Filetype_Extension) > 0 or else Length (Draft.Filetype_Value) > 0)
        and then not Mapping_Key_Is_Valid (Normalize_Extension (To_String (Draft.Filetype_Extension)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Key of Draft.Filetype_Keys loop
         if not Mapping_Key_Is_Valid (Normalize_Extension (To_String (Key))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Icon_Filetype) > 0 or else Length (Draft.Icon_Value) > 0)
        and then not Mapping_Key_Is_Valid (Trim (To_String (Draft.Icon_Filetype)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Key of Draft.Icon_Keys loop
         if not Mapping_Key_Is_Valid (Trim (To_String (Key))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if Length (Draft.Open_Action_Token) > 0 or else Length (Draft.Open_Action_Command) > 0 then
         declare
            Token : constant String := Normalize_Action_Token (To_String (Draft.Open_Action_Token));
            Plus  : constant Natural := Modifier_Suffix_Start (Token);
         begin
            if Token = ""
              or else (Plus = Token'First)
              or else not Open_Action_Base_Key_Is_Valid
                ((if Plus = 0 then Token else Token (Token'First .. Plus - 1)))
              or else not Action_Token_Modifiers_Are_Known (To_String (Draft.Open_Action_Token))
            then
               return "error.settings.invalid_open_action";
            end if;
         end;
      end if;

      for Key of Draft.Open_Action_Keys loop
         declare
            Token : constant String := Normalize_Action_Token (To_String (Key));
            Plus  : constant Natural := Modifier_Suffix_Start (Token);
         begin
            if Token = ""
              or else (Plus = Token'First)
              or else not Open_Action_Base_Key_Is_Valid
                ((if Plus = 0 then Token else Token (Token'First .. Plus - 1)))
              or else not Action_Token_Modifiers_Are_Known (To_String (Key))
            then
               return "error.settings.invalid_open_action";
            end if;
         end;
      end loop;

      return "";
   end Draft_Mapping_Key_Error;

   function Draft_Mapping_Value_Error
     (Draft : Settings_Draft)
      return String is
   begin
      if (Length (Draft.Filetype_Extension) > 0 or else Length (Draft.Filetype_Value) > 0)
        and then not Mapping_Value_Is_Valid (Trim (To_String (Draft.Filetype_Value)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Value of Draft.Filetype_Values loop
         if not Mapping_Value_Is_Valid (Trim (To_String (Value))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Icon_Filetype) > 0 or else Length (Draft.Icon_Value) > 0)
        and then not Mapping_Value_Is_Valid (Trim (To_String (Draft.Icon_Value)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Value of Draft.Icon_Values loop
         if not Mapping_Value_Is_Valid (Trim (To_String (Value))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Open_Action_Token) > 0 or else Length (Draft.Open_Action_Command) > 0)
        and then Contains_Line_Break (To_String (Draft.Open_Action_Command))
      then
         return "error.settings.invalid_open_action";
      end if;

      for Value of Draft.Open_Action_Commands loop
         if Contains_Line_Break (To_String (Value)) then
            return "error.settings.invalid_open_action";
         end if;
      end loop;

      return "";
   end Draft_Mapping_Value_Error;

   type Draft_Mapping_Kind is
     (Draft_Filetype_Mapping,
      Draft_Icon_Mapping,
      Draft_Open_Action_Mapping);

   function Draft_Mapping_Key_Text
     (Kind : Draft_Mapping_Kind;
      Key  : UString)
      return String is
   begin
      case Kind is
         when Draft_Filetype_Mapping =>
            return Normalize_Extension (To_String (Key));
         when Draft_Icon_Mapping =>
            return Trim (To_String (Key));
         when Draft_Open_Action_Mapping =>
            return Normalize_Action_Token (To_String (Key));
      end case;
   end Draft_Mapping_Key_Text;

   function Draft_Settings_Text
     (Draft : Settings_Draft)
      return String
   is
      Filetype_Keys : String_Vectors.Vector := Draft.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector := Draft.Filetype_Values;
      Icon_Keys     : String_Vectors.Vector := Draft.Icon_Keys;
      Icon_Values   : String_Vectors.Vector := Draft.Icon_Values;
      Action_Keys   : String_Vectors.Vector := Draft.Open_Action_Keys;
      Action_Values : String_Vectors.Vector := Draft.Open_Action_Commands;
      Result        : Unbounded_String := Null_Unbounded_String;

      procedure Upsert
        (Keys   : in out String_Vectors.Vector;
         Values : in out String_Vectors.Vector;
         Kind   : Draft_Mapping_Kind;
         Key    : UString;
         Value  : UString)
      is
         Key_Text : constant String := Draft_Mapping_Key_Text (Kind, Key);
      begin
         if Length (Key) = 0 and then Length (Value) = 0 then
            return;
         end if;

         for Index in 1 .. Natural (Keys.Length) loop
            if Draft_Mapping_Key_Text (Kind, Keys.Element (Index)) = Key_Text then
               Keys.Replace_Element (Index, To_Unbounded_String (Key_Text));
               Values.Replace_Element (Index, Value);
               return;
            end if;
         end loop;

         Keys.Append (To_Unbounded_String (Key_Text));
         Values.Append (Value);
      end Upsert;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      Upsert
        (Filetype_Keys,
         Filetype_Values,
         Draft_Filetype_Mapping,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Upsert (Icon_Keys, Icon_Values, Draft_Icon_Mapping, Draft.Icon_Filetype, Draft.Icon_Value);
      Upsert
        (Action_Keys,
         Action_Values,
         Draft_Open_Action_Mapping,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);

      Append_Line ("[settings]");
      Append_Line ("default_view_mode = " & To_String (Draft.Default_View_Mode));
      Append_Line ("show_hidden_files = " & To_String (Draft.Show_Hidden_Files));
      Append_Line ("sort_field = " & To_String (Draft.Sort_Field_Value));
      Append_Line ("sort_ascending = " & To_String (Draft.Sort_Ascending));
      Append_Line ("high_contrast_theme = " & To_String (Draft.High_Contrast_Theme));
      Append_Line ("icon_theme = " & Action_Token_Text (To_String (Draft.Icon_Theme_Name)));

      if not Filetype_Keys.Is_Empty then
         Append_Line ("[filetypes]");
         for Index in 1 .. Natural (Filetype_Keys.Length) loop
            Append_Line
              (To_String (Filetype_Keys.Element (Index))
               & " = "
               & Action_Token_Text (To_String (Filetype_Values.Element (Index))));
         end loop;
      end if;

      if not Icon_Keys.Is_Empty then
         Append_Line ("[icons]");
         for Index in 1 .. Natural (Icon_Keys.Length) loop
            Append_Line
              (To_String (Icon_Keys.Element (Index))
               & " = "
               & Action_Token_Text (To_String (Icon_Values.Element (Index))));
         end loop;
      end if;

      if not Action_Keys.Is_Empty then
         Append_Line ("[open-actions]");
         for Index in 1 .. Natural (Action_Keys.Length) loop
            Append_Line (To_String (Action_Keys.Element (Index)) & " = " & To_String (Action_Values.Element (Index)));
         end loop;
      end if;

      return To_String (Result);
   end Draft_Settings_Text;

   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result is
   begin
      if not Draft_Mapping_Vectors_Are_Aligned (Draft) then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.invalid"));
      end if;

      declare
         Key_Error : constant String := Draft_Mapping_Key_Error (Draft);
      begin
         if Key_Error /= "" then
            return
              (Success   => False,
               Settings  => Default_Settings,
               Error_Key => To_Unbounded_String (Key_Error));
         end if;
      end;

      declare
         Value_Error : constant String := Draft_Mapping_Value_Error (Draft);
      begin
         if Value_Error /= "" then
            return
              (Success   => False,
               Settings  => Default_Settings,
               Error_Key => To_Unbounded_String (Value_Error));
         end if;
      end;

      return Parse (Draft_Settings_Text (Draft));
   end Validate_Draft;

   function Field_Diagnostic
     (Field : Natural;
      Text  : String)
      return String
   is
      Clean : constant String := Trim (Text);
   begin
      if Contains_Line_Break (Text) then
         case Field is
            when 1 =>
               return "error.settings.invalid_view_mode";
            when 2 | 4 | 5 =>
               return "error.settings.invalid_boolean";
            when 3 =>
               return "error.settings.invalid_sort_field";
            when 6 =>
               return "error.settings.invalid_icon_theme";
            when 7 .. 10 =>
               return "error.settings.invalid_mapping";
            when 11 | 12 =>
               return "error.settings.invalid_open_action";
            when others =>
               return "error.settings.invalid";
         end case;
      end if;

      case Field is
         when 1 =>
            declare
               Mode : constant String := Files.Types.To_Lower (Clean);
            begin
               if Mode = "small"
                 or else Mode = "small_icons"
                 or else Mode = "large"
                 or else Mode = "large_icons"
                 or else Mode = "details"
               then
                  return "";
               end if;
               return "error.settings.invalid_view_mode";
            end;
         when 2 | 4 | 5 =>
            declare
               Value : constant String := Files.Types.To_Lower (Clean);
            begin
               if Value = "true" or else Value = "false" then
                  return "";
               end if;
               return "error.settings.invalid_boolean";
            end;
         when 3 =>
            declare
               Value : constant String := Files.Types.To_Lower (Clean);
            begin
               if Value = "name" or else Value = "filetype" or else Value = "size" or else Value = "modified" then
                  return "";
               end if;
               return "error.settings.invalid_sort_field";
            end;
         when 6 =>
            return (if Icon_Theme_Name_Is_Valid (Clean) then "" else "error.settings.invalid_icon_theme");
         when 7 =>
            declare
               Key : constant String := Normalize_Extension (Clean);
            begin
               return (if not Mapping_Key_Is_Valid (Key) then "error.settings.invalid_mapping" else "");
            end;
         when 8 | 10 =>
            return (if Clean = "" then "error.settings.invalid_mapping" else "");
         when 9 =>
            return (if not Mapping_Key_Is_Valid (Clean) then "error.settings.invalid_mapping" else "");
         when 11 =>
            declare
               Key  : constant String := Normalize_Action_Token (Clean);
               Plus : constant Natural := Modifier_Suffix_Start (Key);
            begin
               if Key = ""
                 or else Plus = Key'First
                 or else not Open_Action_Base_Key_Is_Valid
                   ((if Plus = 0 then Key else Key (Key'First .. Plus - 1)))
                 or else not Action_Token_Modifiers_Are_Known (Clean)
               then
                  return "error.settings.invalid_open_action";
               end if;
               return "";
            end;
         when 12 =>
            declare
               Action : constant Open_Action := Parse_Action (Clean);
            begin
               if To_String (Action.Executable) = "" or else Has_Unsafe_Placeholder_Usage (Action) then
                  return "error.settings.invalid_open_action";
               end if;
               return "";
            end;
         when others =>
            return "error.settings.invalid";
      end case;
   end Field_Diagnostic;

   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result
   is
      Parsed : constant Settings_Parse_Result := Validate_Draft (Draft);
      Result : Settings_Model := Settings;
      Filetype_Keys : String_Vectors.Vector := Draft.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector := Draft.Filetype_Values;
      Icon_Keys     : String_Vectors.Vector := Draft.Icon_Keys;
      Icon_Values   : String_Vectors.Vector := Draft.Icon_Values;
      Action_Keys   : String_Vectors.Vector := Draft.Open_Action_Keys;
      Action_Values : String_Vectors.Vector := Draft.Open_Action_Commands;

      procedure Upsert
        (Keys   : in out String_Vectors.Vector;
         Values : in out String_Vectors.Vector;
         Kind   : Draft_Mapping_Kind;
         Key    : UString;
         Value  : UString)
      is
         Key_Text : constant String := Draft_Mapping_Key_Text (Kind, Key);
      begin
         if Length (Key) = 0 and then Length (Value) = 0 then
            return;
         end if;

         for Index in 1 .. Natural (Keys.Length) loop
            if Draft_Mapping_Key_Text (Kind, Keys.Element (Index)) = Key_Text then
               Keys.Replace_Element (Index, To_Unbounded_String (Key_Text));
               Values.Replace_Element (Index, Value);
               return;
            end if;
         end loop;

         Keys.Append (To_Unbounded_String (Key_Text));
         Values.Append (Value);
      end Upsert;
   begin
      if not Parsed.Success then
         return
           (Success   => False,
            Settings  => Settings,
            Error_Key => Parsed.Error_Key);
      end if;

      Result.Default_View := Parsed.Settings.Default_View;
      Result.Show_Hidden_Files := Parsed.Settings.Show_Hidden_Files;
      Result.Sort_Field_Value := Parsed.Settings.Sort_Field_Value;
      Result.Sort_Ascending := Parsed.Settings.Sort_Ascending;
      Result.High_Contrast_Theme := Parsed.Settings.High_Contrast_Theme;
      Result.Icon_Theme_Name := Parsed.Settings.Icon_Theme_Name;
      Upsert
        (Filetype_Keys,
         Filetype_Values,
         Draft_Filetype_Mapping,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Upsert (Icon_Keys, Icon_Values, Draft_Icon_Mapping, Draft.Icon_Filetype, Draft.Icon_Value);
      Upsert
        (Action_Keys,
         Action_Values,
         Draft_Open_Action_Mapping,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);

      Result.Extension_Filetypes.Clear;
      for Index in 1 .. Natural (Filetype_Keys.Length) loop
         Add_Extension_Mapping
           (Result,
            To_String (Filetype_Keys.Element (Index)),
            To_String (Filetype_Values.Element (Index)));
      end loop;

      Result.Icon_Mappings.Clear;
      for Index in 1 .. Natural (Icon_Keys.Length) loop
         Add_Icon_Mapping
           (Result,
            To_String (Icon_Keys.Element (Index)),
            To_String (Icon_Values.Element (Index)));
      end loop;

      Result.Open_Actions.Clear;
      for Index in 1 .. Natural (Action_Keys.Length) loop
         Add_Open_Action
           (Result,
            To_String (Action_Keys.Element (Index)),
            Parse_Action (To_String (Action_Values.Element (Index))));
      end loop;
      return
        (Success   => True,
         Settings  => Result,
         Error_Key => Null_Unbounded_String);
   end Apply_Draft;

   function Save_Draft
     (Path     : String;
      Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Write_Result
   is
      Applied : constant Settings_Parse_Result := Apply_Draft (Settings, Draft);
   begin
      if not Applied.Success then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => Applied.Error_Key);
      end if;

      return Save_Text (Path, To_Text (Applied.Settings));
   end Save_Draft;

   function Reset_Draft_To_Defaults return Settings_Draft is
   begin
      return Make_Draft (Default_Settings);
   end Reset_Draft_To_Defaults;

   function Save_Text
     (Path : String;
      Text : String)
      return Settings_Write_Result
   is
      File   : Ada.Text_IO.File_Type;
      Parent : constant String := Parent_Directory (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.not_file"));
      end if;

      if Parent /= "" then
         if Ada.Directories.Exists (Parent) then
            if Ada.Directories.Kind (Parent) /= Ada.Directories.Directory then
               return
                 (Success   => False,
                  Path      => To_Unbounded_String (Path),
                  Error_Key => To_Unbounded_String ("error.settings.not_file"));
            end if;
         else
            Ada.Directories.Create_Path (Parent);
         end if;
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
      return
        (Success   => True,
         Path      => To_Unbounded_String (Path),
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);

         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Save_Text;

   function Ensure_Default_File
     (Path : String)
      return Settings_Write_Result
   is
   begin
      if Path = "" then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
      elsif Ada.Directories.Exists (Path) then
         if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
            return
              (Success   => True,
               Path      => To_Unbounded_String (Path),
               Error_Key => Null_Unbounded_String);
         else
            return
              (Success   => False,
               Path      => To_Unbounded_String (Path),
               Error_Key => To_Unbounded_String ("error.settings.not_file"));
         end if;
      end if;

      return Save_Text (Path, Default_Settings_Text);
   exception
      when others =>
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Error_Key => To_Unbounded_String ("error.settings.save"));
   end Ensure_Default_File;

   function Normalize_Extension
     (Extension : String)
      return String
   is
      Clean : constant String := Trim (Extension);
   begin
      if Clean = "" then
         return "";
      elsif Clean (Clean'First) = '.' then
         if Clean'Length = 1 then
            return "";
         end if;
         return Files.Types.To_Lower (Trim (Clean (Clean'First + 1 .. Clean'Last)));
      else
         return Files.Types.To_Lower (Clean);
      end if;
   end Normalize_Extension;

   function Make_Action
     (Executable : String;
      Arguments  : String_Vectors.Vector;
      Use_Shell  : Boolean := False)
      return Open_Action is
   begin
      return
        (Executable => To_Unbounded_String (Executable),
         Arguments  => Arguments,
         Use_Shell  => Use_Shell);
   end Make_Action;

   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
   is
      function Is_Path_Separator (Value : Character) return Boolean is
      begin
         return Value = '/' or else Value = '\';
      end Is_Path_Separator;

      function UNC_Share_Root_Last (Value : String) return Natural is
         Server_Start : Natural;
         Share_Start  : Natural;
      begin
         if Value'Length < 5
           or else not Is_Path_Separator (Value (Value'First))
           or else not Is_Path_Separator (Value (Value'First + 1))
         then
            return 0;
         end if;

         Server_Start := Value'First + 2;
         while Server_Start <= Value'Last and then Is_Path_Separator (Value (Server_Start)) loop
            Server_Start := Server_Start + 1;
         end loop;

         for Index in Server_Start .. Value'Last loop
            if Is_Path_Separator (Value (Index)) then
               Share_Start := Index + 1;
               while Share_Start <= Value'Last and then Is_Path_Separator (Value (Share_Start)) loop
                  Share_Start := Share_Start + 1;
               end loop;

               for Share_End in Share_Start .. Value'Last loop
                  if Is_Path_Separator (Value (Share_End)) then
                     return Share_End;
                  end if;
               end loop;

               return Value'Last;
            end if;
         end loop;

         return 0;
      end UNC_Share_Root_Last;

      function Trim_Trailing_Path_Separators (Value : String) return String is
         Last : Natural := Value'Last;
         UNC_Root_Last : constant Natural := UNC_Share_Root_Last (Value);
      begin
         if Value = "" then
            return "";
         end if;

         while Last > Value'First
           and then Is_Path_Separator (Value (Last))
         loop
            if Last = Value'First + 2 and then Value (Value'First + 1) = ':' then
               exit;
            elsif UNC_Root_Last > 0 and then Last <= UNC_Root_Last then
               exit;
            end if;

            Last := Last - 1;
         end loop;

         return Value (Value'First .. Last);
      end Trim_Trailing_Path_Separators;

      function Safe_Simple_Name (Value : String) return String is
         Separator : Natural := 0;
      begin
         if Value = "" then
            return "";
         elsif UNC_Share_Root_Last (Value) = Value'Last then
            return "";
         end if;

         for Index in reverse Value'Range loop
            if Is_Path_Separator (Value (Index)) then
               Separator := Index;
               exit;
            end if;
         end loop;

         if Separator > 0 and then Separator < Value'Last then
            return Value (Separator + 1 .. Value'Last);
         elsif Separator = Value'Last then
            return "";
         end if;

         return Ada.Directories.Simple_Name (Value);
      exception
         when others =>
            return Value;
      end Safe_Simple_Name;

      function Safe_Containing_Directory (Value : String) return String is
         Separator : Natural := 0;
      begin
         if Value = "" then
            return "";
         elsif UNC_Share_Root_Last (Value) = Value'Last then
            return Value;
         end if;

         for Index in reverse Value'Range loop
            if Is_Path_Separator (Value (Index)) then
               Separator := Index;
               exit;
            end if;
         end loop;

         if Separator = Value'First + 2
           and then Value (Value'First + 1) = ':'
         then
            return Value (Value'First .. Separator);
         elsif Separator > Value'First then
            return Value (Value'First .. Separator - 1);
         elsif Separator = Value'First then
            return Value (Value'First .. Value'First);
         end if;

         return Ada.Directories.Containing_Directory (Value);
      exception
         when others =>
            return "";
      end Safe_Containing_Directory;

      function Last_Extension_Dot (Name : String) return Natural is
      begin
         for Index in reverse Name'Range loop
            if Name (Index) = '.' then
               return Index;
            end if;
         end loop;

         return 0;
      end Last_Extension_Dot;

      function Stem_Of (Name : String) return String is
         Dot : constant Natural := Last_Extension_Dot (Name);
      begin
         if Dot = 0 or else Dot = Name'First then
            return Name;
         elsif Dot = Name'Last then
            return Name;
         end if;

         return Name (Name'First .. Dot - 1);
      end Stem_Of;

      function Extension_Of (Name : String) return String is
         Dot : constant Natural := Last_Extension_Dot (Name);
      begin
         if Dot = 0 or else Dot = Name'First or else Dot = Name'Last then
            return "";
         end if;

         return Normalize_Extension (Name (Dot + 1 .. Name'Last));
      end Extension_Of;

      Result    : Open_Action := Action;
      Clean     : constant String := Trim_Trailing_Path_Separators (Path);
      Name      : constant String := Safe_Simple_Name (Clean);
      Parent    : constant String := Safe_Containing_Directory (Clean);
      Extension : constant String := Extension_Of (Name);
      Stem      : constant String := Stem_Of (Name);
   begin
      Result.Arguments.Clear;
      for Argument of Action.Arguments loop
         declare
            Value : constant String := To_String (Argument);
         begin
            if Value = "{path}" then
               Result.Arguments.Append (To_Unbounded_String (Path));
            elsif Value = "{parent}" then
               Result.Arguments.Append (To_Unbounded_String (Parent));
            elsif Value = "{name}" then
               Result.Arguments.Append (To_Unbounded_String (Name));
            elsif Value = "{stem}" then
               Result.Arguments.Append (To_Unbounded_String (Stem));
            elsif Value = "{extension}" then
               Result.Arguments.Append (To_Unbounded_String (Extension));
            else
               Result.Arguments.Append (Argument);
            end if;
         end;
      end loop;

      return Result;
   end Expand_Placeholders;

end Files.Settings;
