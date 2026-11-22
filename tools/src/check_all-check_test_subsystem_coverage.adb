separate (Check_All)
   procedure Check_Test_Subsystem_Coverage is
      procedure Require_Tests (Suite : String; Expected : Positive) is
         --  Registrations in code: one commented out is not counted.
         Text  : constant String :=
           Code_Of
             (To_String (Project_Tools.Text.Read_Text_File (Root & "/tests/tests/src/files_suite-" & Suite & ".adb")));
         Count : Natural := 0;
         From  : Natural := Text'First;

         --  Whether Code calls a check: a name starting Assert, Expect or
         --  Require (qualified or not: Assert_Equal, Assert_Within and the
         --  suite's other assertion helpers among them) followed by its
         --  arguments or ";", and not the name being declared. A message or
         --  an identifier such as Required_Size does not count, nor does Skip:
         --  a body that only skips checks nothing on any host.
         function Calls_A_Check (Code : String) return Boolean is
            function Declares (At_Name : Positive) return Boolean is
              (At_Name - Code'First >= 10
               and then (Ada.Strings.Fixed.Tail (Code (Code'First .. At_Name - 1), 10) = "procedure "
                         or else Ada.Strings.Fixed.Tail (Code (Code'First .. At_Name - 1), 9) = "function "));
            type Check_Names is array (1 .. 3) of Unbounded_String;
            Names : constant Check_Names :=
              [To_Unbounded_String ("Assert"), To_Unbounded_String ("Expect"), To_Unbounded_String ("Require")];
         begin
            for Name of Names loop
               declare
                  Word : constant String := To_String (Name);
                  From : Positive := Code'First;
                  At_Word : Natural;
                  Next : Positive;
               begin
                  loop
                     At_Word := Ada.Strings.Fixed.Index (Code (From .. Code'Last), Word);
                     exit when At_Word = 0;
                     if At_Word = Code'First or else not Is_Identifier_Character (Code (At_Word - 1)) then
                        Next := At_Word + Word'Length;
                        while Next <= Code'Last and then Is_Identifier_Character (Code (Next)) loop
                           Next := Next + 1;
                        end loop;
                        while Next <= Code'Last and then Code (Next) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                           Next := Next + 1;
                        end loop;
                        if Next <= Code'Last and then Code (Next) in '(' | ';' and then not Declares (At_Word) then
                           return True;
                        end if;
                     end if;
                     exit when At_Word + Word'Length > Code'Last;
                     From := At_Word + Word'Length;
                  end loop;
               end;
            end loop;
            return False;
         end Calls_A_Check;

         --  A registered test must check something: a body with no Assert
         --  (or a helper named for its Expect/Require) passes always, and so
         --  does one whose only call is a Skip.
         procedure Require_Checks (Routine : String) is
            Unit : constant String :=
              Root & "/tests/tests/src/files_suite-" & Suite & "-"
              & Ada.Characters.Handling.To_Lower (Routine) & ".adb";
            Body_Text : constant String :=
              (if Ada.Directories.Exists (Unit)
               then Code_Of (To_String (Project_Tools.Text.Read_Text_File (Unit)), Blank_Strings => True)
               else Text);
            Start : constant Natural :=
              (if Ada.Directories.Exists (Unit) then Body_Text'First
               else Ada.Strings.Fixed.Index (Body_Text, "procedure " & Routine & " (T"));
            Stop  : constant Natural :=
              (if Start = 0 then 0
               else Ada.Strings.Fixed.Index (Body_Text (Start .. Body_Text'Last), "end " & Routine & ";"));
         begin
            if Start = 0 or else Stop = 0 or else not Calls_A_Check (Body_Text (Start .. Stop)) then
               Report ("the " & Suite & " test " & Routine & " registers but checks nothing");
            end if;
         end Require_Checks;
      begin
         loop
            declare
               At_Name : constant Natural :=
                 Ada.Strings.Fixed.Index (Text (From .. Text'Last), "Register_Routine");
               At_T    : Natural;
               At_Tick : Natural;
            begin
               exit when At_Name = 0;
               Count := Count + 1;
               From := At_Name + 1;
               At_T := Ada.Strings.Fixed.Index (Text (At_Name .. Text'Last), "(T, ");
               At_Tick := (if At_T = 0 then 0 else Ada.Strings.Fixed.Index (Text (At_T .. Text'Last), "'Access"));
               if At_Tick > At_T + 4 then
                  Require_Checks (Text (At_T + 4 .. At_Tick - 1));
               end if;
            end;
         end loop;
         --  Exact, not a floor: a test added without the number moving here
         --  hides the next one lost.
         if Count /= Expected then
            Report ("the " & Suite & " test suite registers" & Natural'Image (Count)
               & " tests, not the" & Positive'Image (Expected) & " expected here");
         end if;
      end Require_Tests;
      type Suite_Count is record
         Suite    : Unbounded_String;
         Expected : Positive;
      end record;

      function Expect (Suite : String; Expected : Positive) return Suite_Count is
        (Suite => To_Unbounded_String (Suite), Expected => Expected);

      type Suite_Counts is array (Positive range <>) of Suite_Count;

      --  The exact counts as of the last change to a suite: a lost test, or
      --  one added without its count moving here, fails.
      Counts : constant Suite_Counts :=
        [Expect ("settings", 45),
         Expect ("startup", 32),
         Expect ("commands", 45),
         Expect ("model", 57),
         Expect ("interaction", 37),
         Expect ("context_menu", 22),
         Expect ("drags", 8),
         Expect ("tree", 16),
         Expect ("keyboard", 15),
         Expect ("text_input", 5),
         Expect ("rendering", 122),
         Expect ("operations", 49),
         Expect ("transfer", 60),
         Expect ("recovery", 64),
         Expect ("history", 42),
         Expect ("trash", 35),
         Expect ("search", 11),
         Expect ("thumbnails", 22),
         Expect ("archives", 7),
         Expect ("info", 33),
         Expect ("names", 19),
         Expect ("refresh", 16),
         Expect ("open_actions", 18)];

      --  The suites files_suite.adb runs: Result.Add_Test (Files_Suite.<Name>.Suite).
      function Registered_Suites return String_List is
         use Tokens;
         Toks : constant Token_List :=
           Tokens_Of (Project_Tools.Files.Read_Raw_File (Root & "/tests/tests/src/files_suite.adb"));

         function From (Start : Positive) return String_List is
         begin
            for Index in Start .. Toks.Last_Index - 6 loop
               if Is_Word (Toks (Index), "add_test") and then Is_Symbol (Toks (Index + 1), "(")
                 and then Is_Word (Toks (Index + 2), "files_suite") and then Is_Symbol (Toks (Index + 3), ".")
                 and then Toks (Index + 4).Kind = Word and then Is_Symbol (Toks (Index + 5), ".")
                 and then Is_Word (Toks (Index + 6), "suite")
               then
                  return Toks (Index + 4).Text & From (Index + 7);
               end if;
            end loop;
            return [1 .. 0 => <>];
         end From;
      begin
         return From (Toks.First_Index);
      end Registered_Suites;

      Suites : constant String_List := Registered_Suites;

      function Counted (Suite : String) return Boolean is
        (for some Item of Counts => To_String (Item.Suite) = Suite);

      function Registered (Suite : String) return Boolean is
        (for some Name of Suites => To_String (Name) = Suite);
   begin
      if Suites'Length = 0 then
         Report ("check_all's Check_Test_Subsystem_Coverage finds no suite in tests/tests/src/files_suite.adb");
      end if;
      --  Every suite the run adds has its count here, and every count is a
      --  suite the run adds: a new suite is held to an exact count from its
      --  first test, and a dropped one is not counted on.
      for Name of Suites loop
         if not Counted (To_String (Name)) then
            Report ("the " & To_String (Name) & " test suite is run but has no expected test count in"
                    & " check_all's Check_Test_Subsystem_Coverage");
         end if;
      end loop;
      for Item of Counts loop
         if Registered (To_String (Item.Suite)) then
            Require_Tests (To_String (Item.Suite), Item.Expected);
         else
            Report ("check_all's Check_Test_Subsystem_Coverage counts the " & To_String (Item.Suite)
                    & " test suite, which files_suite.adb no longer runs");
         end if;
      end loop;
   end Check_Test_Subsystem_Coverage;
