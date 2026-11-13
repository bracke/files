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
            function Identifier_Char (C : Character) return Boolean is
              (C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');
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
                     if At_Word = Code'First or else not Identifier_Char (Code (At_Word - 1)) then
                        Next := At_Word + Word'Length;
                        while Next <= Code'Last and then Identifier_Char (Code (Next)) loop
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
               Put_Line (Standard_Error, "the " & Suite & " test " & Routine & " registers but checks nothing");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
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
            Put_Line
              (Standard_Error,
               "the " & Suite & " test suite registers" & Natural'Image (Count)
               & " tests, not the" & Positive'Image (Expected) & " expected here");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_Tests;
   begin
      --  The exact counts as of the last change to a suite: a lost test, or
      --  one added without its count moving here, fails.
      Require_Tests ("settings", 35);
      Require_Tests ("startup", 30);
      Require_Tests ("commands", 39);
      Require_Tests ("model", 54);
      Require_Tests ("interaction", 91);
      Require_Tests ("rendering", 101);
      Require_Tests ("operations", 320);
   end Check_Test_Subsystem_Coverage;
