separate (Check_All)
   procedure Check_Test_Hooks is
      Hooks : constant Project_Tools.Files.Path_List :=
        [To_Unbounded_String (Root & "/src/files-file_system-support.ads"),
         To_Unbounded_String (Root & "/src/files-file_system-support.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_supported.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_bases.adb")];
      Override      : constant String := "FILES_TRASH_BACKEND";
      Override_Home : constant String := Root & "/src/files-file_system-trash_location_for_environment.adb";
      Override_Homes : constant Project_Tools.Files.Path_List := [1 => To_Unbounded_String (Override_Home)];
      Unexpected : constant String :=
        Project_Tools.Ada_Source.First_Source_File_Containing
          (Root & "/src",
           "FILES_TEST_",
           Hooks);
      Unexpected_Override : constant String :=
        Project_Tools.Ada_Source.First_Source_File_Containing (Root & "/src", Override, Override_Homes);
      --  A name built in pieces ("FILES_" & "TEST_X") reads a hook the
      --  search above cannot see: the prefix is never split, anywhere.
      Split : constant String :=
        Project_Tools.Ada_Source.First_Source_File_Containing (Root & "/src", "FILES_"" &", Hooks);

      function Is_Blank (Char : Character) return Boolean is
        (Char in ' ' | ASCII.LF | ASCII.CR | ASCII.HT);

      function Is_Word (Char : Character) return Boolean is
        (Char in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');

      --  Text with each closing quote, blanks, '&', blanks and opening
      --  quote removed, so joined literals read as one.
      function Joined (Text : String) return String is
         Result : Unbounded_String;
         Index  : Natural := Text'First;
      begin
         while Index <= Text'Last loop
            if Text (Index) = '"' then
               declare
                  Next : Natural := Index + 1;
               begin
                  while Next <= Text'Last and then Is_Blank (Text (Next)) loop
                     Next := Next + 1;
                  end loop;
                  if Next <= Text'Last and then Text (Next) = '&' then
                     Next := Next + 1;
                     while Next <= Text'Last and then Is_Blank (Text (Next)) loop
                        Next := Next + 1;
                     end loop;
                     if Next <= Text'Last and then Text (Next) = '"' then
                        Index := Next + 1;
                        goto Continue;
                     end if;
                  end if;
               end;
            end if;
            Append (Result, Text (Index));
            Index := Index + 1;
            <<Continue>>
         end loop;
         return To_String (Result);
      end Joined;

      --  Text with every whole-word use of Name (in any letter case)
      --  spelled as the string literal of Value.
      function Substituted (Text, Name, Value : String) return String is
         --  To_Lower's result starts at 1, Text may not.
         Lower      : constant String (Text'Range) := Ada.Characters.Handling.To_Lower (Text);
         Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
         Result     : Unbounded_String;
         From       : Positive := Text'First;
         At_Name    : Natural;
      begin
         loop
            At_Name :=
              (if From > Text'Last then 0 else Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Lower_Name));
            exit when At_Name = 0;
            declare
               After : constant Natural := At_Name + Lower_Name'Length;
            begin
               Append (Result, Text (From .. At_Name - 1));
               if (At_Name = Text'First or else not Is_Word (Text (At_Name - 1)))
                 and then (After > Text'Last or else not Is_Word (Text (After)))
               then
                  Append (Result, '"' & Value & '"');
               else
                  Append (Result, Text (At_Name .. After - 1));
               end if;
               From := After;
            end;
         end loop;
         if From <= Text'Last then
            Append (Result, Text (From .. Text'Last));
         end if;
         return To_String (Result);
      end Substituted;

      --  Text with every string constant it declares (Prefix : constant
      --  String := "FILES_TE";) spelled as its literal wherever it is used,
      --  then every literal join closed up: Prefix & "ST_X" reads as the
      --  name it builds. A constant built from an earlier one resolves too.
      function Resolved (Text : String) return String is
         type String_Constant is record
            Name  : Unbounded_String;
            Value : Unbounded_String;
         end record;
         package Constant_Vectors is new Ada.Containers.Indefinite_Vectors
           (Index_Type => Positive, Element_Type => String_Constant);
         Lower     : constant String (Text'Range) := Ada.Characters.Handling.To_Lower (Text);
         Marker    : constant String := "constant string";
         Constants : Constant_Vectors.Vector;
         From      : Positive := Text'First;
         Found     : Natural;

         --  Text with every constant found so far spelled as its literal.
         function Spelled (Text : String) return String is
            Result : Unbounded_String := To_Unbounded_String (Text);
         begin
            for Known of Constants loop
               Result :=
                 To_Unbounded_String
                   (Substituted (To_String (Result), To_String (Known.Name), To_String (Known.Value)));
            end loop;
            return To_String (Result);
         end Spelled;
      begin
         loop
            Found := (if From > Text'Last then 0 else Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Marker));
            exit when Found = 0;
            From := Found + Marker'Length;
            declare
               --  Back over blanks and the colon to the name's end, then to
               --  its start.
               Name_Last  : Natural := Found - 1;
               Name_First : Natural;
               Assign     : Natural := Found + Marker'Length;
               Stop       : Natural;
               Colon_Seen : Boolean := False;
            begin
               while Name_Last >= Text'First
                 and then (Is_Blank (Text (Name_Last)) or else (Text (Name_Last) = ':' and then not Colon_Seen))
               loop
                  Colon_Seen := Colon_Seen or else Text (Name_Last) = ':';
                  Name_Last := Name_Last - 1;
               end loop;
               Name_First := Name_Last + 1;
               while Name_First > Text'First and then Is_Word (Text (Name_First - 1)) loop
                  Name_First := Name_First - 1;
               end loop;
               while Assign <= Text'Last and then Is_Blank (Text (Assign)) loop
                  Assign := Assign + 1;
               end loop;
               Stop :=
                 (if Assign + 1 > Text'Last then 0
                  else Ada.Strings.Fixed.Index (Text (Assign .. Text'Last), ";"));
               if Colon_Seen
                 and then Name_First <= Name_Last
                 and then Stop > 0
                 and then Text (Assign .. Assign + 1) = ":="
               then
                  declare
                     Value : constant String :=
                       Ada.Strings.Fixed.Trim (Joined (Spelled (Text (Assign + 2 .. Stop - 1))), Ada.Strings.Both);
                  begin
                     --  Only a constant that is one literal.
                     if Value'Length >= 2
                       and then Value (Value'First) = '"'
                       and then Value (Value'Last) = '"'
                       and then Ada.Strings.Fixed.Index (Value (Value'First + 1 .. Value'Last - 1), """") = 0
                     then
                        Constants.Append
                          (String_Constant'
                             (Name  => To_Unbounded_String (Text (Name_First .. Name_Last)),
                              Value => To_Unbounded_String (Value (Value'First + 1 .. Value'Last - 1))));
                     end if;
                  end;
               end if;
            end;
         end loop;
         return Joined (Spelled (Text));
      end Resolved;

      --  The first source below src/, other than those in Allowed, whose
      --  resolved text (Resolved) names Name: a split anywhere inside the
      --  name, not only after FILES_, or a part kept in a constant.
      function First_Built_Name (Name : String; Allowed : Project_Tools.Files.Path_List) return String is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;

         function Listed (Path : String) return Boolean is
           (for some Hook of Allowed => To_String (Hook) = Path);
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Path : constant String := Ada.Directories.Full_Name (Item);
            begin
               if not Listed (Path)
                 and then Ada.Strings.Fixed.Index (Resolved (Project_Tools.Files.Read_Raw_File (Path)), Name) > 0
               then
                  Ada.Directories.End_Search (Search);
                  return Path;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         return "";
      end First_Built_Name;

      procedure Refuse (Message : String) is
      begin
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      --  The resolution itself, on the shapes it exists for: if it stopped
      --  seeing them, the tree search below would pass on every source.
      Samples : constant array (1 .. 3) of Unbounded_String :=
        [To_Unbounded_String ("X : constant String := Value (""FILES_TE"" & ""ST_X"");"),
         To_Unbounded_String
           ("Prefix : constant String := ""FILES_TE"";" & ASCII.LF
            & "X : constant String := Value (prefix & ""ST_X"");"),
         To_Unbounded_String
           ("Start  : constant String := ""FILES_"";" & ASCII.LF
            & "Middle : constant String := Start & ""TRASH_"";" & ASCII.LF
            & "X : constant String := Value (Middle & ""BACKEND"");")];
      Sample_Names : constant array (Samples'Range) of Unbounded_String :=
        [To_Unbounded_String ("FILES_TEST_"),
         To_Unbounded_String ("FILES_TEST_"),
         To_Unbounded_String (Override)];
   begin
      for Index in Samples'Range loop
         if Ada.Strings.Fixed.Index (Resolved (To_String (Samples (Index))), To_String (Sample_Names (Index))) = 0 then
            Refuse
              ("check_all's Check_Test_Hooks no longer sees the name built in its sample"
               & Natural'Image (Index));
         end if;
      end loop;

      declare
         Joined_Hook     : constant String := First_Built_Name ("FILES_TEST_", Hooks);
         Joined_Override : constant String := First_Built_Name (Override, Override_Homes);
      begin
         if Joined_Hook /= "" and then Unexpected = "" then
            Refuse (Joined_Hook & ": builds a FILES_TEST_ variable name from joined literals or string constants");
         end if;
         if Split /= "" then
            Refuse (Split & ": builds a FILES_ variable name in pieces; spell it whole");
         end if;
         if Unexpected /= "" then
            Refuse (Unexpected & ": reads a FILES_TEST_* variable outside the listed test hooks");
         end if;
         if Unexpected_Override /= "" or else Joined_Override /= "" then
            Refuse
              ((if Unexpected_Override /= "" then Unexpected_Override else Joined_Override)
               & ": reads " & Override & ", which forces another host's trash backend; only "
               & Override_Home & " may read it");
         end if;
      end;
      --  And every listed hook still is one: a stale entry would let a new
      --  hook into that file pass unreviewed.
      for Hook of Hooks loop
         Project_Tools.Files.Require_Contains
           (To_String (Hook), "FILES_TEST_", To_String (Hook) & " is listed as a test hook but reads none");
      end loop;
      Project_Tools.Files.Require_Contains
        (Override_Home, Override, Override_Home & " is the one reader of " & Override & " but reads it no more");
   end Check_Test_Hooks;
