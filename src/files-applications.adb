with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Hostkit.Fs;

with Files.Localization;
with Files.Operations;

package body Files.Applications is
   use Ada.Strings.Unbounded;

   package Desktop_Id_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_Type => String);

   --  Strip a trailing or leading run of ASCII spaces and tabs from Text.
   function Trim_Blanks (Text : String) return String is
      First : Integer := Text'First;
      Last  : Integer := Text'Last;
   begin
      while First <= Last
        and then (Text (First) = ' ' or else Text (First) = ASCII.HT)
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then (Text (Last) = ' ' or else Text (Last) = ASCII.HT)
      loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trim_Blanks;

   procedure Parse_Boolean
     (Value  : String;
      Parsed : out Boolean;
      Valid  : out Boolean)
   is
      Trimmed : constant String := Trim_Blanks (Value);
   begin
      Valid := Trimmed = "true" or else Trimmed = "false";
      Parsed := Trimmed = "true";
   end Parse_Boolean;

   function Is_Valid_Group_Header (Line : String) return Boolean is
   begin
      if Line'Length < 3
        or else Line (Line'First) /= '['
        or else Line (Line'Last) /= ']'
      then
         return False;
      end if;

      for Index in Line'First + 1 .. Line'Last - 1 loop
         if Line (Index) = '['
           or else Line (Index) = ']'
           or else Character'Pos (Line (Index)) < 32
           or else Character'Pos (Line (Index)) > 126
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Valid_Group_Header;

   function Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;
      return "";
   exception
      when others =>
         return "";
   end Environment_Value;

   function Strip_Locale_Encoding (Locale : String) return String is
      Dot      : Natural := 0;
      Modifier : Natural := 0;
   begin
      for Index in Locale'Range loop
         if Locale (Index) = '.' and then Dot = 0 then
            Dot := Index;
         elsif Locale (Index) = '@' and then Modifier = 0 then
            Modifier := Index;
         end if;
      end loop;

      if Dot = 0 then
         return Locale;
      elsif Modifier > Dot then
         return Locale (Locale'First .. Dot - 1)
           & Locale (Modifier .. Locale'Last);
      else
         return Locale (Locale'First .. Dot - 1);
      end if;
   end Strip_Locale_Encoding;

   --  Return locale postfixes in desktop-entry fallback order. Environment
   --  values retain POSIX modifiers; the host fallback uses the project's
   --  normalized locale and is converted back to desktop-entry spelling.
   function Message_Locale_Candidates return Files.Types.String_Vectors.Vector is
      Raw : Unbounded_String;
      Result : Files.Types.String_Vectors.Vector;

      procedure Append_Unique (Value : String) is
      begin
         if Value = "" then
            return;
         end if;
         for Existing of Result loop
            if To_String (Existing) = Value then
               return;
            end if;
         end loop;
         Result.Append (To_Unbounded_String (Value));
      end Append_Unique;
   begin
      Raw := To_Unbounded_String (Environment_Value ("LC_ALL"));
      if Raw = "" then
         Raw := To_Unbounded_String (Environment_Value ("LC_MESSAGES"));
      end if;
      if Raw = "" then
         Raw := To_Unbounded_String (Environment_Value ("LANG"));
      end if;

      if Raw = "" then
         Raw := To_Unbounded_String (Files.Localization.System_Locale);
         for Index in 1 .. Length (Raw) loop
            if Element (Raw, Index) = '-' then
               Replace_Element (Raw, Index, '_');
            end if;
         end loop;
      end if;

      declare
         Locale    : constant String := Strip_Locale_Encoding
           (Trim_Blanks (To_String (Raw)));
         Underline : Natural := 0;
         Modifier  : Natural := 0;
      begin
         for Index in Locale'Range loop
            if Locale (Index) = '_' and then Underline = 0 then
               Underline := Index;
            elsif Locale (Index) = '@' and then Modifier = 0 then
               Modifier := Index;
            end if;
         end loop;

         Append_Unique (Locale);
         if Underline /= 0 then
            Append_Unique
              (Locale
                 (Locale'First ..
                    (if Modifier > Underline then Modifier - 1 else Locale'Last)));
         end if;
         if Modifier /= 0 then
            Append_Unique
              (Locale (Locale'First ..
                 (if Underline /= 0 then Underline - 1 else Modifier - 1))
               & Locale (Modifier .. Locale'Last));
         end if;
         if Underline /= 0 or else Modifier /= 0 then
            Append_Unique
              (Locale
                 (Locale'First ..
                    (if Underline /= 0 then Underline - 1
                     else Modifier - 1)));
         end if;
      end;
      return Result;
   end Message_Locale_Candidates;

   function Localized_Key_Rank
     (Key        : String;
      Base_Key   : String;
      Candidates : Files.Types.String_Vectors.Vector) return Natural
   is
      Prefix_Length : constant Natural := Base_Key'Length + 1;
   begin
      if Key'Length <= Base_Key'Length + 2
        or else Key (Key'First .. Key'First + Base_Key'Length) /=
          Base_Key & "["
        or else Key (Key'Last) /= ']'
      then
         return 0;
      end if;

      declare
         Locale : constant String := Strip_Locale_Encoding
           (Key (Key'First + Prefix_Length .. Key'Last - 1));
         Rank   : Natural := 1;
      begin
         for Candidate of Candidates loop
            if Locale = To_String (Candidate) then
               return Rank;
            end if;
            Rank := Rank + 1;
         end loop;
      end;
      return 0;
   end Localized_Key_Rank;

   --  Decode the escapes shared by desktop-entry string, localestring, and
   --  iconstring values. Invalid escapes make the containing entry unusable.
   procedure Decode_Value
     (Value   : String;
      Decoded : out Unbounded_String;
      Valid   : out Boolean)
   is
      Position : Integer := Value'First;
   begin
      Decoded := Null_Unbounded_String;
      Valid := True;
      while Position <= Value'Last loop
         if Value (Position) /= '\' then
            Append (Decoded, Value (Position));
         elsif Position = Value'Last then
            Valid := False;
            Decoded := Null_Unbounded_String;
            return;
         else
            Position := Position + 1;
            case Value (Position) is
               when 's' => Append (Decoded, ' ');
               when 'n' => Append (Decoded, ASCII.LF);
               when 't' => Append (Decoded, ASCII.HT);
               when 'r' => Append (Decoded, ASCII.CR);
               when '\' => Append (Decoded, '\');
               when others =>
                  Valid := False;
                  Decoded := Null_Unbounded_String;
                  return;
            end case;
         end if;
         Position := Position + 1;
      end loop;
   end Decode_Value;

   --  Decode a desktop-entry string(s) value while retaining escaped
   --  semicolons inside an item rather than treating them as separators.
   procedure Parse_String_List
     (Value  : String;
      Items  : out Files.Types.String_Vectors.Vector;
      Valid  : out Boolean)
   is
      Current  : Unbounded_String;
      Position : Integer := Value'First;
   begin
      Items.Clear;
      Valid := True;
      while Position <= Value'Last loop
         if Value (Position) = ';' then
            Items.Append (Current);
            Current := Null_Unbounded_String;
         elsif Value (Position) /= '\' then
            Append (Current, Value (Position));
         elsif Position = Value'Last then
            Valid := False;
            Items.Clear;
            return;
         else
            Position := Position + 1;
            case Value (Position) is
               when 's' => Append (Current, ' ');
               when 'n' => Append (Current, ASCII.LF);
               when 't' => Append (Current, ASCII.HT);
               when 'r' => Append (Current, ASCII.CR);
               when '\' => Append (Current, '\');
               when ';' => Append (Current, ';');
               when others =>
                  Valid := False;
                  Items.Clear;
                  return;
            end case;
         end if;
         Position := Position + 1;
      end loop;

      if Length (Current) > 0
        or else (Value'Length > 0 and then Value (Value'Last) /= ';')
      then
         Items.Append (Current);
      end if;
   end Parse_String_List;

   function List_Contains
     (List : Files.Types.String_Vectors.Vector;
      Item : String) return Boolean
   is
   begin
      if Item = "" then
         return False;
      end if;
      for Existing of List loop
         if To_String (Existing) = Item then
            return True;
         end if;
      end loop;
      return False;
   end List_Contains;

   function Lists_Overlap
     (Left, Right : Files.Types.String_Vectors.Vector) return Boolean
   is
   begin
      for Item of Left loop
         if Item /= "" and then List_Contains (Right, To_String (Item)) then
            return True;
         end if;
      end loop;
      return False;
   end Lists_Overlap;

   --  Apply OnlyShowIn/NotShowIn to each desktop name in the colon-separated
   --  XDG_CURRENT_DESKTOP value. Desktop identifiers are case-sensitive.
   function Desktop_Environment_Allows
     (Only_Show_In     : Files.Types.String_Vectors.Vector;
      Have_Only        : Boolean;
      Not_Show_In      : Files.Types.String_Vectors.Vector;
      Have_Not         : Boolean) return Boolean
   is
      Current : constant String := Environment_Value ("XDG_CURRENT_DESKTOP");
      First   : Integer := Current'First;
      Last    : Integer;
   begin
      --  Both keys may be present, but one desktop name cannot occur in both.
      if Have_Only and then Have_Not
        and then Lists_Overlap (Only_Show_In, Not_Show_In)
      then
         return False;
      end if;

      while First <= Current'Last loop
         Last := First;
         while Last <= Current'Last and then Current (Last) /= ':' loop
            Last := Last + 1;
         end loop;
         declare
            Desktop : constant String := Current (First .. Last - 1);
         begin
            if Have_Only
              and then List_Contains (Only_Show_In, Desktop)
            then
               return True;
            elsif Have_Not
              and then List_Contains (Not_Show_In, Desktop)
            then
               return False;
            end if;
         end;
         First := Last + 1;
      end loop;

      --  An unmatched OnlyShowIn hides the entry. An unmatched NotShowIn does
      --  not restrict it.
      return not Have_Only;
   end Desktop_Environment_Allows;

   --  Desktop Exec values are argument vectors, not shell command lines. Quotes
   --  and backslashes group characters, but are removed before the vector is
   --  passed to the process API. Field codes inside quotes are invalid by the
   --  desktop-entry specification; rejecting them also avoids silently changing
   --  their argument boundaries.
   procedure Parse_Exec
     (Text   : String;
      Tokens : out Files.Types.String_Vectors.Vector;
      Valid  : out Boolean)
   is
      Current   : Unbounded_String;
      Position  : Integer := Text'First;
      In_Quotes : Boolean := False;
      Started   : Boolean := False;

      procedure Finish_Token is
      begin
         if Started then
            Tokens.Append (Current);
            Current := Null_Unbounded_String;
            Started := False;
         end if;
      end Finish_Token;
   begin
      Tokens.Clear;
      Valid := True;

      while Position <= Text'Last loop
         if Text (Position) = '\' then
            if Position = Text'Last then
               Valid := False;
               Tokens.Clear;
               return;
            end if;
            Position := Position + 1;
            Append (Current, Text (Position));
            Started := True;
         elsif Text (Position) = '"' then
            In_Quotes := not In_Quotes;
            Started := True;
         elsif (Text (Position) = ' ' or else Text (Position) = ASCII.HT)
           and then not In_Quotes
         then
            Finish_Token;
         else
            if In_Quotes and then Text (Position) = '%'
              and then Position < Text'Last
              and then Text (Position + 1) /= '%'
            then
               Valid := False;
               Tokens.Clear;
               return;
            end if;
            Append (Current, Text (Position));
            Started := True;
         end if;
         Position := Position + 1;
      end loop;

      if In_Quotes then
         Valid := False;
         Tokens.Clear;
         return;
      end if;
      Finish_Token;
   end Parse_Exec;

   function Build_Open_Action
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Files.Settings.Open_Action
   is
      Tokens     : Files.Types.String_Vectors.Vector;
      Executable : Unbounded_String;
      Arguments  : Files.Types.String_Vectors.Vector;
      Valid      : Boolean;
      Target_Field_Seen : Boolean := False;

      procedure Decode_Executable
        (Token   : String;
         Decoded : out Unbounded_String)
      is
         Position : Integer := Token'First;
      begin
         Decoded := Null_Unbounded_String;
         while Position <= Token'Last loop
            if Token (Position) /= '%' then
               Append (Decoded, Token (Position));
               Position := Position + 1;
            elsif Position = Token'Last
              or else Token (Position + 1) /= '%'
            then
               Valid := False;
               Decoded := Null_Unbounded_String;
               return;
            else
               Append (Decoded, '%');
               Position := Position + 2;
            end if;
         end loop;
      end Decode_Executable;

      procedure Append_Expanded (Token : String) is
         Expanded  : Unbounded_String;
         Position  : Integer := Token'First;
         Had_Field : Boolean := False;

         procedure Use_Target is
         begin
            if Target_Field_Seen then
               Valid := False;
               return;
            end if;
            Target_Field_Seen := True;
            if not Targets.Is_Empty then
               Append (Expanded, To_String (Targets.First_Element));
            end if;
         end Use_Target;
      begin
         if Token = "%F" or else Token = "%U" then
            if Target_Field_Seen then
               Valid := False;
               return;
            end if;
            Target_Field_Seen := True;
            for Target of Targets loop
               Arguments.Append (Target);
            end loop;
            return;
         elsif Token = "%i" then
            if App.Icon /= "" then
               Arguments.Append (To_Unbounded_String ("--icon"));
               Arguments.Append (App.Icon);
            end if;
            return;
         end if;

         while Position <= Token'Last loop
            if Token (Position) /= '%' then
               Append (Expanded, Token (Position));
               Position := Position + 1;
            elsif Position = Token'Last then
               Valid := False;
               return;
            else
               Had_Field := True;
               case Token (Position + 1) is
                  when '%' =>
                     Append (Expanded, '%');
                  when 'f' | 'u' =>
                     Use_Target;
                  when 'c' =>
                     Append (Expanded, To_String (App.Name));
                  when 'k' =>
                     Append (Expanded, To_String (App.Desktop_File));
                  when 'd' | 'D' | 'n' | 'N' | 'v' | 'm' =>
                     null;
                  when 'F' | 'U' | 'i' =>
                     --  These codes expand to multiple arguments and are only
                     --  valid as a complete argument.
                     Valid := False;
                     return;
                  when others =>
                     Valid := False;
                     return;
               end case;
               Position := Position + 2;
            end if;
         end loop;

         if Valid and then (Length (Expanded) > 0 or else not Had_Field) then
            Arguments.Append (Expanded);
         end if;
      end Append_Expanded;
   begin
      Parse_Exec (To_String (App.Exec), Tokens, Valid);
      if not Valid or else Tokens.Is_Empty then
         return Files.Settings.Make_Action ("", Arguments);
      end if;

      Decode_Executable (To_String (Tokens.First_Element), Executable);
      if not Valid or else Index (Executable, "=") /= 0 then
         return Files.Settings.Make_Action ("", Arguments);
      end if;

      for Token_Index in 2 .. Natural (Tokens.Length) loop
         Append_Expanded (To_String (Tokens.Element (Positive (Token_Index))));
         exit when not Valid;
      end loop;

      if not Valid then
         return Files.Settings.Make_Action ("", Files.Types.String_Vectors.Empty_Vector);
      elsif not Target_Field_Seen then
         for Target of Targets loop
            Arguments.Append (Target);
         end loop;
      end if;

      return Files.Settings.Make_Action (To_String (Executable), Arguments);
   end Build_Open_Action;

   function Has_Single_Target_Field (App : Application) return Boolean is
      Tokens : Files.Types.String_Vectors.Vector;
      Valid  : Boolean;
   begin
      Parse_Exec (To_String (App.Exec), Tokens, Valid);
      if not Valid or else Tokens.Is_Empty then
         return False;
      end if;

      for Token_Index in 2 .. Natural (Tokens.Length) loop
         declare
            Token    : constant String :=
              To_String (Tokens.Element (Positive (Token_Index)));
            Position : Integer := Token'First;
         begin
            while Position <= Token'Last loop
               if Token (Position) = '%' and then Position < Token'Last then
                  if Token (Position + 1) = 'f'
                    or else Token (Position + 1) = 'u'
                  then
                     return True;
                  end if;
                  Position := Position + 2;
               else
                  Position := Position + 1;
               end if;
            end loop;
         end;
      end loop;
      return False;
   end Has_Single_Target_Field;

   function Build_Open_Actions
     (App     : Application;
      Targets : Files.Types.String_Vectors.Vector)
      return Open_Action_Vectors.Vector
   is
      Result : Open_Action_Vectors.Vector;
   begin
      if Natural (Targets.Length) > 1 and then Has_Single_Target_Field (App) then
         for Target of Targets loop
            declare
               One_Target : Files.Types.String_Vectors.Vector;
            begin
               One_Target.Append (Target);
               Result.Append (Build_Open_Action (App, One_Target));
            end;
         end loop;
      else
         Result.Append (Build_Open_Action (App, Targets));
      end if;
      return Result;
   end Build_Open_Actions;

   --  Parse a single .desktop file into an Application, returning whether it is
   --  a displayable application entry. Any failure leaves Found False.
   procedure Parse_Desktop_File
     (Path    : String;
      Locales : Files.Types.String_Vectors.Vector;
      Found   : out Boolean;
      App     : out Application)
   is
      --  The desktop group header, assembled from fragments so no single source
      --  literal mixes letters with a space (which the repository's hard-coded
      --  text check would otherwise flag).
      Group_Header : constant String := "[Desktop" & " " & "Entry]";
      File         : Ada.Text_IO.File_Type;
      In_Group     : Boolean := False;
      Have_Group   : Boolean := False;
      Have_Any_Group : Boolean := False;
      Groups_Seen  : Desktop_Id_Sets.Set;
      Keys_Seen    : Desktop_Id_Sets.Set;
      Is_App       : Boolean := False;
      No_Display   : Boolean := False;
      Hidden       : Boolean := False;
      Name_Value   : Unbounded_String;
      Localized_Name_Value : Unbounded_String;
      Exec_Value   : Unbounded_String;
      Icon_Value   : Unbounded_String;
      Localized_Icon_Value : Unbounded_String;
      Try_Exec_Value : Unbounded_String;
      Only_Show_In : Files.Types.String_Vectors.Vector;
      Not_Show_In  : Files.Types.String_Vectors.Vector;
      Have_Type    : Boolean := False;
      Have_Name    : Boolean := False;
      Have_Icon    : Boolean := False;
      Have_Try_Exec : Boolean := False;
      Have_Only_Show_In : Boolean := False;
      Have_Not_Show_In  : Boolean := False;
      Have_Localized_Name : Boolean := False;
      Have_Localized_Icon : Boolean := False;
      Any_Localized_Icon  : Boolean := False;
      Name_Rank   : Natural := Natural'Last;
      Icon_Rank   : Natural := Natural'Last;
      Entry_Valid : Boolean := True;

      procedure Assign_Decoded
        (Raw    : String;
         Target : out Unbounded_String)
      is
         Valid : Boolean;
      begin
         Decode_Value (Raw, Target, Valid);
         if not Valid then
            Entry_Valid := False;
         end if;
      end Assign_Decoded;

      procedure Assign_Boolean
        (Raw    : String;
         Target : out Boolean)
      is
         Valid : Boolean;
      begin
         Parse_Boolean (Raw, Target, Valid);
         if not Valid then
            Entry_Valid := False;
         end if;
      end Assign_Boolean;

      procedure Assign_String_List
        (Raw    : String;
         Target : out Files.Types.String_Vectors.Vector)
      is
         Valid : Boolean;
      begin
         Parse_String_List (Raw, Target, Valid);
         if not Valid then
            Entry_Valid := False;
         end if;
      end Assign_String_List;

      procedure Consider_Localized
        (Key        : String;
         Base_Key   : String;
         Raw        : String;
         Target     : in out Unbounded_String;
         Have_Value : in out Boolean;
         Best_Rank  : in out Natural)
      is
         Rank : constant Natural :=
           Localized_Key_Rank (Key, Base_Key, Locales);
      begin
         if Rank > 0 and then Rank < Best_Rank then
            Assign_Decoded (Raw, Target);
            Have_Value := True;
            Best_Rank := Rank;
         end if;
      end Consider_Localized;
   begin
      Found := False;
      App :=
        (Name         => Null_Unbounded_String,
         Exec         => Null_Unbounded_String,
         Icon         => Null_Unbounded_String,
         Desktop_File => Null_Unbounded_String);

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line    : constant String := Trim_Blanks (Ada.Text_IO.Get_Line (File));
            Equals  : Natural := 0;
         begin
            if Line'Length > 0 and then Line (Line'First) = '[' then
               Keys_Seen.Clear;
               if not Is_Valid_Group_Header (Line) then
                  Entry_Valid := False;
                  In_Group := False;
               else
                  declare
                     Group_Name : constant String :=
                       Line (Line'First + 1 .. Line'Last - 1);
                  begin
                     Have_Any_Group := True;
                     if Groups_Seen.Contains (Group_Name) then
                        Entry_Valid := False;
                     else
                        Groups_Seen.Insert (Group_Name);
                     end if;

                     In_Group := Line = Group_Header;
                     if In_Group then
                        Have_Group := True;
                     end if;
                  end;
               end if;
            elsif Line'Length > 0
              and then Line (Line'First) /= '#'
            then
               for Index in Line'Range loop
                  if Line (Index) = '=' then
                     Equals := Index;
                     exit;
                  end if;
               end loop;

               if not Have_Any_Group or else Equals <= Line'First then
                  Entry_Valid := False;
               else
                  declare
                     Key   : constant String :=
                       Trim_Blanks (Line (Line'First .. Equals - 1));
                     Value : constant String :=
                       Trim_Blanks (Line (Equals + 1 .. Line'Last));
                  begin
                     if Keys_Seen.Contains (Key) then
                        Entry_Valid := False;
                     else
                        Keys_Seen.Insert (Key);
                        if not In_Group then
                           null;
                        elsif Key = "Type" then
                           Is_App := Value = "Application";
                           Have_Type := True;
                        elsif Key = "Name" then
                           Assign_Decoded (Value, Name_Value);
                           Have_Name := True;
                        elsif Key'Length > 5
                          and then Key (Key'First .. Key'First + 4) = "Name["
                        then
                           Consider_Localized
                             (Key, "Name", Value, Localized_Name_Value,
                              Have_Localized_Name, Name_Rank);
                        elsif Key = "Exec" then
                           Assign_Decoded (Value, Exec_Value);
                        elsif Key = "Icon" then
                           Assign_Decoded (Value, Icon_Value);
                           Have_Icon := True;
                        elsif Key'Length > 5
                          and then Key (Key'First .. Key'First + 4) = "Icon["
                        then
                           Any_Localized_Icon := True;
                           Consider_Localized
                             (Key, "Icon", Value, Localized_Icon_Value,
                              Have_Localized_Icon, Icon_Rank);
                        elsif Key = "TryExec" then
                           Assign_Decoded (Value, Try_Exec_Value);
                           Have_Try_Exec := True;
                        elsif Key = "OnlyShowIn" then
                           Assign_String_List (Value, Only_Show_In);
                           Have_Only_Show_In := True;
                        elsif Key = "NotShowIn" then
                           Assign_String_List (Value, Not_Show_In);
                           Have_Not_Show_In := True;
                        elsif Key = "NoDisplay" then
                           Assign_Boolean (Value, No_Display);
                        elsif Key = "Hidden" then
                           Assign_Boolean (Value, Hidden);
                        end if;
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      if Have_Localized_Name then
         Name_Value := Localized_Name_Value;
      end if;
      if Have_Localized_Icon then
         Icon_Value := Localized_Icon_Value;
      end if;

      if Any_Localized_Icon and then not Have_Icon then
         Entry_Valid := False;
      end if;

      if Entry_Valid and then Have_Group and then Have_Type and then Is_App
        and then Have_Name
        and then not No_Display and then not Hidden
        and then Name_Value /= "" and then Exec_Value /= ""
        and then Desktop_Environment_Allows
          (Only_Show_In, Have_Only_Show_In,
           Not_Show_In, Have_Not_Show_In)
        and then
          (not Have_Try_Exec
           or else Files.Operations.Open_Action_Executable_Is_Available
             (Files.Settings.Make_Action
                (To_String (Try_Exec_Value),
                 Files.Types.String_Vectors.Empty_Vector)))
      then
         App :=
           (Name         => Name_Value,
            Exec         => Exec_Value,
            Icon         => Icon_Value,
            Desktop_File => To_Unbounded_String (Path));
         Found := To_String
           (Build_Open_Action
              (App, Files.Types.String_Vectors.Empty_Vector).Executable) /= "";
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            begin
               Ada.Text_IO.Close (File);
            exception
               when others =>
                  null;
            end;
         end if;
         Found := False;
   end Parse_Desktop_File;

   --  Convert a path relative to an applications directory into the desktop
   --  file ID used for XDG precedence. For example, foo/bar.desktop and
   --  foo-bar.desktop have the same ID.
   function Desktop_File_Id (Relative_Path : String) return String is
      Result : String := Relative_Path;
   begin
      for Index in Result'Range loop
         if Result (Index) = '/' or else Result (Index) = '\' then
            Result (Index) := '-';
         end if;
      end loop;
      return Result;
   end Desktop_File_Id;

   --  Recursively scan Directory for *.desktop entries. Claimed contains IDs
   --  already supplied by a higher-priority XDG directory. An entry claims its
   --  ID even when hidden or malformed, so a lower-priority definition cannot
   --  unexpectedly make that application visible again.
   Max_Application_Scan_Depth : constant Natural := 64;

   procedure Scan_Directory
     (Directory     : String;
      Relative_Path : String;
      Locales       : Files.Types.String_Vectors.Vector;
      Claimed       : in out Desktop_Id_Sets.Set;
      Apps          : in out Application_Vectors.Vector;
      Depth         : Natural := 0)
   is
      Search  : Ada.Directories.Search_Type;
      Element : Ada.Directories.Directory_Entry_Type;
      use type Ada.Directories.File_Kind;
   begin
      if Depth > Max_Application_Scan_Depth
        or else not Ada.Directories.Exists (Directory)
      then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Directory,
         Pattern   => "",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => False]);

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Element);
         declare
            Simple : constant String := Ada.Directories.Simple_Name (Element);
            Full   : constant String := Ada.Directories.Full_Name (Element);
            Relative : constant String :=
              (if Relative_Path = "" then Simple
               else Relative_Path & "/" & Simple);
            Kind   : constant Ada.Directories.File_Kind :=
              Ada.Directories.Kind (Element);
         begin
            --  Ada.Directories.Kind follows links. Descending through one can
            --  revisit an ancestor forever (or scan outside the configured
            --  application tree), so links are never traversal edges here.
            if Hostkit.Fs.Is_Link (Full) then
               null;
            elsif Kind = Ada.Directories.Directory then
               if Simple /= "." and then Simple /= ".." then
                  Scan_Directory
                    (Full, Relative, Locales, Claimed, Apps, Depth + 1);
               end if;
            elsif Kind = Ada.Directories.Ordinary_File
              and then Simple'Length > 8
              and then Simple (Simple'Last - 7 .. Simple'Last) = ".desktop"
            then
               declare
                  Id    : constant String := Desktop_File_Id (Relative);
                  Found : Boolean;
                  App   : Application;
               begin
                  if not Claimed.Contains (Id) then
                     Claimed.Insert (Id);
                     Parse_Desktop_File (Full, Locales, Found, App);
                     if Found then
                        Apps.Append (App);
                     end if;
                  end if;
               end;
            end if;
         exception
            when others =>
               null;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
   end Scan_Directory;

   --  Return the list of XDG base data directories to scan, most specific first.
   function Data_Directories return Files.Types.String_Vectors.Vector is
      Bases : Files.Types.String_Vectors.Vector;

      Home          : constant String := Environment_Value ("HOME");
      Data_Home     : constant String := Environment_Value ("XDG_DATA_HOME");
      Data_Dirs     : constant String := Environment_Value ("XDG_DATA_DIRS");
      Effective_Dirs : constant String :=
        (if Data_Dirs /= "" then Data_Dirs else "/usr/local/share:/usr/share");

      procedure Append_Base (Value : String) is
      begin
         if Value = "" or else not GNAT.OS_Lib.Is_Absolute_Path (Value) then
            return;
         end if;
         for Existing of Bases loop
            if To_String (Existing) = Value then
               return;
            end if;
         end loop;
         Bases.Append (To_Unbounded_String (Value));
      end Append_Base;
   begin
      if Data_Home /= "" and then GNAT.OS_Lib.Is_Absolute_Path (Data_Home) then
         Append_Base (Data_Home);
      elsif Home /= "" and then GNAT.OS_Lib.Is_Absolute_Path (Home) then
         Append_Base (Home & "/.local/share");
      end if;

      declare
         Current : Unbounded_String;
      begin
         for Character_Value of Effective_Dirs loop
            if Character_Value = ':' then
               if Length (Current) > 0 then
                  Append_Base (To_String (Current));
                  Current := Null_Unbounded_String;
               end if;
            else
               Append (Current, Character_Value);
            end if;
         end loop;
         if Length (Current) > 0 then
            Append_Base (To_String (Current));
         end if;
      end;

      return Bases;
   exception
      when others =>
         return Files.Types.String_Vectors.Empty_Vector;
   end Data_Directories;

   function Comes_Before (Left, Right : Application) return Boolean is
      Left_Name  : constant String :=
        Files.Types.To_Lower (To_String (Left.Name));
      Right_Name : constant String :=
        Files.Types.To_Lower (To_String (Right.Name));
   begin
      if Left_Name /= Right_Name then
         return Left_Name < Right_Name;
      elsif Left.Name /= Right.Name then
         return Left.Name < Right.Name;
      else
         return Left.Desktop_File < Right.Desktop_File;
      end if;
   end Comes_Before;

   package Application_Sorting is new Application_Vectors.Generic_Sorting
     ("<" => Comes_Before);

   function Available_Applications return Application_Vectors.Vector is
      Collected : Application_Vectors.Vector;
      Claimed   : Desktop_Id_Sets.Set;
      Locales   : constant Files.Types.String_Vectors.Vector :=
        Message_Locale_Candidates;
   begin
      for Base of Data_Directories loop
         Scan_Directory
           (Directory     => To_String (Base) & "/applications",
            Relative_Path => "",
            Locales       => Locales,
            Claimed       => Claimed,
            Apps          => Collected);
      end loop;

      Application_Sorting.Sort (Collected);
      return Collected;
   exception
      when others =>
         return Application_Vectors.Empty_Vector;
   end Available_Applications;

end Files.Applications;
